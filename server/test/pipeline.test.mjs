import assert from "node:assert/strict";
import { test } from "node:test";
import { catalog } from "../src/catalog.mjs";
import { createPipeline, INSUFFICIENT, namedMadhhabs, resolveBooks, searchPlan } from "../src/pipeline.mjs";
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
