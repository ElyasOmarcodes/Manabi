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

const listed = (names) => names.map((n) => ({ name: `models/${n}`, supportedGenerationMethods: ["generateContent"] }));

test("quota, retired and overloaded models are skipped until a working one answers", async () => {
  // The situation seen live: every Flash model out of quota or overloaded, an
  // old one retired, Flash-Lite still fine. Switching must not run out of attempts.
  const models = listed(["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.6-flash", "gemini-3.5-flash", "gemini-2.5-flash", "gemini-3.5-flash-lite"]);
  const calls = [];
  const fetch = async (url) => {
    if (url.includes("/models?")) return json(200, { models });
    const name = decodeURIComponent(url.split("/models/")[1].split(":")[0]);
    calls.push(name);
    if (name === "gemini-3.6-flash") return json(503, { error: { message: "This model is currently experiencing high demand." } });
    if (name === "gemini-2.5-flash") return json(404, { error: { message: "This model models/gemini-2.5-flash is no longer available to new users." } });
    if (name.endsWith("-flash")) return json(429, { error: { message: "You exceeded your current quota" } });
    return answer({ ok: true });
  };
  const gemini = createGemini({ apiKey: "k", fetch });
  const out = await gemini.generateJson({ system: "s", prompt: "p", schema: {} });
  assert.equal(out.model, "gemini-3.5-flash-lite");
  assert.deepEqual(calls, ["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.6-flash", "gemini-3.5-flash", "gemini-2.5-flash", "gemini-3.5-flash-lite"]);
  calls.length = 0;
  await gemini.generateJson({ system: "s", prompt: "p", schema: {} });
  assert.deepEqual(calls, ["gemini-3.5-flash-lite"], "failed models stay benched");
});

test("a model that times out is skipped for the next one", async () => {
  const models = listed(["gemini-3.8-flash", "gemini-3.5-flash-lite"]);
  const fetch = async (url, init) => {
    if (url.includes("/models?")) return json(200, { models });
    if (url.includes("3.8-flash")) {
      return new Promise((_, reject) => init.signal.addEventListener("abort", () => reject(Object.assign(new Error("aborted"), { name: "AbortError" }))));
    }
    return answer({ ok: true });
  };
  const gemini = createGemini({ apiKey: "k", fetch, tierLimits: { main: { callMs: 50, totalMs: 5_000 }, fast: { callMs: 50, totalMs: 5_000 } } });
  const out = await gemini.generateJson({ system: "s", prompt: "p", schema: {} });
  assert.equal(out.model, "gemini-3.5-flash-lite");
});

test("when every model is out of quota the quota error is reported", async () => {
  const models = listed(["gemini-3.8-flash", "gemini-3.5-flash-lite"]);
  const fetch = async (url) => (url.includes("/models?") ? json(200, { models }) : json(429, { error: { message: "You exceeded your current quota" } }));
  const gemini = createGemini({ apiKey: "k", fetch });
  await assert.rejects(gemini.generateJson({ system: "s", prompt: "p", schema: {} }), (e) => e.code === "QUOTA");
  await assert.rejects(gemini.generateJson({ system: "s", prompt: "p", schema: {} }), (e) => e.code === "QUOTA", "fails fast once everything is benched");
});

test("a streamed generation reports the growing text and the token usage", async () => {
  const models = listed(["gemini-3.8-flash"]);
  const sse = (obj) => `data: ${JSON.stringify(obj)}\r\n\r\n`;
  const chunks = [
    sse({ candidates: [{ content: { parts: [{ text: "thinking…", thought: true }] } }] }),
    sse({ candidates: [{ content: { parts: [{ text: '{"answer":"ab' }] } }] }),
    sse({ candidates: [{ content: { parts: [{ text: 'c"}' }] } }], usageMetadata: { promptTokenCount: 50, candidatesTokenCount: 7, thoughtsTokenCount: 3 } }),
  ];
  let url;
  const fetch = async (u) => {
    if (u.includes("/models?")) return json(200, { models });
    url = u;
    const enc = new TextEncoder();
    return { ok: true, status: 200, body: (async function* () { for (const c of chunks) yield enc.encode(c); })() };
  };
  const seen = [];
  const out = await createGemini({ apiKey: "k", fetch }).generateJson({ system: "s", prompt: "p", schema: {}, onText: (t) => seen.push(t) });
  assert.match(url, /:streamGenerateContent\?alt=sse$/);
  assert.deepEqual(seen, ['{"answer":"ab', '{"answer":"abc"}']);
  assert.deepEqual(out.data, { answer: "abc" });
  assert.deepEqual(out.usage, { input: 50, output: 7, thoughts: 3 });
});

test("Flash thinks briefly, and a model that rejects the setting is asked again without it", async () => {
  const models = listed(["gemini-3.8-flash"]);
  const bodies = [];
  const fetch = async (url, init) => {
    if (url.includes("/models?")) return json(200, { models });
    const body = JSON.parse(init.body);
    bodies.push(body.generationConfig.thinkingConfig);
    if (body.generationConfig.thinkingConfig) return json(400, { error: { message: "thinking_level is not supported for this model" } });
    return answer({ ok: true });
  };
  const gemini = createGemini({ apiKey: "k", fetch });
  const out = await gemini.generateJson({ system: "s", prompt: "p", schema: {} });
  assert.deepEqual(out.data, { ok: true });
  assert.deepEqual(bodies, [{ thinkingLevel: "low" }, undefined]);
});
