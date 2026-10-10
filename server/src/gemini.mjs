// Minimal Gemini REST client (generateContent with JSON schema output).
// The API key is only ever sent in the x-goog-api-key header, never logged.
//
// Two tiers: "fast" (Flash-Lite, for planning and ranking) and "main"
// (Flash, for writing the answer). Each model has its own quota, so when a
// model reports an exhausted quota the client moves on to the next one.

const API = "https://generativelanguage.googleapis.com/v1beta";
// Only used when the model list cannot be read.
const FALLBACK = { main: ["gemini-flash-latest", "gemini-flash-lite-latest"], fast: ["gemini-flash-lite-latest", "gemini-flash-latest"] };

/** Per-call time limits and the overall budget of one generation, per tier. */
const TIER_LIMITS = { fast: { callMs: 45_000, totalMs: 100_000 }, main: { callMs: 70_000, totalMs: 200_000 } };

/** How long a model is skipped after it fails in a way another model can avoid. */
const COOLDOWN_MS = { QUOTA: 60 * 60_000, MODEL_NOT_FOUND: 24 * 60 * 60_000, OVERLOADED: 3 * 60_000, TIMEOUT: 5 * 60_000 };

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

export const createGemini = ({ apiKey, model, fetch: fetcher = fetch, timeoutMs = 90_000, now = () => Date.now(), tierLimits = TIER_LIMITS } = {}) => {
  if (!apiKey) throw new GeminiError("NO_API_KEY", "Gemini API key is not configured");
  let available; // models listed by the API
  const benched = new Map(); // model → { until, error }: skipped until then

  const call = async (url, init = {}, limitMs = timeoutMs) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), limitMs);
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

  /** Candidate models for a tier, best first, without benched ones. */
  const candidates = async (tier) => {
    if (model) return [model];
    const listed = await listModels();
    const unique = [...new Set([...rankModels(listed, tier), ...(listed.length ? [] : FALLBACK[tier])])];
    return unique.filter((m) => (benched.get(m)?.until ?? 0) <= now());
  };

  const resolveModel = async (tier = "main") => (await candidates(tier))[0] ?? FALLBACK[tier][0];

  /** Why a model should be skipped in favour of the next one (or undefined). */
  const benchReason = (error) => {
    if (error.code === "MODEL_NOT_FOUND") return "MODEL_NOT_FOUND";
    if (error.code === "QUOTA" && !error.retryable) return "QUOTA";
    if (error.code === "TIMEOUT") return "TIMEOUT";
    if (error.code === "HTTP" && error.status >= 500) return "OVERLOADED";
    return undefined;
  };

  /**
   * Runs one JSON-schema constrained generation and returns the parsed object.
   * A model that is slow, overloaded, out of quota or retired is skipped for a
   * while and the next model is tried at once; switching models does not use
   * up the retry budget, and the whole call has a time limit.
   */
  const generateJson = async ({ system, prompt, schema, temperature = 0.2, tier = "main" }) => {
    const limits = tierLimits[tier] ?? tierLimits.main;
    const deadline = now() + limits.totalMs;
    const body = {
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { temperature, responseMimeType: "application/json", responseSchema: schema },
    };
    let lastError;
    let retries = 0;
    const tried = new Set();
    for (;;) {
      const name = (await candidates(tier)).find((m) => !tried.has(m));
      if (!name) {
        // Nothing left: report the most telling reason (quota beats the rest).
        const stored = [...benched.values()].map((b) => b.error);
        throw stored.find((e) => e.code === "QUOTA") ?? lastError ?? stored[0] ?? new GeminiError("UNAVAILABLE", "No Gemini model is available right now");
      }
      try {
        const remaining = Math.max(5_000, deadline - now());
        const result = await call(`${API}/models/${encodeURIComponent(name)}:generateContent`, { method: "POST", body: JSON.stringify(body) }, Math.min(limits.callMs, remaining));
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
      } catch (raw) {
        const error = raw instanceof GeminiError ? new GeminiError(raw.code, `${raw.message} [${name}]`, { status: raw.status, retryable: raw.retryable }) : raw;
        lastError = error;
        const reason = model ? undefined : benchReason(raw);
        if (reason) {
          benched.set(name, { until: now() + COOLDOWN_MS[reason], error });
          tried.add(name);
        } else if (!raw.retryable) {
          throw error; // bad key, blocked prompt, invalid request: another model will not help
        } else if (retries < 2) {
          retries += 1;
          await sleep(800 * 2 ** retries);
        } else if (model || raw.code === "NETWORK") {
          throw error; // a pinned model, or no connection at all
        } else {
          // Same model kept failing (e.g. malformed output): try the next one.
          tried.add(name);
          retries = 0;
        }
        if (now() >= deadline) throw error;
      }
    }
  };

  return { generateJson, resolveModel };
};
