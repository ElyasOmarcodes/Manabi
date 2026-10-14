import assert from "node:assert/strict";
import { test } from "node:test";
import { catalog } from "../src/catalog.mjs";
import { chapterPages, chapterSpan, createPipeline, expansionPages, findChapter, hintTitles, focusBooks, INSUFFICIENT, limitsFor, namedMadhhabs, relatedWorks, resolveAuthors, resolveBooks, searchPlan } from "../src/pipeline.mjs";
import { normalizeArabic } from "../src/verify.mjs";
import { fixtures, fixtureTurath, scriptedGemini } from "./helpers.mjs";

const plan = (over = {}) => ({
  standaloneQuestion: "د نیت حدیث څه دی؟",
  detectedLanguage: "ps",
  questionType: "hadith",
  isIslamicStudies: true,
  queries: ["إنما الأعمال بالنيات", "النية"],
  madhhabs: [],
  requestedBooks: [],
  referenceBooks: [],
  ...over,
});

const keyFor = (prompt, page, prefix) => {
  const m = new RegExp(`\\[(${prefix}\\d+)\\] Book: [^\\n]*Page: ${page}\\b`).exec(prompt);
  assert.ok(m, `candidate for page ${page} not in prompt`);
  return m[1];
};

const selectPage = (page) => (request) => ({ selected: [keyFor(request.prompt, page, "C")], coverage: "full", followUpQueries: [], followUpBooks: [] });

test("grounded answer: metadata from Turath, quotes inline and verified", async () => {
  const gemini = scriptedGemini(plan(), selectPage(5), (request) => {
    const key = keyFor(request.prompt, 5, "S");
    return {
      status: "answered",
      answer: `دا حدیث په الأربعون النووية کې راغلی دی [${key}].\n[[Q1]]\n[[Q2]]\nپای [S99].`,
      summary: "د نیت حدیث",
      citations: [
        { id: "Q1", sourceId: key, quote: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى", relevance: "اصلي متن" },
        { id: "Q2", sourceId: key, quote: "هذا نص مختلق لا يوجد في الكتاب أصلا ولا في غيره", relevance: "x" },
      ],
      opinions: [],
    };
  });
  const pipeline = createPipeline({ gemini, turath: fixtureTurath(), catalog });
  const events = [];
  const result = await pipeline.ask({ question: "د نیت حدیث څه دی؟", language: "ps" }, (e, d) => events.push([e, d]));

  assert.equal(result.status, "answered");
  assert.equal(result.language, "ps");
  assert.match(result.answer, /^دا حدیث .*\[1\]\./);
  assert.doesNotMatch(result.answer, /S99|\[S|\[\[/);
  const quoteLines = result.answer.split("\n").filter((l) => l.startsWith("> "));
  assert.equal(quoteLines.length, 1, "verified quote inline, fabricated one removed");
  assert.match(quoteLines[0], / \[1\]$/);
  assert.ok(fixtures.page5.text.includes(quoteLines[0].slice(2).replace(/ \[1\]$/, "")), "inline quote is a verbatim slice of the page");
  assert.equal(result.sources.length, 1);
  const [source] = result.sources;
  assert.equal(source.bookTitle, "الأربعون النووية مع زيادات ابن رجب");
  assert.equal(source.authorName, "النووي");
  assert.equal(source.volume, "1");
  assert.equal(source.printedPage, 5);
  assert.equal(source.url, "https://app.turath.io/book/147927?page=5");
  assert.equal(source.quotes.length, 1);
  assert.equal(normalizeArabic(source.quotes[0].text), "انما الاعمال بالنيات وانما لكل امري ما نوي");
  assert.deepEqual(
    [...new Set(events.filter(([e]) => e === "stage").map(([, d]) => d.stage))],
    ["planning", "searching", "reading", "composing", "verifying"],
  );
});

test("an answer whose quotes cannot be verified is downgraded to insufficient", async () => {
  const gemini = scriptedGemini(plan({ detectedLanguage: "en" }), selectPage(5), {
    status: "answered",
    answer: "Invented answer [S1].\n[[Q1]]",
    citations: [{ id: "Q1", sourceId: "S1", quote: "قال رسول الله صلى الله عليه وسلم من غش فليس منا والمكر والخداع في النار" }],
  });
  const result = await createPipeline({ gemini, turath: fixtureTurath(), catalog }).ask({ question: "What is the hadith of intention?", language: "auto" });
  assert.equal(result.status, "insufficient");
  assert.equal(result.answer, INSUFFICIENT.en);
  assert.equal(result.sources.length, 0);
  assert.ok(result.related.length > 0);
});

test("no Turath matches means no reading or composing", async () => {
  const gemini = scriptedGemini(plan({ detectedLanguage: "fa" }));
  const result = await createPipeline({ gemini, turath: fixtureTurath({ emptySearch: true }), catalog }).ask({ question: "سوال", language: "fa" });
  assert.equal(result.status, "insufficient");
  assert.equal(result.answer, INSUFFICIENT.fa);
  assert.equal(gemini.prompts.length, 1);
});

test("reading step can trigger one follow-up search round", async () => {
  const searches = [];
  const turath = fixtureTurath();
  const spy = { ...turath, search: (q, o) => (searches.push(q), turath.search(q, o)) };
  const compose = (request) => {
    const key = keyFor(request.prompt, 5, "S");
    return { status: "answered", answer: `x [${key}]\n[[Q1]]`, citations: [{ id: "Q1", sourceId: key, quote: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى" }] };
  };
  const gemini = scriptedGemini(
    plan({ queries: ["الإسلام"] }),
    { selected: [], coverage: "partial", missing: "intention", followUpQueries: ["النيات"], followUpBooks: [] },
    selectPage(5),
    compose,
  );
  const result = await createPipeline({ gemini, turath: spy, catalog }).ask({ question: "q", language: "ar" });
  assert.ok(searches.includes("النيات"), "follow-up query was searched");
  assert.equal(result.status, "answered");
  assert.equal(gemini.prompts.length, 4);
});

test("search plan covers requested books, reference books and schools", () => {
  const p = searchPlan({ queries: ["a", "b", "c", "d"], madhhabs: ["hanafi", "shafii"], requestedBookIds: ["1"], referenceBookIds: ["2", "3"], userScoped: false });
  assert.ok(p.some((s) => s.kind === "requested" && s.scope.bookIds[0] === "1"));
  assert.ok(p.some((s) => s.kind === "reference" && s.scope.bookIds[0] === "3"));
  assert.deepEqual([...new Set(p.filter((s) => s.kind === "madhhab").map((s) => s.scope.categoryIds[0]))], ["14", "16"]);
  const scoped = searchPlan({ queries: ["a"], scope: { bookIds: ["9"] }, madhhabs: ["hanafi"], requestedBookIds: ["1"], userScoped: true });
  assert.ok(scoped.every((s) => s.kind === "general" && s.scope.bookIds[0] === "9"), "a user scope is strict");
});

test("book titles resolve through the offline catalog", () => {
  const [id] = resolveBooks(["الأربعون النووية"], catalog);
  assert.equal(id, "12836");
  assert.deepEqual(resolveBooks(["كتاب لا وجود له إطلاقا في الفهرس"], catalog), []);
});

test("scope restricts every search", async () => {
  const scopes = [];
  const turath = fixtureTurath();
  const spy = { ...turath, search: (q, o) => (scopes.push(o), turath.search(q, o)) };
  const gemini = scriptedGemini(plan({ questionType: "fiqh", madhhabs: ["hanafi"], referenceBooks: ["رد المحتار"] }), { selected: [], coverage: "none", followUpQueries: [], followUpBooks: [] });
  await createPipeline({ gemini, turath: spy, catalog }).ask({ question: "q", scope: { bookId: "12836" } });
  assert.ok(scopes.length > 0 && scopes.every((s) => s.bookIds?.[0] === "12836"));
  assert.match(gemini.prompts[0].prompt, /الأربعون النووية/);
});

test("Turath outage surfaces as TURATH_UNAVAILABLE", async () => {
  const pipeline = createPipeline({ gemini: scriptedGemini(plan()), turath: fixtureTurath({ fail: true }), catalog });
  await assert.rejects(pipeline.ask({ question: "q" }), (e) => e.code === "TURATH_UNAVAILABLE");
});

test("input validation", async () => {
  const pipeline = createPipeline({ gemini: scriptedGemini(), turath: fixtureTurath(), catalog });
  await assert.rejects(pipeline.ask({ question: "  " }), (e) => e.code === "INVALID_ARGUMENT");
  await assert.rejects(pipeline.ask({ question: "x".repeat(2001) }), (e) => e.code === "INVALID_ARGUMENT");
});

test("the page after a selected source is added as its own source", async () => {
  let composePrompt = "";
  const gemini = scriptedGemini(plan(), selectPage(5), (request) => {
    composePrompt = request.prompt;
    const key = keyFor(request.prompt, 6, "S");
    return { status: "insufficient", answer: `${key}`, citations: [] };
  });
  await createPipeline({ gemini, turath: fixtureTurath(), catalog }).ask({ question: "q", language: "ar" });
  assert.match(composePrompt, /\[S1\] Book: [^\n]*Page: 5\b/);
  assert.match(composePrompt, /\[S2\] Book: [^\n]*Page: 6\b/, "continuation page 6 follows page 5");
});

test("schools named in the question are detected", () => {
  assert.deepEqual(namedMadhhabs("د حنفي مذهب علماء څه فرمايي"), ["hanafi"]);
  assert.deepEqual(namedMadhhabs("What do the Shafi'is and Hanbalis say?"), ["shafii", "hanbali"]);
  assert.deepEqual(namedMadhhabs("حدیث نیت"), []);
});

test("research depth changes how wide the search goes", () => {
  const queries = ["a", "b", "c", "d", "e", "f", "g", "h"];
  const count = (depth) => searchPlan({ queries, madhhabs: ["hanafi"], referenceBookIds: ["1", "2", "3", "4", "5", "6"], userScoped: false, limits: limitsFor(depth) }).length;
  assert.ok(count("quick") < count("standard") && count("standard") < count("deep"));
  assert.equal(limitsFor("quick").followUpRounds, 0);
  assert.equal(limitsFor("nonsense").maxSelected, limitsFor("standard").maxSelected);
});

test("quick research skips the follow-up round", async () => {
  const gemini = scriptedGemini(
    plan({ queries: ["الإسلام"] }),
    { selected: [], coverage: "partial", missing: "intention", followUpQueries: ["النيات"], followUpBooks: [] },
    { status: "insufficient", answer: "", citations: [] },
  );
  const result = await createPipeline({ gemini, turath: fixtureTurath(), catalog }).ask({ question: "q", language: "ar", depth: "quick" });
  assert.equal(gemini.prompts.length, 3, "plan, one ranking and compose: no follow-up search");
  assert.equal(result.depth, "quick");
});

test("progress: activity log, token usage, a streamed draft, and a retry resumes finished steps", async () => {
  const composeAnswer = (request) => {
    const key = keyFor(request.prompt, 5, "S");
    return { status: "answered", answer: `ځواب [${key}].\n[[Q1]]`, summary: "", citations: [{ id: "Q1", sourceId: key, quote: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى" }], opinions: [] };
  };
  const calls = [];
  let failCompose = true;
  const scripted = { plan: plan(), rank: selectPage(5) };
  const gemini = {
    resolveModel: async () => "test-model",
    generateJson: async (request) => {
      const step = request.schema?.properties?.queries ? "plan" : request.schema?.properties?.coverage ? "rank" : "compose";
      calls.push(step);
      if (step === "compose") {
        if (failCompose) throw Object.assign(new Error("Could not reach Gemini"), { code: "NETWORK" });
        request.onText?.('{"status":"answered","answer":"ځواب په');
      }
      const data = step === "compose" ? composeAnswer(request) : typeof scripted[step] === "function" ? scripted[step](request) : scripted[step];
      return { data, model: "test-model", usage: { input: 100, output: 10, thoughts: 5 } };
    },
  };
  const pipeline = createPipeline({ gemini, turath: fixtureTurath(), catalog });
  const memo = new Map();
  const events = [];
  await assert.rejects(pipeline.ask({ question: "د نیت حدیث څه دی؟", language: "ps" }, (e, d) => events.push([e, d]), memo));
  assert.deepEqual(calls, ["plan", "rank", "compose"]);
  const kinds = events.filter(([e]) => e === "activity").map(([, d]) => d.kind);
  for (const k of ["plan", "search", "found", "rank", "ranked", "read", "compose"]) assert.ok(kinds.includes(k), `activity ${k}`);
  assert.deepEqual(events.filter(([e]) => e === "usage").at(-1)[1], { input: 200, output: 20, thoughts: 10, calls: 2, peak: 100 });

  // The retry with the same memo only asks Gemini to write the answer again.
  failCompose = false;
  calls.length = 0;
  events.length = 0;
  const result = await pipeline.ask({ question: "د نیت حدیث څه دی؟", language: "ps" }, (e, d) => events.push([e, d]), memo);
  assert.deepEqual(calls, ["compose"]);
  assert.equal(result.status, "answered");
  assert.equal(result.usage.calls, 1);
  assert.ok(events.some(([e, d]) => e === "draft" && d.text === "ځواب په"));
});

test("scope targets: each book, and each author within each category", async () => {
  const { scopeTargets, searchPlan } = await import("../src/pipeline.mjs");
  assert.deepEqual(scopeTargets({ bookId: "5", authorId: "9" }), [{ bookIds: ["5"], authorIds: ["9"] }]);
  assert.deepEqual(scopeTargets({ bookIds: "5,6", authorIds: [], categoryIds: [] }), [{ bookIds: ["5"] }, { bookIds: ["6"] }]);
  assert.deepEqual(scopeTargets({ bookIds: "5", authorIds: "9", categoryIds: "" }), [{ bookIds: ["5"] }]);
  assert.deepEqual(scopeTargets({ bookIds: ["5"], authorIds: "1,2", categoryIds: "30" }), [
    { bookIds: ["5"] },
    { authorIds: ["1"], categoryIds: ["30"] },
    { authorIds: ["2"], categoryIds: ["30"] },
  ]);
  assert.deepEqual(scopeTargets({ bookIds: "x,0", authorIds: "" }), []);
  const plan = searchPlan({ queries: ["a", "b"], scope: [{ bookIds: ["5"] }, { bookIds: ["6"] }], userScoped: true });
  assert.deepEqual(plan.map((s) => [s.query, s.scope.bookIds[0]]), [["a", "5"], ["a", "6"], ["b", "5"], ["b", "6"]]);
});

test("the chapter on a topic is found in the table of contents", () => {
  const toc = [
    { title: "ربع العبادات", level: 1, page: 1 },
    { title: "باب فضل التوبة في الحج", level: 3, page: 40 },
    { title: "ربع المنجيات", level: 1, page: 1150 },
    { title: "كتاب التوبة", level: 2, page: 1160 },
    { title: "الركن الأول في نفس التوبة", level: 3, page: 1161 },
    { title: "بيان حقيقة التوبة", level: 4, page: 1161 },
    { title: "الركن الثاني فيما عنه التوبة", level: 3, page: 1175 },
    { title: "الركن الثالث في تمام التوبة", level: 3, page: 1190 },
    { title: "كتاب الصبر والشكر", level: 2, page: 1219 },
  ];
  const found = findChapter(toc, ["التوبة"]);
  assert.equal(found.chapter.title, "كتاب التوبة");
  assert.deepEqual(found.sections.map((x) => x.page), [1161, 1161, 1175, 1190]);
  assert.deepEqual(chapterPages(found, 4), [1160, 1161, 1175, 1190]);
  assert.deepEqual(chapterPages(found, 2), [1160, 1161]);
  assert.equal(findChapter(toc, ["الزكاة"]), undefined);
  assert.equal(findChapter(toc, []), undefined);
});

test("scholars resolve to authors, and their most found main book is read", () => {
  const ids = resolveAuthors(["أبو حامد الغزالي"], catalog);
  assert.equal(ids[0], "619");
  const candidates = [
    { bookId: "1", bookTitle: "مختصر كتاب", authorId: "619" },
    { bookId: "1", bookTitle: "مختصر كتاب", authorId: "619" },
    { bookId: "2", bookTitle: "إحياء علوم الدين", authorId: "619" },
    { bookId: "3", bookTitle: "كتاب آخر", authorId: "7" },
  ];
  assert.deepEqual(focusBooks({ authorIds: ["619"], candidates }), ["2"]);
  assert.deepEqual(focusBooks({ requestedBookIds: ["9"], authorIds: ["619"], candidates, max: 2 }), ["9", "2"]);
});

test("works built on a book are its abridgements, not its indexes", () => {
  const ids = relatedWorks("9472", catalog);
  assert.ok(ids.includes("22842"), "موعظة المؤمنين من إحياء علوم الدين");
  assert.ok(!ids.includes("38171"), "تخريج أحاديث الإحياء is not an abridgement");
  assert.ok(!ids.includes("9472"));
});

test("author searches join the plan", () => {
  const p = searchPlan({ queries: ["a", "b"], requestedAuthorIds: ["619"], userScoped: false });
  assert.ok(p.some((s) => s.kind === "requested" && s.scope.authorIds?.[0] === "619"));
});

test("a scoped book's chapter is read, the format and outline reach the writer", async () => {
  const compose = (request) => {
    assert.match(request.prompt, /FORMAT: posts/);
    assert.match(request.prompt, /CHAPTER OUTLINE[^]*\[الأحاديث\]/);
    const key = keyFor(request.prompt, 5, "S");
    return { status: "answered", answer: `### 1 — نیت\nx [${key}]\n[[Q1]]`, citations: [{ id: "Q1", sourceId: key, quote: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى" }] };
  };
  const gemini = scriptedGemini(
    plan({ chapterTerms: ["الأحاديث"], answerFormat: "posts", requestedAuthors: [] }),
    (request) => {
      assert.match(request.prompt, /Chapter read/);
      return { selected: [], coverage: "full", followUpQueries: [], followUpBooks: [] };
    },
    compose,
  );
  const events = [];
  const result = await createPipeline({ gemini, turath: fixtureTurath(), catalog }).ask(
    { question: "q", language: "ps", scope: { bookIds: ["147927"] } },
    (e, d) => events.push([e, d]),
  );
  assert.equal(result.status, "answered");
  assert.ok(events.some(([e, d]) => e === "activity" && d.kind === "chapter" && d.chapter === "[الأحاديث]"));
});

test("each post keeps the quotation of the source it cites", async () => {
  const { realignQuotes } = await import("../src/pipeline.mjs");
  const answer = "مقدمه [S1]\n### 1 — الف\nمتن [S1]\n[[Q2]]\n### 2 — ب\nمتن [S2]\n[[Q3]]\n### 3 — ج\nمتن [S3]\n[[Q1]]\n### 4 — د\nمتن [S4]\n[[Q4]]";
  const sourceOf = new Map([["Q1", "S1"], ["Q2", "S2"], ["Q3", "S3"], ["Q4", "S4"]]);
  const fixed = realignQuotes(answer, sourceOf);
  assert.deepEqual([...fixed.matchAll(/\[\[(Q\d)\]\]/g)].map((m) => m[1]), ["Q1", "Q2", "Q3", "Q4"]);
  // Nothing to fix: unchanged.
  assert.equal(realignQuotes(fixed, sourceOf), fixed);
  // A part citing a source with no quote keeps what it has.
  assert.equal(realignQuotes("### x\nمتن [S9]\n[[Q1]]", sourceOf), "### x\nمتن [S9]\n[[Q1]]");
});

// A small book: chapter "فتح المدائن" on pages 9-13, the next chapter from 14.
const storyTurath = () => {
  const reads = [];
  const passage = (page) => ({
    book: { id: 900001, title: "تاريخ الرسل والملوك" },
    author: { id: 7, name: "الطبري" },
    location: { internalPage: page, printedPage: page },
    text: `صفحة ${page}: فلما رأى أهل المدائن الخيل تعبر دجلة قالوا ديوان آمد ديوان آمد ثم هربوا وتركوا المدائن ودخلها المسلمون.`,
    headings: [],
    citation: `الطبري ${page}`,
  });
  return {
    reads,
    search: async () => ({ items: [passage(10)], totalMatches: 1 }),
    getPage: async (_id, page) => {
      reads.push(page);
      return passage(page);
    },
    getBook: async () => ({ title: "تاريخ الرسل والملوك", toc: [{ title: "ذكر فتح المدائن", page: 9, level: 1 }, { title: "عبور دجلة", page: 10, level: 2 }, { title: "ذكر جلولاء", page: 14, level: 1 }] }),
  };
};

test("chapter of a page from the table of contents, and the pages read around a hit", () => {
  const toc = [{ title: "كتاب المغازي", page: 1, level: 1 }, { title: "باب غزوة أحد", page: 9, level: 2 }, { title: "فصل", page: 9, level: 3 }, { title: "باب الخندق", page: 14, level: 2 }];
  assert.deepEqual(chapterSpan(toc, 11), { title: "فصل", start: 9, end: 13 });
  assert.deepEqual(chapterSpan(toc, 3), { title: "كتاب المغازي", start: 1, end: undefined });
  assert.equal(chapterSpan(toc.slice(1), 3), undefined);
  assert.deepEqual(expansionPages({ start: 9, end: 13 }, 11, 3), [10, 12, 13]);
  assert.deepEqual(expansionPages({ start: 11, end: 11 }, 11, 3), [10, 12], "a one-page section reads its neighbours");
  assert.deepEqual(expansionPages(undefined, 5, 2), [4, 6]);
});

test("book titles from the web step", () => {
  const text = "1. تاريخ الرسل والملوك — الطبري — ذكر فتح المدائن\n- «البداية والنهاية» — ابن كثير\n* الكامل في التاريخ | ابن الأثير\nThis is about the conquest.\n";
  assert.deepEqual(hintTitles(text), ["تاريخ الرسل والملوك", "البداية والنهاية", "الكامل في التاريخ"]);
});

test("the reader asks for the rest of a chapter: its pages are read and judged in the next round", async () => {
  const turath = storyTurath();
  const gemini = scriptedGemini(
    plan({ queries: ["ديوان آمد"] }),
    { selected: ["C1"], coverage: "partial", missing: "the rest of the story", expand: ["C1"], followUpQueries: [], followUpBooks: [] },
    (request) => {
      for (const page of [11, 12, 13]) keyFor(request.prompt, page, "C");
      return { selected: ["C1", "C2"], coverage: "full", expand: [], followUpQueries: [], followUpBooks: [] };
    },
    { status: "insufficient", answer: "", citations: [] },
  );
  const acts = [];
  await createPipeline({ gemini, turath, catalog }).ask({ question: "د سعد د دجلې د تېرېدو کیسه", language: "ps" }, (event, data) => event === "activity" && acts.push(data));
  assert.equal(gemini.prompts.length, 4, "plan, two rankings, compose");
  assert.deepEqual(turath.reads.filter((p) => p !== 10).slice(0, 3), [11, 12, 13], "the section of the hit, after it");
  assert.ok(acts.some((a) => a.kind === "expand" && a.chapter === "عبور دجلة" && a.pages === 3));

  const off = scriptedGemini(plan({ queries: ["ديوان آمد"] }), { selected: ["C1"], coverage: "partial", expand: ["C1"], followUpQueries: [], followUpBooks: [] }, { status: "insufficient", answer: "", citations: [] });
  await createPipeline({ gemini: off, turath: storyTurath(), catalog, features: { expand: false } }).ask({ question: "q", language: "ps" });
  assert.equal(off.prompts.length, 3, "without expansion there is no next step");
});

test("books named by the web step are searched; the web call runs beside the plan", async () => {
  const turath = storyTurath();
  const searched = [];
  const search = turath.search;
  turath.search = async (q, scope) => {
    searched.push(scope?.bookIds?.[0]);
    return search(q, scope);
  };
  const gemini = scriptedGemini(plan({ queries: ["ديوان آمد"] }), { selected: ["C1"], coverage: "full", expand: [], followUpQueries: [], followUpBooks: [] }, { status: "insufficient", answer: "", citations: [] });
  let webAsked;
  gemini.generateText = async (request) => {
    webAsked = request;
    return { text: "صحيح البخاري — البخاري", model: "test-model", usage: { input: 10, output: 5 } };
  };
  const result = await createPipeline({ gemini, turath, catalog }).ask({ question: "د سعد د دجلې د تېرېدو کیسه څه ده", language: "ps" });
  assert.equal(webAsked.search, true);
  const bukhari = resolveBooks(["صحيح البخاري"], catalog)[0];
  assert.ok(bukhari && searched.includes(bukhari), "the named book was searched");
  assert.equal(result.usage.calls, 4, "the web call is counted");
});
