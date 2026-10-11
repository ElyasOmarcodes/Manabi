import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { createApp, createRateLimiter } from "../src/app.mjs";
import { catalog } from "../src/catalog.mjs";
import { createPipeline } from "../src/pipeline.mjs";
import { normalizeArabic } from "../src/verify.mjs";
import { fixtureTurath, scriptedGemini } from "./helpers.mjs";

const config = { allowedOrigins: ["*"], askLimit: 2, askWindowMs: 60_000, readLimit: 100, trustProxy: false };
let server;
let base;
const gemini = scriptedGemini();

before(async () => {
  const turath = fixtureTurath();
  const pipeline = createPipeline({ gemini, turath, catalog });
  const app = createApp({ config, pipeline, turath, catalog, gemini, logger: { error() {} } });
  server = await app.listen(0, "127.0.0.1");
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

test("health reports catalog and model", async () => {
  const res = await fetch(`${base}/api/health`, { headers: { origin: "https://example.org" } });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("access-control-allow-origin"), "*");
  const body = await res.json();
  assert.equal(body.ok, true);
  assert.equal(body.model, "test-model");
  assert.ok(body.catalog.bookCount > 1000);
});

test("book, author and page endpoints return normalized Turath data without raw payloads", async () => {
  const book = await (await fetch(`${base}/api/books/147927`)).json();
  assert.equal(book.title, "الأربعون النووية مع زيادات ابن رجب");
  assert.ok(book.toc.length > 10);
  assert.equal(book.raw, undefined);
  assert.equal(book.pageMap[4], "1,5", "page map for the reader");
  assert.deepEqual(book.volumeBounds["1"], [1, 67]);
  const author = await (await fetch(`${base}/api/authors/44`)).json();
  assert.equal(author.name, "النووي");
  const page = await (await fetch(`${base}/api/pages/147927/5`)).json();
  assert.equal(page.url, "https://app.turath.io/book/147927?page=5");
  assert.match(normalizeArabic(page.text), /انما الاعمال بالنيات/);
  const missing = await fetch(`${base}/api/books/999999999`);
  assert.equal(missing.status, 404);
});

test("search and catalog endpoints", async () => {
  const search = await (await fetch(`${base}/api/search?q=${encodeURIComponent("الإسلام")}&bookId=147927`)).json();
  assert.equal(search.totalMatches, 14);
  assert.ok(search.items[0].citation.includes("تراث 147927"));
  const books = await (await fetch(`${base}/api/catalog/books?q=${encodeURIComponent("الأربعون النووية")}&limit=5`)).json();
  assert.ok(books.some((b) => b.id === "12836" && b.author.name === "النووي"));
  const authors = await (await fetch(`${base}/api/catalog/authors?q=${encodeURIComponent("النووي")}`)).json();
  assert.ok(authors.some((a) => a.id === "44"));
  const cats = await (await fetch(`${base}/api/catalog/categories`)).json();
  assert.equal(cats.length, 40);
  const bad = await fetch(`${base}/api/search`);
  assert.equal(bad.status, 400);
});

test("ask streams stages then a verified result", async () => {
  gemini.prompts.length = 0;
  const queue = [
    { standaloneQuestion: "q", detectedLanguage: "ar", questionType: "hadith", isIslamicStudies: true, queries: ["النيات"], madhhabs: [], requestedBooks: [], referenceBooks: [] },
    (request) => ({ selected: [/\[(C\d+)\] Book: [^\n]*Page: 5\b/.exec(request.prompt)[1]], coverage: "full", followUpQueries: [], followUpBooks: [] }),
    (request) => {
      const key = /\[(S\d+)\] Book: [^\n]*Page: 5\b/.exec(request.prompt)[1];
      return { status: "answered", answer: `نص [${key}]`, citations: [{ id: "Q1", sourceId: key, quote: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى" }] };
    },
  ];
  gemini.generateJson = async (request) => {
    const next = queue.shift();
    return { data: typeof next === "function" ? next(request) : next, model: "test-model" };
  };
  const res = await fetch(`${base}/api/ask`, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "text/event-stream" },
    body: JSON.stringify({ question: "ما حديث النية؟", language: "ar" }),
  });
  assert.equal(res.headers.get("content-type"), "text/event-stream; charset=utf-8");
  const text = await res.text();
  const events = [...text.matchAll(/event: (\w+)\ndata: (.*)\n/g)].map((m) => [m[1], JSON.parse(m[2])]);
  assert.deepEqual(events.filter(([e]) => e === "stage").map(([, d]) => d.stage), ["planning", "searching", "reading", "composing", "verifying"]);
  const [, result] = events.find(([e]) => e === "result");
  assert.equal(result.status, "answered");
  assert.equal(result.answer, "نص [1]");
  assert.equal(result.sources[0].quotes[0].exact, true);
});

test("a retried requestId rejoins the same answer without asking Gemini again", async () => {
  let calls = 0;
  const queue = [
    { standaloneQuestion: "q", detectedLanguage: "ar", questionType: "hadith", isIslamicStudies: true, queries: ["النيات"], madhhabs: [], requestedBooks: [], referenceBooks: [] },
    (request) => ({ selected: [/\[(C\d+)\] Book: [^\n]*Page: 5\b/.exec(request.prompt)[1]], coverage: "full", followUpQueries: [], followUpBooks: [] }),
    (request) => {
      const key = /\[(S\d+)\] Book: [^\n]*Page: 5\b/.exec(request.prompt)[1];
      return { status: "answered", answer: `نص [${key}]`, citations: [{ id: "Q1", sourceId: key, quote: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى" }] };
    },
  ];
  gemini.generateJson = async (request) => {
    calls += 1;
    const next = queue.shift();
    return { data: typeof next === "function" ? next(request) : next, model: "test-model" };
  };
  const ask = () =>
    fetch(`${base}/api/ask`, {
      method: "POST",
      headers: { "content-type": "application/json", accept: "text/event-stream" },
      body: JSON.stringify({ question: "ما حديث النية؟", language: "ar", requestId: "resume-test-0001" }),
    }).then((r) => r.text());
  const first = await ask();
  const again = await ask();
  assert.equal(calls, 3, "the pipeline ran once");
  for (const text of [first, again]) {
    const result = [...text.matchAll(/event: result\ndata: (.*)\n/g)].map((m) => JSON.parse(m[1]))[0];
    assert.equal(result.status, "answered");
  }
  assert.match(again, /event: stage/, "a rejoining client also gets the recorded stages");
});

test("ask is rate limited per client", async () => {
  const ask = () => fetch(`${base}/api/ask`, { method: "POST", body: "{}" });
  const statuses = [];
  for (let i = 0; i < 3; i += 1) statuses.push((await ask()).status);
  assert.equal(statuses.at(-1), 429);
});

test("rate limiter window resets", () => {
  let t = 0;
  const limit = createRateLimiter({ limit: 1, windowMs: 1000, now: () => t });
  assert.equal(limit("a").ok, true);
  assert.equal(limit("a").ok, false);
  t = 1000;
  assert.equal(limit("a").ok, true);
});

test("layers: the model names the matn delimiters of sample pages", async () => {
  const calls = [];
  const gemini = {
    resolveModel: async () => "m",
    generateJson: async (r) => {
      calls.push(r);
      return { data: { isCommentary: true, matnMarkers: ["()"], quranMarkers: ["﴿﴾"], confidence: 0.9, note: "x" }, model: "m", usage: { input: 10, output: 5, thoughts: 0 } };
    },
  };
  const app = createApp({ config: { allowedOrigins: ["*"], askLimit: 10, askWindowMs: 60_000, readLimit: 100, trustProxy: false }, pipeline: {}, turath: fixtureTurath(), catalog, gemini, logger: { info() {}, error() {} } });
  const server = await app.listen(0, "127.0.0.1");
  try {
    const url = `http://127.0.0.1:${server.address().port}/api/layers`;
    const res = await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ title: "مرقاة المفاتيح", pages: ["(قال) أي ...", "x".repeat(5000)] }) });
    const body = await res.json();
    assert.equal(res.status, 200);
    assert.deepEqual(body.matnMarkers, ["()"]);
    assert.equal(calls[0].tier, "fast");
    assert.ok(calls[0].prompt.includes("مرقاة المفاتيح"));
    assert.ok(calls[0].prompt.length < 4500, "pages are trimmed");
    const bad = await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ pages: [] }) });
    assert.equal(bad.status, 400);
  } finally {
    server.close();
  }
});

test("narrators and page ranges", async () => {
  const fakeNarrators = {
    search: async (q, page) => ({ count: 1, page, data: [{ id: 4210, name: "عبيد الله بن موسى", rank: "ثقة", death: 212, q }] }),
    get: async (id) => ({ id: Number(id), name: "عبيد الله بن موسى", summary: [["الكنية", "أبو محمد"]] }),
  };
  const app = createApp({ config, pipeline: {}, turath: fixtureTurath(), catalog, gemini, narrators: fakeNarrators, logger: { info() {}, error() {} } });
  const server = await app.listen(0, "127.0.0.1");
  try {
    const base = `http://127.0.0.1:${server.address().port}`;
    const list = await (await fetch(`${base}/api/narrators?q=${encodeURIComponent("عبيد")}&page=2`)).json();
    assert.equal(list.data[0].q, "عبيد");
    assert.equal(list.page, 2);
    const one = await (await fetch(`${base}/api/narrators/4210`)).json();
    assert.equal(one.summary[0][1], "أبو محمد");
    const range = await (await fetch(`${base}/api/pages/147927/4-7`)).json();
    assert.deepEqual(range.items.map((p) => p.location.internalPage), [4, 5, 6, 7]);
  } finally {
    server.close();
  }
});
