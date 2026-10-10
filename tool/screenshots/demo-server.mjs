// Offline demo server for UI screenshots: the real Manabi app server and
// pipeline over recorded Turath responses, with a scripted model whose answer
// cites real pages (quotes are still verified against the recorded text).
//   node tool/screenshots/demo-server.mjs [port]
import { createApp } from "../../server/src/app.mjs";
import { catalog } from "../../server/src/catalog.mjs";
import { createPipeline } from "../../server/src/pipeline.mjs";
import { fixtureTurath } from "../../server/test/helpers.mjs";

const port = Number(process.argv[2] ?? 8787);
const turath = fixtureTurath();

const keys = (prompt, prefix) => [...prompt.matchAll(new RegExp(`\\[(${prefix}\\d+)\\] Book: [^\\n]*Page: (\\d+)`, "g"))].map((m) => ({ key: m[1], page: Number(m[2]) }));

const gemini = {
  resolveModel: async () => "demo-model",
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

const pipeline = createPipeline({ gemini, turath, catalog });
const app = createApp({ config: { allowedOrigins: ["*"], askLimit: 1000, askWindowMs: 60_000, readLimit: 10_000, trustProxy: false }, pipeline, turath, catalog, gemini, logger: console });
await app.listen(port, "127.0.0.1");
console.log(`demo server on http://127.0.0.1:${port}`);
