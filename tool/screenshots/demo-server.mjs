// Offline demo server for UI screenshots: the real Manabi app server and
// pipeline over recorded Turath responses, with a scripted model whose answer
// cites real pages (quotes are still verified against the recorded text).
//   node tool/screenshots/demo-server.mjs [port]
import { createApp } from "../../server/src/app.mjs";
import { chatModels } from "../../server/src/gemini.mjs";
import { catalog } from "../../server/src/catalog.mjs";
import { createPipeline } from "../../server/src/pipeline.mjs";
import { fixtureTurath } from "../../server/test/helpers.mjs";

const port = Number(process.argv[2] ?? 8787);
const turath = fixtureTurath();

const keys = (prompt, prefix) => [...prompt.matchAll(new RegExp(`\\[(${prefix}\\d+)\\] Book: [^\\n]*Page: (\\d+)`, "g"))].map((m) => ({ key: m[1], page: Number(m[2]) }));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Like the real client: token usage on every reply, and the answer streamed
// in pieces when the pipeline asks for it (so the draft view can be seen).
const scripted = {
  generateJson: async ({ prompt, schema }) => {
    if (schema.properties?.queries) {
      return { model: "demo-model", data: { standaloneQuestion: "حديث النية", detectedLanguage: "ps", questionType: "hadith", isIslamicStudies: true, queries: ["النيات", "الإسلام"], madhhabs: [], requestedBooks: [], referenceBooks: [] } };
    }
    if (schema.properties?.selected) {
      const found = keys(prompt, "C");
      const first = found.find((c) => c.page === 5) ?? found[0];
      return { model: "demo-model", data: { selected: [first.key, ...found.filter((c) => c !== first).slice(0, 2).map((c) => c.key)], coverage: "full", followUpQueries: [], followUpBooks: [] } };
    }
    const found = keys(prompt, "S");
    const main = found.find((s) => s.page === 5) ?? found[0];
    const others = found.filter((s) => s !== main).slice(0, 2);
    return {
      model: "demo-model",
      data: {
        status: "answered",
        summary: "د نیت حدیث او راویان",
        answer: [
          "## د حدیث متن او راوي",
          `دا مشهور حدیث امیر المؤمنین ابو حفص عمر بن الخطاب رضي الله عنه روایت کړی دی، او امام نووي یې د خپلو څلوېښتو احادیثو په سر کې راوړی دی [${main.key}].`,
          "[[Q1]]",
          "## د حدیث اهمیت",
          `- علماوو دا حدیث د دین یو له اصلي بنسټونو څخه ګڼلی دی، ځکه چې د هر عمل قبولیت په نیت پورې تړلی دی [${main.key}].`,
          others[0] ? `- د کتاب په نورو برخو کې د اسلام د ارکانو بحث هم راغلی دی [${others[0].key}].` : "",
          others[1] ? `- همدا راز د ایمان او احسان مراتب هم بیان شوي دي [${others[1].key}].` : "",
        ].filter(Boolean).join("\n"),
        citations: [{ id: "Q1", sourceId: main.key, quote: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى", relevance: "د حدیث متن" }],
        opinions: [],
      },
    };
  },
};

// A typical model listing, for the model picker.
const listed = ["gemini-3-pro", "gemini-3-flash", "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemma-3-27b-it", "gemma-3-12b-it", "gemma-3n-e4b-it"].map((id) => ({
  name: `models/${id}`,
  displayName: id.replace(/-/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()),
  inputTokenLimit: id.startsWith("gemma") ? 131072 : 1048576,
}));

const gemini = {
  resolveModel: async () => "gemini-3-flash",
  models: async () => chatModels(listed),
  generateJson: async (request) => {
    // DEMO_DELAY: a slower model, to see the research progress.
    await sleep(Number(process.env.DEMO_DELAY ?? 900));
    const reply = await scripted.generateJson(request);
    if (request.onText) {
      const text = JSON.stringify(reply.data);
      for (let n = 40; n < text.length; n += 40) {
        request.onText(text.slice(0, n));
        await sleep(120);
      }
    }
    return { ...reply, usage: { input: Math.round(prompt(request).length / 3.6), output: Math.round(JSON.stringify(reply.data).length / 3.2), thoughts: request.onText ? 180 : 60 } };
  },
};
const prompt = (r) => `${r.system}${r.prompt}`;

const pipeline = createPipeline({ gemini, turath, catalog });
const app = createApp({ config: { allowedOrigins: ["*"], askLimit: 1000, askWindowMs: 60_000, readLimit: 10_000, trustProxy: false }, pipeline, turath, catalog, gemini, logger: console });
await app.listen(port, "127.0.0.1");
console.log(`demo server on http://127.0.0.1:${port}`);
