// Minimal Gemini REST client (generateContent with JSON schema output).
// The API key is only ever sent in the x-goog-api-key header, never logged.
//
// Two tiers: "fast" (Flash-Lite, for planning and ranking) and "main"
// (Flash, for writing the answer). Each model has its own quota, so when a
// model reports an exhausted quota the client moves on to the next one.

const API = "https://generativelanguage.googleapis.com/v1beta";
const FALLBACK = { main: ["gemini-2.5-flash", "gemini-2.5-flash-lite"], fast: ["gemini-2.5-flash-lite", "gemini-2.5-flash"] };

export class GeminiError extends Error {
  constructor(code, message, { status, retryable = false } = {}) {
    super(message);
    this.name = "GeminiError";
    this.code = code;
    this.status = status;
    this.retryable = retryable;
  }
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const parse = (name) => {
  const m = /^(?:models\/)?gemini-(\d+)(?:\.(\d+))?-(flash-lite|flash|pro)$/.exec(name);
  return m ? { major: Number(m[1]), minor: Number(m[2] ?? 0), kind: m[3] } : undefined;
};

/** Orders usable models for a tier, newest first, preferred kind first. */
export const rankModels = (models, tier = "main") => {
  const prefer = tier === "fast" ? ["flash-lite", "flash"] : ["flash", "flash-lite"];
  return models
    .filter((m) => (m.supportedGenerationMethods ?? ["generateContent"]).includes("generateContent"))
    .map((m) => ({ name: String(m.name ?? m).replace(/^models\//, ""), v: parse(String(m.name ?? m)) }))
    .filter((m) => m.v && prefer.includes(m.v.kind))
    .sort((a, b) => prefer.indexOf(a.v.kind) - prefer.indexOf(b.v.kind) || b.v.major - a.v.major || b.v.minor - a.v.minor)
    .map((m) => m.name);
};

/** Kept for compatibility: the best "main" model. */
export const pickModel = (models) => rankModels(models, "main")[0];

/** A 429 that names a daily/plan quota (as opposed to a short burst limit). */
const isExhausted = (message) => /quota|exceeded your current/i.test(message ?? "");

export const createGemini = ({ apiKey, model, fetch: fetcher = fetch, timeoutMs = 120_000, now = () => Date.now() } = {}) => {
  if (!apiKey) throw new GeminiError("NO_API_KEY", "Gemini API key is not configured");
  let available; // models listed by the API
  const exhausted = new Map(); // model → time it may be retried

  const call = async (url, init = {}) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetcher(url, {
        ...init,
        headers: { "content-type": "application/json", "x-goog-api-key": apiKey, ...init.headers },
        signal: controller.signal,
      });
      const text = await response.text();
      let body;
      try {
        body = text ? JSON.parse(text) : {};
      } catch {
        body = { raw: text.slice(0, 200) };
      }
      if (!response.ok) {
        const message = body?.error?.message ?? `Gemini HTTP ${response.status}`;
        if (response.status === 400 && /api key/i.test(message)) throw new GeminiError("AUTH", "Invalid Gemini API key", { status: 400 });
        if (response.status === 401 || response.status === 403) throw new GeminiError("AUTH", message, { status: response.status });
        if (response.status === 404) throw new GeminiError("MODEL_NOT_FOUND", message, { status: 404 });
        if (response.status === 429) throw new GeminiError("QUOTA", message, { status: 429, retryable: !isExhausted(message) });
        throw new GeminiError("HTTP", message, { status: response.status, retryable: response.status >= 500 });
      }
      return body;
    } catch (error) {
      if (error instanceof GeminiError) throw error;
      if (error?.name === "AbortError") throw new GeminiError("TIMEOUT", "Gemini request timed out", { retryable: true });
      throw new GeminiError("NETWORK", "Could not reach Gemini", { retryable: true });
    } finally {
      clearTimeout(timer);
    }
  };

  const listModels = async () => {
    if (available) return available;
    try {
      const body = await call(`${API}/models?pageSize=1000`, { method: "GET" });
      available = body.models ?? [];
    } catch (error) {
      if (error instanceof GeminiError && error.code === "AUTH") throw error;
      available = [];
    }
    return available;
  };

  /** Candidate models for a tier, skipping those whose quota is exhausted. */
  const candidates = async (tier) => {
    if (model) return [model];
    const listed = await listModels();
    const ranked = [...rankModels(listed, tier), ...FALLBACK[tier]];
    const unique = [...new Set(ranked)];
    const ready = unique.filter((m) => (exhausted.get(m) ?? 0) <= now());
    return ready.length ? ready : unique.slice(0, 1);
  };

  const resolveModel = async (tier = "main") => (await candidates(tier))[0];

  /** Runs one JSON-schema constrained generation and returns the parsed object. */
  const generateJson = async ({ system, prompt, schema, temperature = 0.2, tier = "main" }) => {
    const body = {
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { temperature, responseMimeType: "application/json", responseSchema: schema },
    };
    let lastError;
    const tried = new Set();
    for (let attempt = 0; attempt < 6; attempt += 1) {
      const name = (await candidates(tier)).find((m) => !tried.has(m) || attempt < 2) ?? (await resolveModel(tier));
      try {
        const result = await call(`${API}/models/${encodeURIComponent(name)}:generateContent`, { method: "POST", body: JSON.stringify(body) });
        const candidate = result.candidates?.[0];
        if (!candidate) {
          const reason = result.promptFeedback?.blockReason;
          throw new GeminiError("BLOCKED", reason ? `Gemini blocked the request: ${reason}` : "Gemini returned no answer");
        }
        const text = (candidate.content?.parts ?? []).filter((p) => typeof p.text === "string" && !p.thought).map((p) => p.text).join("");
        try {
          return { data: JSON.parse(text), model: name };
        } catch {
          throw new GeminiError("BAD_OUTPUT", "Gemini returned malformed JSON", { retryable: true });
        }
      } catch (error) {
        lastError = error;
        tried.add(name);
        if (model) {
          if (!error.retryable) throw error;
        } else if (error.code === "MODEL_NOT_FOUND" || (error.code === "QUOTA" && !error.retryable)) {
          // Daily quota for this model is used up (or the model is gone): try another model.
          exhausted.set(name, now() + 60 * 60 * 1000);
          const rest = (await candidates(tier)).filter((m) => !tried.has(m));
          if (!rest.length) throw error;
          continue;
        } else if (!error.retryable) {
          throw error;
        }
        await sleep(800 * 2 ** Math.min(attempt, 3));
      }
    }
    throw lastError;
  };

  return { generateJson, resolveModel };
};
