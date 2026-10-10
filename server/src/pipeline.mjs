// Grounded answer pipeline:
//   1. plan    – Gemini turns the question into literal Arabic search queries
//   2. search  – Nusus/Turath full-text retrieval (real pages only)
//   3. compose – Gemini answers strictly from the numbered sources
//   4. verify  – every quote is located in the real page text; unverifiable
//                answers are downgraded to "insufficient".
//
// Keep in sync with app/lib/core/pipeline/answer_pipeline.dart.
import { LANGUAGES, PLAN_SCHEMA, PLAN_SYSTEM, COMPOSE_SCHEMA, composeSystem, composePrompt, planPrompt } from "./prompts.mjs";
import { locateQuote } from "./verify.mjs";

export const INSUFFICIENT = {
  ps: "په موندل شویو منابعو کې د دې پوښتنې لپاره مستند ځواب ونه موندل شو. مهرباني وکړئ پوښتنه په بل ډول ولیکئ، یا د لټون ساحه (کتاب، مؤلف یا ډله) بدله کړئ.",
  ar: "لم يُعثر في المصادر المسترجعة على جواب موثَّق لهذا السؤال. جرّب صياغة أخرى للسؤال أو غيّر نطاق البحث (كتاب أو مؤلف أو تصنيف).",
  fa: "در منابع یافت‌شده پاسخ مستندی برای این پرسش پیدا نشد. لطفاً پرسش را به شکل دیگری بنویسید یا دامنهٔ جست‌وجو (کتاب، مؤلف یا دسته) را تغییر دهید.",
  en: "No documented answer to this question was found in the retrieved sources. Try rephrasing the question or changing the search scope (book, author or category).",
};

const MADHHAB_CATEGORIES = ["14", "15", "16", "17"]; // Hanafi, Maliki, Shafi'i, Hanbali

const LANG_CODES = new Set(Object.keys(LANGUAGES));

const clampInt = (value, min, max, fallback) => {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : fallback;
};

const cleanQueries = (queries) => {
  const seen = new Set();
  const out = [];
  for (const raw of Array.isArray(queries) ? queries : []) {
    if (typeof raw !== "string") continue;
    const q = raw.replace(/[ً-ٰٟ]/g, "").replace(/["'«»()[\]{}]/g, " ").replace(/\s+/g, " ").trim();
    if (!q || q.length > 60 || seen.has(q)) continue;
    seen.add(q);
    out.push(q);
  }
  return out.slice(0, 5);
};

/** Runs async tasks with bounded concurrency, collecting settled results. */
const settleAll = async (tasks, concurrency = 4) => {
  const results = new Array(tasks.length);
  let cursor = 0;
  const worker = async () => {
    while (cursor < tasks.length) {
      const index = cursor++;
      try {
        results[index] = { ok: true, value: await tasks[index]() };
      } catch (error) {
        results[index] = { ok: false, error };
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(concurrency, tasks.length) }, worker));
  return results;
};

const scopeToNusus = (scope = {}) => {
  const out = {};
  if (scope.bookId) out.bookIds = [String(scope.bookId)];
  if (scope.authorId) out.authorIds = [String(scope.authorId)];
  if (scope.categoryId) out.categoryIds = [String(scope.categoryId)];
  return Object.keys(out).length ? out : undefined;
};

export const scopeLabel = (scope, catalog) => {
  if (!scope) return "";
  const parts = [];
  if (scope.bookId) parts.push(`book "${catalog.book(scope.bookId)?.title ?? scope.bookId}"`);
  if (scope.authorId) parts.push(`author "${catalog.authorName(scope.authorId) ?? scope.authorId}"`);
  if (scope.categoryId) parts.push(`category "${catalog.categoryTitle(scope.categoryId) ?? scope.categoryId}"`);
  return parts.join(", ");
};

const toSource = (passage, key, catalog) => {
  const bookId = String(passage.book.id);
  const catalogBook = catalog.book(bookId);
  const authorId = passage.author?.id ?? catalogBook?.authorId;
  const categoryId = passage.category?.id ?? catalogBook?.categoryId;
  return {
    key,
    bookId,
    bookTitle: passage.book.title,
    authorId: authorId === undefined ? undefined : String(authorId),
    authorName: passage.author?.name ?? catalog.authorName(authorId),
    categoryId: categoryId === undefined ? undefined : String(categoryId),
    categoryTitle: catalog.categoryTitle(categoryId),
    volume: passage.location?.volume,
    printedPage: passage.location?.printedPage,
    internalPage: passage.location?.internalPage,
    headings: passage.headings ?? [],
    url: passage.url,
    shamelaUrl: passage.alternateUrls?.shamela,
    citation: passage.citation,
    text: passage.text,
    snippet: passage.snippet,
  };
};

/** Retrieves, de-duplicates and interleaves passages from several query streams. */
export const gatherSources = async ({ turath, catalog, queries, scope, questionType, maxSources }) => {
  const nususScope = scopeToNusus(scope);
  const streams = queries.map((query) => ({ query, scope: nususScope, max: 4 }));
  if (questionType === "fiqh" && !nususScope) {
    for (const categoryId of MADHHAB_CATEGORIES) {
      for (const query of queries.slice(0, 2)) streams.push({ query, scope: { categoryIds: [categoryId] }, max: 1 });
    }
  }
  const settled = await settleAll(
    streams.map((s) => () => turath.retrieve(s.query, { maxPassages: s.max, maxCharsPerPassage: 1600, scope: s.scope })),
  );
  const failures = settled.filter((r) => !r.ok).map((r) => r.error);
  const lists = settled.map((r) => (r.ok ? r.value.passages : []));
  const totalMatches = settled.reduce((sum, r) => sum + (r.ok ? r.value.totalMatches : 0), 0);

  const seen = new Set();
  const picked = [];
  for (let round = 0; picked.length < maxSources; round += 1) {
    let any = false;
    for (const list of lists) {
      const passage = list[round];
      if (!passage) continue;
      any = true;
      const id = `${passage.book.id}:${passage.location?.internalPage ?? passage.text.slice(0, 40)}`;
      if (seen.has(id)) continue;
      seen.add(id);
      picked.push(passage);
      if (picked.length >= maxSources) break;
    }
    if (!any) break;
  }
  if (!picked.length && failures.length && failures.length === settled.length) {
    const error = new Error("The Turath library could not be reached");
    error.code = "TURATH_UNAVAILABLE";
    error.cause = failures[0];
    throw error;
  }
  return { sources: picked.map((p, i) => toSource(p, `S${i + 1}`, catalog)), totalMatches };
};

const MARKER = /\[\s*(S\d+(?:\s*[,،;]\s*S?\d+)*)\s*\]/gi;

/** Verifies citations, renumbers markers to [1], [2] … and builds the public result. */
export const finalize = ({ composed, sources, language }) => {
  const byKey = new Map(sources.map((s) => [s.key, s]));
  const quotes = new Map();
  for (const citation of Array.isArray(composed?.citations) ? composed.citations : []) {
    const key = String(citation?.sourceId ?? "").trim().toUpperCase();
    const source = byKey.get(key);
    if (!source) continue;
    const located = locateQuote(source.text, citation.quote);
    if (!located) continue;
    const list = quotes.get(key) ?? [];
    if (list.length < 2 && !list.some((q) => q.text === located.text)) {
      list.push({ ...located, relevance: typeof citation.relevance === "string" ? citation.relevance : undefined });
    }
    quotes.set(key, list);
  }

  const status = ["answered", "partial", "insufficient"].includes(composed?.status) ? composed.status : "insufficient";
  const related = sources.slice(0, 6).map(publicSource({}));
  if (status === "insufficient" || quotes.size === 0) {
    const modelNote = status === "insufficient" && typeof composed?.answer === "string" ? composed.answer.trim() : "";
    return {
      status: "insufficient",
      answer: INSUFFICIENT[language] ?? INSUFFICIENT.en,
      detail: modelNote,
      sources: [],
      related,
      opinions: [],
    };
  }

  const order = [];
  const number = (key) => {
    if (!byKey.has(key)) return undefined;
    let n = order.indexOf(key);
    if (n < 0) {
      order.push(key);
      n = order.length - 1;
    }
    return n + 1;
  };
  const answer = String(composed.answer ?? "")
    .replace(MARKER, (_, inner) => {
      const nums = inner
        .split(/[,،;]/)
        .map((part) => part.trim().toUpperCase())
        .map((part) => (part.startsWith("S") ? part : `S${part}`))
        .map(number)
        .filter((n) => n !== undefined);
      return [...new Set(nums)].map((n) => `[${n}]`).join("");
    })
    .trim();
  for (const key of quotes.keys()) number(key);

  const numbered = order.map((key, i) => publicSource(quotes)(byKey.get(key), i));
  const keyToNumber = new Map(order.map((key, i) => [key, i + 1]));
  const opinions = (Array.isArray(composed.opinions) ? composed.opinions : [])
    .map((o) => ({
      holder: String(o?.holder ?? "").trim(),
      view: String(o?.view ?? "").trim(),
      sources: (Array.isArray(o?.sourceIds) ? o.sourceIds : [])
        .map((id) => keyToNumber.get(String(id).trim().toUpperCase()))
        .filter((n) => n !== undefined),
    }))
    .filter((o) => o.holder && o.view && o.sources.length);

  return {
    status: status === "partial" ? "partial" : "answered",
    answer,
    summary: typeof composed.summary === "string" ? composed.summary.trim() : "",
    notes: typeof composed.notes === "string" ? composed.notes.trim() : "",
    sources: numbered,
    related: [],
    opinions,
  };
};

const publicSource = (quotes) => (source, index) => ({
  n: index + 1,
  bookId: source.bookId,
  bookTitle: source.bookTitle,
  authorId: source.authorId,
  authorName: source.authorName,
  categoryId: source.categoryId,
  categoryTitle: source.categoryTitle,
  volume: source.volume,
  printedPage: source.printedPage,
  internalPage: source.internalPage,
  headings: source.headings,
  url: source.url,
  shamelaUrl: source.shamelaUrl,
  citation: source.citation,
  quotes: (quotes.get?.(source.key) ?? []).map((q) => ({ text: q.text, exact: q.exact, relevance: q.relevance })),
  excerpt: (source.snippet || source.text || "").slice(0, 600),
});

export const createPipeline = ({ gemini, turath, catalog }) => {
  const ask = async (input, onEvent = () => {}) => {
    const started = Date.now();
    const question = String(input?.question ?? "").trim();
    if (!question) {
      const error = new Error("question must not be empty");
      error.code = "INVALID_ARGUMENT";
      throw error;
    }
    if (question.length > 2000) {
      const error = new Error("question is too long (max 2000 characters)");
      error.code = "INVALID_ARGUMENT";
      throw error;
    }
    const scope = input.scope ?? {};
    const history = Array.isArray(input.history) ? input.history.slice(-3) : [];
    const maxSources = clampInt(input.maxSources, 3, 16, 10);

    onEvent("stage", { stage: "planning" });
    const plan = await gemini.generateJson({
      system: PLAN_SYSTEM,
      prompt: planPrompt({ question, history, scopeLabel: scopeLabel(scope, catalog) }),
      schema: PLAN_SCHEMA,
      temperature: 0.1,
    });
    const queries = cleanQueries(plan.data.queries);
    const requested = LANG_CODES.has(input.language) ? input.language : undefined;
    const detected = LANG_CODES.has(plan.data.detectedLanguage) ? plan.data.detectedLanguage : undefined;
    const language = requested ?? detected ?? (LANG_CODES.has(input.fallbackLanguage) ? input.fallbackLanguage : "en");
    onEvent("plan", { queries, questionType: plan.data.questionType, language });

    if (!queries.length) {
      return { ...finalize({ composed: { status: "insufficient" }, sources: [], language }), queries, language, model: plan.model, elapsedMs: Date.now() - started };
    }

    onEvent("stage", { stage: "searching" });
    const { sources, totalMatches } = await gatherSources({
      turath,
      catalog,
      queries,
      scope,
      questionType: plan.data.questionType,
      maxSources,
    });
    onEvent("sources", { count: sources.length, totalMatches });
    if (!sources.length) {
      return {
        ...finalize({ composed: { status: "insufficient" }, sources, language }),
        queries,
        language,
        totalMatches,
        model: plan.model,
        elapsedMs: Date.now() - started,
      };
    }

    onEvent("stage", { stage: "composing" });
    const composed = await gemini.generateJson({
      system: composeSystem(LANGUAGES[language]),
      prompt: composePrompt({ question: plan.data.standaloneQuestion || question, history, sources, languageName: LANGUAGES[language] }),
      schema: COMPOSE_SCHEMA,
      temperature: 0.2,
    });

    onEvent("stage", { stage: "verifying" });
    const result = finalize({ composed: composed.data, sources, language });
    return { ...result, queries, language, totalMatches, model: composed.model, elapsedMs: Date.now() - started };
  };
  return { ask };
};
