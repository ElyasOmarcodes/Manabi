import assert from "node:assert/strict";
import { test } from "node:test";
import { catalog } from "../src/catalog.mjs";
import { createPipeline, INSUFFICIENT } from "../src/pipeline.mjs";
import { fixtures, fixtureTurath, scriptedGemini } from "./helpers.mjs";
import { normalizeArabic } from "../src/verify.mjs";

const plan = (over = {}) => ({
  standaloneQuestion: "د نیت حدیث څه دی؟",
  detectedLanguage: "ps",
  questionType: "hadith",
  isIslamicStudies: true,
  queries: ["إنما الأعمال بالنيات", "النية"],
  ...over,
});

const findKey = (request, page) => {
  const m = new RegExp(`\\[(S\\d+)\\] Book: [^\\n]*Page: ${page}\\b`).exec(request.prompt);
  assert.ok(m, `source for page ${page} not in prompt`);
  return m[1];
};

test("answer is grounded: metadata comes from Turath and quotes from the real page", async () => {
  const gemini = scriptedGemini(plan(), (request) => {
    const key = findKey(request, 5);
    return {
      status: "answered",
      answer: `دا حدیث په الأربعون النووية کې راغلی دی [${key}]. [S99]`,
      summary: "د نیت حدیث",
      citations: [
        { sourceId: key, quote: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى", relevance: "اصلي متن" },
        { sourceId: key, quote: "هذا نص مختلق لا يوجد في الكتاب أصلا", relevance: "x" },
      ],
      opinions: [],
    };
  });
  const pipeline = createPipeline({ gemini, turath: fixtureTurath(), catalog });
  const events = [];
  const result = await pipeline.ask({ question: "د نیت حدیث څه دی؟", language: "ps" }, (e, d) => events.push([e, d]));

  assert.equal(result.status, "answered");
  assert.equal(result.language, "ps");
  assert.match(result.answer, /\[1\]/);
  assert.doesNotMatch(result.answer, /S99|\[S/);
  assert.equal(result.sources.length, 1);
  const [source] = result.sources;
  assert.equal(source.n, 1);
  assert.equal(source.bookId, "147927");
  assert.equal(source.bookTitle, "الأربعون النووية مع زيادات ابن رجب");
  assert.equal(source.authorName, "النووي");
  assert.equal(source.volume, "1");
  assert.equal(source.printedPage, 5);
  assert.equal(source.internalPage, 5);
  assert.equal(source.url, "https://app.turath.io/book/147927?page=5");
  assert.equal(source.shamelaUrl, "https://shamela.ws/book/147927/5");
  assert.equal(source.quotes.length, 1, "fabricated quote must be dropped");
  assert.equal(normalizeArabic(source.quotes[0].text), "انما الاعمال بالنيات وانما لكل امري ما نوي");
  assert.ok(fixtures.page5.text.includes(source.quotes[0].text));
  assert.deepEqual(
    events.filter(([e]) => e === "stage").map(([, d]) => d.stage),
    ["planning", "searching", "composing", "verifying"],
  );
});

test("an answer whose quotes cannot be verified is downgraded to insufficient", async () => {
  const gemini = scriptedGemini(plan({ detectedLanguage: "en" }), {
    status: "answered",
    answer: "Invented answer [S1].",
    citations: [{ sourceId: "S1", quote: "قال رسول الله صلى الله عليه وسلم من غش فليس منا والمكر والخداع في النار" }],
  });
  const pipeline = createPipeline({ gemini, turath: fixtureTurath(), catalog });
  const result = await pipeline.ask({ question: "What is the hadith of intention?", language: "auto" });
  assert.equal(result.status, "insufficient");
  assert.equal(result.answer, INSUFFICIENT.en);
  assert.equal(result.sources.length, 0);
  assert.ok(result.related.length > 0, "searched sources are still listed for inspection");
});

test("no Turath matches means no Gemini answer at all", async () => {
  const gemini = scriptedGemini(plan({ detectedLanguage: "fa" }));
  const pipeline = createPipeline({ gemini, turath: fixtureTurath({ emptySearch: true }), catalog });
  const result = await pipeline.ask({ question: "سوال", language: "fa" });
  assert.equal(result.status, "insufficient");
  assert.equal(result.answer, INSUFFICIENT.fa);
  assert.equal(gemini.prompts.length, 1, "compose step must not run without sources");
});

test("fiqh questions also search the four madhhab categories", async () => {
  const scopes = [];
  const turath = fixtureTurath();
  const spy = { ...turath, retrieve: (q, o) => (scopes.push(o.scope), turath.retrieve(q, o)) };
  const gemini = scriptedGemini(plan({ questionType: "fiqh" }), { status: "insufficient", answer: "", citations: [] });
  await createPipeline({ gemini, turath: spy, catalog }).ask({ question: "q", language: "ar" });
  const cats = scopes.filter((s) => s?.categoryIds).map((s) => s.categoryIds[0]);
  assert.deepEqual([...new Set(cats)].sort(), ["14", "15", "16", "17"]);
});

test("scope restricts the search to one book", async () => {
  const scopes = [];
  const turath = fixtureTurath();
  const spy = { ...turath, retrieve: (q, o) => (scopes.push(o.scope), turath.retrieve(q, o)) };
  const gemini = scriptedGemini(plan({ questionType: "fiqh" }), { status: "insufficient", answer: "", citations: [] });
  await createPipeline({ gemini, turath: spy, catalog }).ask({ question: "q", scope: { bookId: "12836" } });
  assert.ok(scopes.every((s) => s?.bookIds?.[0] === "12836"));
  assert.match(gemini.prompts[0].prompt, /الأربعون النووية/);
});

test("Turath outage surfaces as TURATH_UNAVAILABLE", async () => {
  const gemini = scriptedGemini(plan());
  const pipeline = createPipeline({ gemini, turath: fixtureTurath({ fail: true }), catalog });
  await assert.rejects(pipeline.ask({ question: "q" }), (e) => e.code === "TURATH_UNAVAILABLE");
});

test("input validation", async () => {
  const pipeline = createPipeline({ gemini: scriptedGemini(), turath: fixtureTurath(), catalog });
  await assert.rejects(pipeline.ask({ question: "  " }), (e) => e.code === "INVALID_ARGUMENT");
  await assert.rejects(pipeline.ask({ question: "x".repeat(2001) }), (e) => e.code === "INVALID_ARGUMENT");
});
