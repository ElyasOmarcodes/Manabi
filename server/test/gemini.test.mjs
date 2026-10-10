import assert from "node:assert/strict";
import { test } from "node:test";
import { createGemini, rankModels } from "../src/gemini.mjs";

const models = [
  { name: "models/gemini-2.5-flash", supportedGenerationMethods: ["generateContent"] },
  { name: "models/gemini-3.0-flash", supportedGenerationMethods: ["generateContent"] },
  { name: "models/gemini-3.0-flash-lite", supportedGenerationMethods: ["generateContent"] },
  { name: "models/gemini-3.0-pro", supportedGenerationMethods: ["generateContent"] },
  { name: "models/text-embedding-004", supportedGenerationMethods: ["embedContent"] },
];

const json = (status, body) => ({ ok: status < 400, status, text: async () => JSON.stringify(body) });
const answer = (data) => json(200, { candidates: [{ content: { parts: [{ text: JSON.stringify(data) }] } }] });

test("models are ranked per tier", () => {
  assert.deepEqual(rankModels(models, "main"), ["gemini-3.0-flash", "gemini-2.5-flash", "gemini-3.0-flash-lite"]);
  assert.equal(rankModels(models, "fast")[0], "gemini-3.0-flash-lite");
});

test("an exhausted daily quota moves on to the next model", async () => {
  const calls = [];
  const fetch = async (url) => {
    if (url.includes("/models?")) return json(200, { models });
    const name = decodeURIComponent(url.split("/models/")[1].split(":")[0]);
    calls.push(name);
    if (name === "gemini-3.0-flash") return json(429, { error: { message: "You exceeded your current quota. Quota exceeded for metric: free_tier_requests, limit: 20" } });
    return answer({ ok: name });
  };
  const gemini = createGemini({ apiKey: "k", fetch });
  const first = await gemini.generateJson({ system: "s", prompt: "p", schema: {} });
  assert.equal(first.model, "gemini-2.5-flash");
  assert.deepEqual(calls, ["gemini-3.0-flash", "gemini-2.5-flash"]);
  await gemini.generateJson({ system: "s", prompt: "p", schema: {} });
  assert.equal(calls.at(-1), "gemini-2.5-flash", "the exhausted model is skipped afterwards");
  assert.equal(await gemini.resolveModel(), "gemini-2.5-flash");
});

test("authentication errors are not retried", async () => {
  let n = 0;
  const fetch = async (url) => (url.includes("/models?") ? json(200, { models }) : (n++, json(403, { error: { message: "denied" } })));
  const gemini = createGemini({ apiKey: "k", fetch });
  await assert.rejects(gemini.generateJson({ system: "s", prompt: "p", schema: {} }), (e) => e.code === "AUTH");
  assert.equal(n, 1);
});
