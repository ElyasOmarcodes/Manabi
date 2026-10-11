import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { createApp, createRateLimiter } from "../src/app.mjs";
import { catalog } from "../src/catalog.mjs";
import { createPipeline } from "../src/pipeline.mjs";
import { normalizeArabic } from "../src/verify.mjs";
import { fixtureFetch, fixtureTurath, scriptedGemini } from "./helpers.mjs";

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

test("layers: the model marks the matn stretches of sample pages", async () => {
  const calls = [];
  const gemini = {
    resolveModel: async () => "m",
    generateJson: async (r) => {
      calls.push(r);
      return { data: { isCommentary: true, pages: [{ matn: [{ start: "قال", end: "قال" }] }, { matn: [] }], quranMarkers: ["﴿﴾"], note: "x" }, model: "m", usage: { input: 10, output: 5, thoughts: 0 } };
    },
  };
  const app = createApp({ config: { allowedOrigins: ["*"], askLimit: 10, askWindowMs: 60_000, readLimit: 100, trustProxy: false }, pipeline: {}, turath: fixtureTurath(), catalog, gemini, logger: { info() {}, error() {} } });
  const server = await app.listen(0, "127.0.0.1");
  try {
    const url = `http://127.0.0.1:${server.address().port}/api/layers`;
    const res = await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ title: "مرقاة المفاتيح", pages: ["(قال) أي ...", "x".repeat(9000)] }) });
    const body = await res.json();
    assert.equal(res.status, 200);
    assert.deepEqual(body.pages[0].matn, [{ start: "قال", end: "قال" }]);
    assert.equal(calls[0].tier, "fast");
    assert.ok(calls[0].prompt.includes("مرقاة المفاتيح"));
    assert.ok(calls[0].prompt.length < 6000, "pages are trimmed");
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

test("books outside the catalog snapshot are collected from Turath responses", async () => {
  const { createDiscovered } = await import("../src/discovered.mjs");
  const discovered = createDiscovered({ catalog });
  const client = discovered.watch({
    search: async () => ({ items: [{ book: { id: "999999", title: "كتاب جديد" }, author: { id: "77", name: "مؤلف" }, category: { id: "3" } }, { book: { id: "8176", title: "مرقاة المفاتيح" } }] }),
    getBook: async () => ({ id: "999998", title: "كتاب آخر", author: { id: "78" }, category: { id: "4" } }),
  });
  await client.search("x");
  await client.getBook("999998");
  const { count, books } = discovered.list();
  assert.equal(count, 2, "books already in the snapshot are skipped");
  assert.deepEqual(books[0], ["999999", "كتاب جديد", "77", "3", "مؤلف"]);
  const app = createApp({ config, pipeline: {}, turath: fixtureTurath(), catalog, gemini, discovered, logger: { info() {}, error() {} } });
  const server = await app.listen(0, "127.0.0.1");
  try {
    const body = await (await fetch(`http://127.0.0.1:${server.address().port}/api/catalog/discovered`)).json();
    assert.equal(body.count, 2);
  } finally {
    server.close();
  }
});

test("search options of Turath's search screen reach the Turath API", async () => {
  const { createAdvancedSearch } = await import("../src/search.mjs");
  const seen = [];
  const fetchFn = async (input) => {
    const u = new URL(String(input));
    seen.push(Object.fromEntries(u.searchParams));
    return fixtureFetch()(input);
  };
  const app = createApp({ config, pipeline: {}, turath: fixtureTurath(), catalog, gemini, advancedSearch: createAdvancedSearch({ fetch: fetchFn }), logger: { info() {}, error() {} } });
  const server = await app.listen(0, "127.0.0.1");
  try {
    const base = `http://127.0.0.1:${server.address().port}/api/search?q=${encodeURIComponent("الإسلام")}`;
    const body = await (await fetch(`${base}&precision=3&stem=0&notes=0&toc=1&bookId=147927`)).json();
    assert.ok(body.items.length > 0);
    assert.equal(body.items[0].book.id, "147927");
    assert.equal(body.items[0].raw, undefined);
    assert.deepEqual(
      { precision: seen[0].precision, stem: seen[0].stem, non_author: seen[0].non_author, scope: seen[0].scope, book: seen[0].book },
      { precision: "3", stem: "0", non_author: "0", scope: "toc", book: "147927" },
    );
    // Default options keep using the Nusus client (with its query fallbacks).
    await fetch(`${base}&precision=2`);
    assert.equal(seen.length, 1);
  } finally {
    server.close();
  }
});

test("PDF flags for book lists are looked up once per book", async () => {
  const { createPdfFlags } = await import("../src/pdf-flags.mjs");
  const asked = [];
  const pdfFlags = createPdfFlags({
    fetch: async (url) => {
      const id = new URL(String(url)).searchParams.get("id");
      asked.push(id);
      return new Response(JSON.stringify({ meta: { pdf_links: id === "1681" ? { root: "/x/", files: ["01_1.pdf"] } : undefined } }), { status: 200 });
    },
  });
  const app = createApp({ config, pipeline: {}, turath: fixtureTurath(), catalog, gemini, pdfFlags, logger: { info() {}, error() {} } });
  const server = await app.listen(0, "127.0.0.1");
  try {
    const url = `http://127.0.0.1:${server.address().port}/api/books/pdf?ids=1681,8176,abc`;
    assert.deepEqual((await (await fetch(url)).json()).pdf, { 1681: true, 8176: false });
    await fetch(url);
    assert.deepEqual(asked.sort(), ["1681", "8176"]);
  } finally {
    server.close();
  }
});
