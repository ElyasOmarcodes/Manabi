// Live end-to-end test against the real Turath API and Gemini.
// Runs only when MANABI_LIVE=1 and GEMINI_API_KEY is set (CI uses the repository secret).
import assert from "node:assert/strict";
import { test } from "node:test";
import { createTurathClient } from "nusus/turath";
import { catalog } from "../src/catalog.mjs";
import { createGemini } from "../src/gemini.mjs";
import { createPipeline } from "../src/pipeline.mjs";
import { locateQuote } from "../src/verify.mjs";

const key = process.env.GEMINI_API_KYA || process.env.GEMINI_API_KEY;
const live = process.env.MANABI_LIVE === "1" && Boolean(key);

const pipeline = live
  ? createPipeline({ gemini: createGemini({ apiKey: key, model: process.env.GEMINI_MODEL }), turath: createTurathClient({ timeout: 20_000 }), catalog })
  : undefined;
const turath = createTurathClient({ timeout: 20_000 });

// Free-tier keys run out of daily quota; that is an account limit, not a defect.
const liveTest = (name, timeout, body) =>
  test(name, { skip: !live, timeout }, async (t) => {
    try {
      await body();
    } catch (error) {
      if (error?.code === "QUOTA") return t.skip(`Gemini quota exhausted: ${error.message.slice(0, 120)}`);
      throw error;
    }
  });

const check = async (result) => {
  console.log(JSON.stringify({ status: result.status, model: result.model, queries: result.queries, sources: result.sources.map((s) => s.citation) }));
  for (const source of result.sources) {
    assert.match(source.url, /^https:\/\/app\.turath\.io\/book\/\d+/);
    assert.ok(source.bookTitle);
    // Re-fetch the page from Turath and confirm every quote really is on it.
    const page = await turath.getPage(source.bookId, source.internalPage);
    for (const quote of source.quotes) assert.ok(locateQuote(page.text, quote.text), `quote not on page: ${quote.text}`);
  }
};

liveTest("live: Pashto hadith question gets a verified, cited answer", 180_000, async () => {
  const result = await pipeline.ask({ question: "د «إنما الأعمال بالنيات» حدیث چا روایت کړی دی؟", language: "ps" });
  assert.equal(result.language, "ps");
  assert.notEqual(result.status, "insufficient");
  assert.ok(result.sources.length >= 1);
  assert.ok(result.sources.some((s) => s.quotes.length >= 1), "at least one source carries a verified quote");
  await check(result);
});

liveTest("live: fiqh question in English keeps opinions attributed", 180_000, async () => {
  const result = await pipeline.ask({ question: "Does touching the private part break wudu?", language: "en" });
  await check(result);
  for (const opinion of result.opinions) assert.ok(opinion.sources.length >= 1);
});

liveTest("live: nonsense question is reported as not documented", 180_000, async () => {
  const result = await pipeline.ask({ question: "What is the Wi-Fi password of the moon base in 2090?", language: "en" });
  assert.equal(result.status, "insufficient");
});

liveTest("live: Hanafi ruling with several sources, then a follow-up naming two books", 300_000, async () => {
  const q1 = "د حنفي مذهب علماء څه فرمايي چې کله د ميږې څخه بچی پيدا شي، او سر يې د سپي وي ايا ددی خوراک جايز دی کنه؟ پر پښتو ژبه ځواب راکړه او د اصل مرجع متن په عربي ذکر کړه";
  const first = await pipeline.ask({ question: q1, language: "ps" });
  await check(first);
  assert.notEqual(first.status, "insufficient");
  assert.ok(first.sources.length >= 3, `expected several Hanafi sources, got ${first.sources.length}`);
  assert.ok(first.answer.split("\n").filter((l) => l.startsWith("> ")).length >= 2, "original Arabic texts are quoted inline");

  const history = [{ question: q1, summary: first.summary, books: first.sources.map((s) => s.bookTitle) }];
  const second = await pipeline.ask({ question: "نوري حوالې وګوره لکه الفقه الاسلامي للزحيلي، الموسوعة الفقهية", language: "ps", history });
  await check(second);
  const books = second.sources.map((s) => s.bookId);
  assert.ok(books.includes("384") || books.includes("38056"), `requested books should be consulted, got ${second.sources.map((s) => s.bookTitle).join(" | ")}`);
});
