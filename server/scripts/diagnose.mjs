// Live diagnosis with the real key (run by .github/workflows/diagnose.yml):
//   1. which Gemini models the key can use,
//   2. latency of a small JSON call per candidate model,
//   3. the full pipeline for one question, timing every Gemini call.
// Prints no secrets.
import { createTurathClient } from "nusus/turath";
import { catalog } from "../src/catalog.mjs";
import { createGemini, rankModels } from "../src/gemini.mjs";
import { createPipeline } from "../src/pipeline.mjs";

const key = process.env.GEMINI_API_KEY || process.env.GEMINI_API_KYA;
if (!key) {
  console.log("No Gemini key available; nothing to diagnose.");
  process.exit(0);
}
const API = "https://generativelanguage.googleapis.com/v1beta";
const question = process.env.DIAG_QUESTION || "د حنفي فقهې او فتاوی له نظره میت یعني مړي ته د غسل پر وخت د اوبو په وسیله استنجاء څه حکم لري، او د لوټې(مَدَر) پر وسیله څه حکم لري؟";
const scope = { categoryId: process.env.DIAG_CATEGORY || "14" };
const depth = process.env.DIAG_DEPTH || "quick";

const t0 = Date.now();
const listed = await (await fetch(`${API}/models?pageSize=1000`, { headers: { "x-goog-api-key": key } })).json();
const models = listed.models ?? [];
console.log("models main:", rankModels(models, "main").join(", "));
console.log("models fast:", rankModels(models, "fast").join(", "));

const probe = async (name, extra = {}) => {
  const started = Date.now();
  const body = {
    contents: [{ role: "user", parts: [{ text: 'Reply with {"ok": true}' }] }],
    generationConfig: { responseMimeType: "application/json", responseSchema: { type: "OBJECT", properties: { ok: { type: "BOOLEAN" } } }, ...extra },
  };
  const res = await fetch(`${API}/models/${name}:generateContent`, { method: "POST", headers: { "content-type": "application/json", "x-goog-api-key": key }, body: JSON.stringify(body) });
  const text = await res.text();
  let message = "";
  try {
    message = JSON.parse(text).error?.message ?? "";
  } catch {}
  return `${res.status} ${Date.now() - started}ms ${message.slice(0, 140)}`;
};
for (const name of [...new Set([...rankModels(models, "main").slice(0, 3), ...rankModels(models, "fast").slice(0, 2)])]) {
  console.log(`probe ${name}: plain ${await probe(name)} | thinkingBudget=0 ${await probe(name, { thinkingConfig: { thinkingBudget: 0 } })}`);
}

const gemini = createGemini({ apiKey: key });
const timed = {
  resolveModel: gemini.resolveModel,
  generateJson: async (request) => {
    const started = Date.now();
    try {
      const out = await gemini.generateJson(request);
      console.log(`gemini ok tier=${request.tier ?? "main"} model=${out.model} ${Date.now() - started}ms promptChars=${request.prompt.length}`);
      return out;
    } catch (error) {
      console.log(`gemini FAIL tier=${request.tier ?? "main"} ${error.code} ${Date.now() - started}ms ${String(error.message).slice(0, 200)}`);
      throw error;
    }
  },
};
const pipeline = createPipeline({ gemini: timed, turath: createTurathClient({ timeout: 20_000 }), catalog });
try {
  const result = await pipeline.ask({ question, language: "ps", scope, depth }, (event, data) => {
    if (event === "stage") console.log(`stage ${data.stage} +${Date.now() - t0}ms`);
  });
  console.log(JSON.stringify({ status: result.status, model: result.model, elapsedMs: result.elapsedMs, sources: result.sources.map((s) => s.citation) }, null, 1));
  console.log("answer:", result.answer.slice(0, 1500));
} catch (error) {
  console.log("pipeline error:", error.code, error.message);
}
