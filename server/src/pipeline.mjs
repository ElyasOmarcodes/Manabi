// Grounded answer pipeline (v2):
//   1. plan     – Gemini: literal Arabic queries, schools, requested + reference books
//   2. search   – Nusus/Turath: general, per-book, per-school searches → candidate pool
//   3. read     – Gemini ranks the candidates; one follow-up search round if needed
//   4. compose  – Gemini answers only from the selected pages, quoting them inline
//   5. verify   – every quote is located in the real page text; unverifiable
//                 answers are downgraded to "insufficient".
//
// Keep in sync with app/lib/core/pipeline/answer_pipeline.dart.
import { partialJsonString } from "./partial.mjs";
import { decodingTurath } from "./text.mjs";
import {
  COMPOSE_SCHEMA,
  LANGUAGES,
  PLAN_SCHEMA,
  PLAN_SYSTEM,
  RERANK_SCHEMA,
  RERANK_SYSTEM,
  composePrompt,
  composeSystem,
  planPrompt,
  rerankPrompt,
} from "./prompts.mjs";
import { boundText } from "./excerpt.mjs";
import { locateQuote } from "./verify.mjs";

export const INSUFFICIENT = {
  ps: "په موندل شویو منابعو کې د دې پوښتنې لپاره مستند ځواب ونه موندل شو. مهرباني وکړئ پوښتنه په بل ډول ولیکئ، یا د لټون ساحه (کتاب، مؤلف یا ډله) بدله کړئ.",
  ar: "لم يُعثر في المصادر المسترجعة على جواب موثَّق لهذا السؤال. جرّب صياغة أخرى للسؤال أو غيّر نطاق البحث (كتاب أو مؤلف أو تصنيف).",
  fa: "در منابع یافت‌شده پاسخ مستندی برای این پرسش پیدا نشد. لطفاً پرسش را به شکل دیگری بنویسید یا دامنهٔ جست‌وجو (کتاب، مؤلف یا دسته) را تغییر دهید.",
  en: "No documented answer to this question was found in the retrieved sources. Try rephrasing the question or changing the search scope (book, author or category).",
};

export const MADHHAB_CATEGORY = { hanafi: "14", maliki: "15", shafii: "16", hanbali: "17" };

const MADHHAB_NAMES = {
  hanafi: /حنف|احناف|أحناف|hanaf/i,
  maliki: /مالكي|مالكية|malik(?:i|ite)/i,
  shafii: /شافع|shafi/i,
  hanbali: /حنبل|hanbal/i,
};

/** Schools the question names explicitly (a safety net for the planner). */
export const namedMadhhabs = (text) => Object.keys(MADHHAB_NAMES).filter((m) => MADHHAB_NAMES[m].test(text ?? ""));
const LANG_CODES = new Set(Object.keys(LANGUAGES));

export const LIMITS = {
  generalQueries: 6,
  hitsPerGeneral: 8,
  requestedBooks: 3,
  queriesPerRequested: 4,
  hitsPerRequested: 4,
  referenceBooks: 5,
  queriesPerReference: 2,
  hitsPerReference: 3,
  queriesPerMadhhab: 3,
  hitsPerMadhhab: 4,
  maxSearches: 40,
  maxCandidates: 64,
  excerptChars: 650,
  sourceChars: 2400,
  maxSelected: 14,
  continuationPages: 6,
  followUpRounds: 1,
};

/**
 * Research depth, chosen by the user like a "thinking effort" control:
 * quick reads fewer passages, deep searches wider and reads more pages.
 */
export const DEPTHS = {
  quick: { generalQueries: 3, hitsPerGeneral: 6, referenceBooks: 3, queriesPerMadhhab: 2, maxSearches: 18, maxCandidates: 32, maxSelected: 6, continuationPages: 2, followUpRounds: 0 },
  standard: {},
  deep: { generalQueries: 8, hitsPerGeneral: 10, referenceBooks: 6, queriesPerReference: 3, queriesPerMadhhab: 4, hitsPerMadhhab: 5, maxSearches: 64, maxCandidates: 96, maxSelected: 18, continuationPages: 10, followUpRounds: 2 },
};

export const limitsFor = (depth) => ({ ...LIMITS, ...(DEPTHS[depth] ?? {}) });

/**
 * Rulings often continue on the next page. For the strongest selected pages,
 * fetch the following page and add it as its own source (with its own page
 * number), so quotes from it are cited correctly.
 */
export const addContinuations = async ({ turath, catalog, selected, limit = LIMITS.continuationPages }) => {
  const have = new Set(selected.map((c) => c.id));
  const targets = selected.filter((c) => c.internalPage !== undefined).slice(0, limit);
  const settled = await settleAll(targets.map((c) => () => turath.getPage(c.bookId, c.internalPage + 1)));
  const out = [];
  for (const c of selected) {
    out.push(c);
    const i = targets.indexOf(c);
    if (i < 0 || !settled[i]?.ok) continue;
    const next = toCandidate(settled[i].value, catalog);
    if (have.has(next.id) || !next.text.trim()) continue;
    have.add(next.id);
    out.push({ ...next, text: boundText(settled[i].value.text, 1600).text, continuationOf: c.id });
  }
  return out;
};

const clampInt = (value, min, max, fallback) => {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : fallback;
};

export const cleanQueries = (queries, max = 8) => {
  const seen = new Set();
  const out = [];
  for (const raw of Array.isArray(queries) ? queries : []) {
    if (typeof raw !== "string") continue;
    const q = raw.replace(/[ً-ٰٟ]/g, "").replace(/["'«»()[\]{}]/g, " ").replace(/\s+/g, " ").trim();
    if (!q || q.length > 60 || seen.has(q)) continue;
    seen.add(q);
    out.push(q);
  }
  return out.slice(0, max);
};

const cleanTitles = (titles, max) =>
  [...new Set((Array.isArray(titles) ? titles : []).filter((t) => typeof t === "string").map((t) => t.trim()).filter(Boolean))].slice(0, max);

/** Runs async tasks with bounded concurrency, collecting settled results. */
const settleAll = async (tasks, concurrency = 6) => {
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

const scopeIds = (v) =>
  [...new Set((Array.isArray(v) ? v : typeof v === "string" ? v.split(",") : v != null ? [v] : []).map((x) => String(x).trim()).filter((x) => /^[1-9]\d{0,9}$/.test(x)))];

/**
 * The searches a scope stands for. Turath filters one book, author and
 * category per search, so several picks become several searches: every
 * chosen book, plus every chosen author within every chosen category.
 * (The older single bookId/authorId/categoryId form is one search.)
 */
export const scopeTargets = (scope = {}, max = 12) => {
  if (!scope || typeof scope !== "object") return [];
  const lists = scope.bookIds !== undefined || scope.authorIds !== undefined || scope.categoryIds !== undefined;
  if (!lists) {
    const one = {};
    if (scopeIds(scope.bookId)[0]) one.bookIds = [scopeIds(scope.bookId)[0]];
    if (scopeIds(scope.authorId)[0]) one.authorIds = [scopeIds(scope.authorId)[0]];
    if (scopeIds(scope.categoryId)[0]) one.categoryIds = [scopeIds(scope.categoryId)[0]];
    return Object.keys(one).length ? [one] : [];
  }
  const books = scopeIds(scope.bookIds);
  const authors = scopeIds(scope.authorIds);
  const categories = scopeIds(scope.categoryIds);
  const out = books.map((id) => ({ bookIds: [id] }));
  // One book with its own author or category: the book alone.
  const singleBook = books.length === 1 && authors.length <= 1 && categories.length <= 1;
  if (!singleBook && (authors.length || categories.length)) {
    for (const a of authors.length ? authors : [undefined]) {
      for (const c of categories.length ? categories : [undefined]) out.push({ ...(a && { authorIds: [a] }), ...(c && { categoryIds: [c] }) });
    }
  }
  return out.slice(0, max);
};

const scopeToNusus = (scope = {}) => {
  const targets = scopeTargets(scope);
  return targets.length ? targets : undefined;
};

export const scopeLabel = (scope, catalog) => {
  const targets = scopeTargets(scope ?? {});
  if (!targets.length) return "";
  const books = [...new Set(targets.flatMap((t) => t.bookIds ?? []))];
  const authors = [...new Set(targets.flatMap((t) => t.authorIds ?? []))];
  const categories = [...new Set(targets.flatMap((t) => t.categoryIds ?? []))];
  const parts = [];
  if (books.length) parts.push(`${books.length > 1 ? "books" : "book"} ${books.map((id) => `"${catalog.book(id)?.title ?? id}"`).join(", ")}`);
  if (authors.length) parts.push(`${authors.length > 1 ? "authors" : "author"} ${authors.map((id) => `"${catalog.authorName(id) ?? id}"`).join(", ")}`);
  if (categories.length) parts.push(`${categories.length > 1 ? "categories" : "category"} ${categories.map((id) => `"${catalog.categoryTitle(id) ?? id}"`).join(", ")}`);
  return parts.join("; ");
};

// Works derived from another book (supplements, abridgements, indexes …)
// rank below the main work unless the user asked for them.
const DERIVATIVE = /^(تكملة|مختصر|تهذيب|فهرس|فهارس|تخريج|ترتيب|زوائد|منتخب|تلخيص|قرة عيون|دراسة|التعليق)/u;
const strip = (s) => s.replace(/[ً-ٰٟـ]/g, "").replace(/[أإآٱ]/g, "ا").replace(/ى/g, "ي").trim();

/** Resolves free-text book titles to catalog book ids (best match first). */
export const resolveBooks = (titles, catalog, perTitle = 1) => {
  const ids = [];
  for (const title of titles) {
    let found = [];
    try {
      found = catalog.findBooks(title, { limit: 12 });
      if (!found.length) {
        // Retry without a trailing author qualifier like "لابن قدامة" / "للزحيلي".
        const short = title.replace(/\s+(ل|لل|لابن|للإمام)\S*(\s+\S+)?$/u, "").trim();
        if (short && short !== title) found = catalog.findBooks(short, { limit: 12 });
      }
    } catch {
      found = [];
    }
    const wantDerivative = DERIVATIVE.test(strip(title));
    const ranked = found
      .map((b, rank) => {
        const t = strip(b.title);
        const penalty = !wantDerivative && DERIVATIVE.test(t) ? 100 : 0;
        return { b, score: rank + penalty + Math.max(0, t.length - strip(title).length) / 40 };
      })
      .sort((x, y) => x.score - y.score)
      .slice(0, perTitle);
    for (const { b } of ranked) if (!ids.includes(b.id)) ids.push(b.id);
  }
  return ids;
};

const toCandidate = (passage, catalog) => {
  const bookId = String(passage.book.id);
  const catalogBook = catalog.book(bookId);
  const authorId = passage.author?.id ?? catalogBook?.authorId;
  const categoryId = passage.category?.id ?? catalogBook?.categoryId;
  const snippet = passage.raw?.snip ?? passage.snippet;
  return {
    id: `${bookId}:${passage.location?.internalPage ?? passage.text.slice(0, 40)}`,
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
    excerpt: boundText(passage.text, LIMITS.excerptChars, snippet).text,
    text: boundText(passage.text, LIMITS.sourceChars, snippet).text,
    snippet: passage.snippet,
  };
};

/** Builds the list of searches for one retrieval round. */
export const searchPlan = ({ queries, scope, madhhabs = [], requestedBookIds = [], referenceBookIds = [], userScoped, limits: L = LIMITS }) => {
  const plan = [];
  // Several scope targets: every target gets the first query before any
  // gets the second, and the hits are shared out between them.
  const targets = Array.isArray(scope) ? scope : [scope];
  const take = targets.length > 1 ? Math.max(3, Math.ceil(L.hitsPerGeneral / Math.min(targets.length, 3))) : L.hitsPerGeneral;
  for (const q of queries.slice(0, L.generalQueries)) for (const t of targets) plan.push({ query: q, scope: t, take, kind: "general" });
  if (targets.length > 1) return plan.slice(0, Math.max(L.maxSearches, Math.min(targets.length * 2, 16)));
  if (!userScoped) {
    for (const id of requestedBookIds.slice(0, L.requestedBooks)) {
      for (const q of queries.slice(0, L.queriesPerRequested)) plan.push({ query: q, scope: { bookIds: [id] }, take: L.hitsPerRequested, kind: "requested" });
    }
    for (const id of referenceBookIds.slice(0, L.referenceBooks)) {
      for (const q of queries.slice(0, L.queriesPerReference)) plan.push({ query: q, scope: { bookIds: [id] }, take: L.hitsPerReference, kind: "reference" });
    }
    for (const m of madhhabs) {
      const categoryId = MADHHAB_CATEGORY[m];
      if (!categoryId) continue;
      for (const q of queries.slice(0, L.queriesPerMadhhab)) plan.push({ query: q, scope: { categoryIds: [categoryId] }, take: L.hitsPerMadhhab, kind: "madhhab" });
    }
  }
  return plan.slice(0, L.maxSearches);
};

/** Runs searches and merges their hits into a de-duplicated, interleaved candidate pool. */
export const collectCandidates = async ({ turath, catalog, plan, existing = [], limits: L = LIMITS, onSearch }) => {
  const settled = await settleAll(
    plan.map((s) => async () => {
      const value = await turath.search(s.query, { ...s.scope });
      onSearch?.(s, value);
      return value;
    }),
  );
  const failures = settled.filter((r) => !r.ok).length;
  const lists = settled.map((r, i) => (r.ok ? r.value.items.slice(0, plan[i].take) : []));
  const totalMatches = settled.reduce((sum, r) => sum + (r.ok ? r.value.totalMatches : 0), 0);
  const seen = new Set(existing.map((c) => c.id));
  const pool = [];
  // Requested books first, then interleave every list by rank.
  const order = [...plan.keys()].sort((a, b) => Number(plan[b].kind === "requested") - Number(plan[a].kind === "requested"));
  for (let round = 0; existing.length + pool.length < L.maxCandidates; round += 1) {
    let any = false;
    for (const i of order) {
      const passage = lists[i][round];
      if (!passage) continue;
      any = true;
      const candidate = toCandidate(passage, catalog);
      if (seen.has(candidate.id)) continue;
      seen.add(candidate.id);
      pool.push(candidate);
      if (existing.length + pool.length >= L.maxCandidates) break;
    }
    if (!any) break;
  }
  return { candidates: pool, totalMatches, failed: plan.length > 0 && failures === plan.length };
};

const MARKER = /\[\s*(S\d+(?:\s*[,،;]\s*S?\d+)*)\s*\]/gi;
const QUOTE_MARKER = /\[\[\s*(Q\d+)\s*\]\]/gi;

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
  // The passage around the search match, shown when no quote was verified.
  excerpt: (source.excerpt || source.text || "").slice(0, 700),
});

/** Verifies citations, renders inline quotes, renumbers markers to [1], [2] … */
export const finalize = ({ composed, sources, language }) => {
  const byKey = new Map(sources.map((s) => [s.key, s]));
  const quotes = new Map(); // source key → verified quotes
  const inline = new Map(); // Q id → { key, text }
  for (const [i, citation] of (Array.isArray(composed?.citations) ? composed.citations : []).entries()) {
    const key = String(citation?.sourceId ?? "").trim().toUpperCase();
    const source = byKey.get(key);
    if (!source) continue;
    const located = locateQuote(source.text, citation.quote);
    if (!located) continue;
    const qid = String(citation.id ?? `Q${i + 1}`).trim().toUpperCase();
    inline.set(qid, { key, text: located.text });
    const list = quotes.get(key) ?? [];
    if (list.length < 3 && !list.some((q) => q.text === located.text)) {
      list.push({ ...located, relevance: typeof citation.relevance === "string" ? citation.relevance : undefined });
    }
    quotes.set(key, list);
  }

  const status = ["answered", "partial", "insufficient"].includes(composed?.status) ? composed.status : "insufficient";
  const related = sources.slice(0, 6).map(publicSource({}));
  if (status === "insufficient" || quotes.size === 0) {
    const modelNote = status === "insufficient" && typeof composed?.answer === "string" ? composed.answer.replace(QUOTE_MARKER, "").trim() : "";
    return { status: "insufficient", answer: INSUFFICIENT[language] ?? INSUFFICIENT.en, detail: modelNote, sources: [], related, opinions: [] };
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
    // Verified quotes become Arabic block quotes with their source number;
    // unverifiable ones disappear.
    .replace(QUOTE_MARKER, (_, qid) => {
      const q = inline.get(qid.toUpperCase());
      if (!q) return "";
      return `\n> ${q.text.replace(/\s*\n\s*/g, " ")} [S${q.key.slice(1)}]\n`;
    })
    .replace(MARKER, (_, inner) => {
      const nums = inner
        .split(/[,،;]/)
        .map((part) => part.trim().toUpperCase())
        .map((part) => (part.startsWith("S") ? part : `S${part}`))
        .map(number)
        .filter((n) => n !== undefined);
      return [...new Set(nums)].map((n) => `[${n}]`).join("");
    })
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  for (const key of quotes.keys()) number(key);

  const numbered = order.map((key, i) => publicSource(quotes)(byKey.get(key), i));
  const keyToNumber = new Map(order.map((key, i) => [key, i + 1]));
  const opinions = (Array.isArray(composed.opinions) ? composed.opinions : [])
    .map((o) => ({
      holder: String(o?.holder ?? "").trim(),
      view: String(o?.view ?? "").trim(),
      sources: (Array.isArray(o?.sourceIds) ? o.sourceIds : []).map((id) => keyToNumber.get(String(id).trim().toUpperCase())).filter((n) => n !== undefined),
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

const error = (code, message) => Object.assign(new Error(message), { code });

/** Gemini output (or search) steps kept per request, so a retry resumes where it stopped. */
export const createMemo = () => new Map();

export const createPipeline = ({ gemini, turath: client, catalog }) => {
  const turath = decodingTurath(client);
  const ask = async (input, onEvent = () => {}, memo = createMemo()) => {
    const started = Date.now();
    const usage = { input: 0, output: 0, thoughts: 0, calls: 0, peak: 0 };
    const act = (kind, data = {}) => onEvent("activity", { kind, t: Date.now() - started, ...data });
    const generate = async (key, request) => {
      if (memo.has(key)) {
        act("resumed", { step: key });
        return memo.get(key);
      }
      // The user's model writes the answer; the quick steps keep the fast tier.
      const prefer = typeof input?.model === "string" && request.tier !== "fast" ? input.model : undefined;
      const result = await gemini.generateJson(prefer ? { ...request, prefer } : request);
      usage.input += result.usage?.input ?? 0;
      usage.output += result.usage?.output ?? 0;
      usage.thoughts += result.usage?.thoughts ?? 0;
      usage.calls += 1;
      usage.peak = Math.max(usage.peak, result.usage?.input ?? 0);
      onEvent("usage", { ...usage });
      memo.set(key, result);
      return result;
    };
    const bookTitle = (s) => (s.scope?.bookIds?.length === 1 ? catalog.book(s.scope.bookIds[0])?.title : undefined);
    const onSearch = (s, value) => act("search", { query: s.query, within: s.kind, book: bookTitle(s), hits: value?.totalMatches ?? 0 });
    const collect = async (key, args) => {
      if (memo.has(key)) return memo.get(key);
      const result = await collectCandidates({ ...args, onSearch });
      if (!result.failed) memo.set(key, result);
      return result;
    };
    const question = String(input?.question ?? "").trim();
    if (!question) throw error("INVALID_ARGUMENT", "question must not be empty");
    if (question.length > 2000) throw error("INVALID_ARGUMENT", "question is too long (max 2000 characters)");
    const scope = input.scope ?? {};
    const nususScope = scopeToNusus(scope);
    const history = Array.isArray(input.history) ? input.history.slice(-3) : [];
    const depth = DEPTHS[input.depth] ? input.depth : "standard";
    const L = limitsFor(depth);
    const maxSources = clampInt(input.maxSources, 3, L.maxSelected, L.maxSelected);

    // 1. plan
    onEvent("stage", { stage: "planning" });
    const plan = await generate("plan", {
      system: PLAN_SYSTEM,
      prompt: planPrompt({ question, history, scopeLabel: scopeLabel(scope, catalog) }),
      schema: PLAN_SCHEMA,
      temperature: 0.1,
      tier: "fast",
    });
    const p = plan.data ?? {};
    const queries = cleanQueries(p.queries);
    const requested = LANG_CODES.has(input.language) ? input.language : undefined;
    const detected = LANG_CODES.has(p.detectedLanguage) ? p.detectedLanguage : undefined;
    const language = requested ?? detected ?? (LANG_CODES.has(input.fallbackLanguage) ? input.fallbackLanguage : "en");
    const madhhabs = [...new Set([...(Array.isArray(p.madhhabs) ? p.madhhabs : []), ...namedMadhhabs(question)])].filter((m) => MADHHAB_CATEGORY[m]);
    const requestedBookIds = resolveBooks(cleanTitles(p.requestedBooks, LIMITS.requestedBooks), catalog, 2);
    const referenceBookIds = resolveBooks(cleanTitles(p.referenceBooks, 6), catalog, 1).filter((id) => !requestedBookIds.includes(id));
    const standalone = typeof p.standaloneQuestion === "string" && p.standaloneQuestion.trim() ? p.standaloneQuestion.trim() : question;
    const plannedBooks = [...requestedBookIds, ...referenceBookIds].map((id) => catalog.book(id)?.title).filter(Boolean);
    onEvent("plan", { queries, language, books: plannedBooks });
    act("plan", { queries, books: plannedBooks, madhhabs });

    const done = (result, extra = {}) => ({ ...result, queries, language, depth, model: plan.model, elapsedMs: Date.now() - started, usage: { ...usage }, ...extra });
    if (!queries.length) return done(finalize({ composed: { status: "insufficient" }, sources: [], language }));

    // 2. search
    onEvent("stage", { stage: "searching" });
    const first = await collect("search0", {
      turath,
      catalog,
      limits: L,
      plan: searchPlan({ queries, scope: nususScope, madhhabs, requestedBookIds, referenceBookIds, userScoped: Boolean(nususScope), limits: L }),
    });
    if (first.failed) throw error("TURATH_UNAVAILABLE", "The Turath library could not be reached");
    let candidates = first.candidates.map((c, i) => ({ ...c, key: `C${i + 1}` }));
    let totalMatches = first.totalMatches;
    onEvent("sources", { count: candidates.length, totalMatches });
    act("found", { count: candidates.length, total: totalMatches });
    if (!candidates.length) return done(finalize({ composed: { status: "insufficient" }, sources: [], language }), { totalMatches });

    // 3. read: rank, then follow-up rounds if something is missing
    onEvent("stage", { stage: "reading" });
    const rank = async (key, pool, usedQueries) => {
      act("rank", { pool: pool.length });
      const ranked =
        (
          await generate(key, {
            system: RERANK_SYSTEM,
            prompt: rerankPrompt({ question: standalone, candidates: pool, queries: usedQueries }),
            schema: RERANK_SCHEMA,
            temperature: 0.1,
          })
        ).data ?? {};
      act("ranked", { selected: Array.isArray(ranked.selected) ? ranked.selected.length : 0, coverage: ranked.coverage, missing: typeof ranked.missing === "string" ? ranked.missing.slice(0, 200) : undefined });
      return ranked;
    };
    let usedQueries = [...queries];
    let ranking = await rank("rank0", candidates, usedQueries);
    // Follow-up rounds: the reader names what is still missing (deeper research allows more rounds).
    for (let round = 0; round < L.followUpRounds && ranking.coverage !== "full"; round += 1) {
      const followQueries = cleanQueries(ranking.followUpQueries, 5).filter((q) => !usedQueries.includes(q));
      const followBooks = resolveBooks(cleanTitles(ranking.followUpBooks, 4), catalog, 1);
      if (!followQueries.length && !followBooks.length) break;
      onEvent("stage", { stage: "searching" });
      act("followup", { queries: followQueries, books: followBooks.map((id) => catalog.book(id)?.title).filter(Boolean) });
      const selectedFirst = new Set((ranking.selected ?? []).map((k) => String(k).toUpperCase()));
      const keep = candidates.filter((c) => selectedFirst.has(c.key));
      const extra = await collect(`search${round + 1}`, {
        turath,
        catalog,
        existing: keep,
        limits: L,
        plan: searchPlan({
          queries: followQueries.length ? followQueries : queries.slice(0, 3),
          scope: nususScope,
          requestedBookIds: followBooks,
          madhhabs: [],
          userScoped: Boolean(nususScope),
          limits: L,
        }),
      });
      totalMatches += extra.totalMatches;
      if (!extra.candidates.length) break;
      usedQueries = [...usedQueries, ...followQueries];
      candidates = [...keep, ...extra.candidates].map((c, i) => ({ ...c, key: `C${i + 1}` }));
      onEvent("sources", { count: candidates.length, totalMatches });
      onEvent("stage", { stage: "reading" });
      ranking = await rank(`rank${round + 1}`, candidates, usedQueries);
    }
    const byKey = new Map(candidates.map((c) => [c.key, c]));
    let selected = [...new Set((ranking.selected ?? []).map((k) => String(k).trim().toUpperCase()))].map((k) => byKey.get(k)).filter(Boolean);
    if (!selected.length && ranking.coverage !== "none") selected = candidates.slice(0, Math.min(6, candidates.length));
    selected = selected.slice(0, maxSources);
    if (!selected.length) {
      return done(finalize({ composed: { status: "insufficient" }, sources: candidates.slice(0, 6).map((c, i) => ({ ...c, key: `S${i + 1}` })), language }), { totalMatches });
    }
    const expanded = typeof turath.getPage === "function" ? await addContinuations({ turath, catalog, selected, limit: L.continuationPages }) : selected;
    const sources = expanded.map((c, i) => ({ ...c, key: `S${i + 1}` }));
    act("read", { books: [...new Set(sources.map((s) => s.bookTitle))].slice(0, 8), pages: sources.length });

    // 4. compose (streamed: the draft answer is shown while it is written)
    onEvent("stage", { stage: "composing" });
    act("compose", { sources: sources.length });
    let lastDraft = 0;
    const composed = await generate("compose", {
      onText: (text) => {
        if (Date.now() - lastDraft < 350) return;
        lastDraft = Date.now();
        const draft = partialJsonString(text, "answer");
        if (draft) onEvent("draft", { text: draft });
      },
      system: composeSystem(LANGUAGES[language]),
      prompt: composePrompt({ question: standalone, history, sources, languageName: LANGUAGES[language], missing: ranking.coverage === "full" ? "" : ranking.missing }),
      schema: COMPOSE_SCHEMA,
      temperature: 0.2,
    });

    // 5. verify
    onEvent("stage", { stage: "verifying" });
    act("verify", {});
    return done(finalize({ composed: composed.data, sources, language }), { totalMatches, model: composed.model });
  };
  return { ask };
};
