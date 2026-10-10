// Minimal Gemini REST client (generateContent with JSON schema output).
// The API key is only ever sent in the x-goog-api-key header, never logged.

const API = "https://generativelanguage.googleapis.com/v1beta";
const FALLBACK_MODEL = "gemini-2.5-flash";

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

const parseVersion = (name) => {
  const m = /^models\/gemini-(\d+)(?:\.(\d+))?-(flash|pro)$/.exec(name);
  if (!m) return undefined;
  return { major: Number(m[1]), minor: Number(m[2] ?? 0), tier: m[3] };
};

/** Picks the newest stable "gemini-X.Y-flash" (or pro) model that supports generateContent. */
export const pickModel = (models) => {
  const candidates = models
    .filter((m) => m.supportedGenerationMethods?.includes("generateContent"))
    .map((m) => ({ name: m.name, v: parseVersion(m.name) }))
    .filter((m) => m.v);
  const score = (m) => (m.v.tier === "flash" ? 1_000_000 : 0) + m.v.major * 1000 + m.v.minor;
  candidates.sort((a, b) => score(b) - score(a));
  return candidates[0]?.name.replace(/^models\//, "");
};

export const createGemini = ({ apiKey, model, fetch: fetcher = fetch, timeoutMs = 90_000 } = {}) => {
  if (!apiKey) throw new GeminiError("NO_API_KEY", "Gemini API key is not configured");
  let resolvedModel = model || undefined;

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
        if (response.status === 429) throw new GeminiError("QUOTA", message, { status: 429, retryable: true });
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

  const resolveModel = async () => {
    if (resolvedModel) return resolvedModel;
    try {
      const body = await call(`${API}/models?pageSize=1000`, { method: "GET" });
      resolvedModel = pickModel(body.models ?? []) ?? FALLBACK_MODEL;
    } catch (error) {
      if (error instanceof GeminiError && error.code === "AUTH") throw error;
      resolvedModel = FALLBACK_MODEL;
    }
    return resolvedModel;
  };

  /** Runs one JSON-schema constrained generation and returns the parsed object. */
  const generateJson = async ({ system, prompt, schema, temperature = 0.2 }) => {
    const body = {
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { temperature, responseMimeType: "application/json", responseSchema: schema },
    };
    let lastError;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const name = await resolveModel();
      try {
        const result = await call(`${API}/models/${encodeURIComponent(name)}:generateContent`, {
          method: "POST",
          body: JSON.stringify(body),
        });
        const candidate = result.candidates?.[0];
        if (!candidate) {
          const reason = result.promptFeedback?.blockReason;
          throw new GeminiError("BLOCKED", reason ? `Gemini blocked the request: ${reason}` : "Gemini returned no answer");
        }
        const text = (candidate.content?.parts ?? [])
          .filter((p) => typeof p.text === "string" && !p.thought)
          .map((p) => p.text)
          .join("");
        try {
          return { data: JSON.parse(text), model: name };
        } catch {
          throw new GeminiError("BAD_OUTPUT", "Gemini returned malformed JSON", { retryable: true });
        }
      } catch (error) {
        lastError = error;
        if (error.code === "MODEL_NOT_FOUND" && !model) {
          resolvedModel = resolvedModel === FALLBACK_MODEL ? undefined : FALLBACK_MODEL;
          continue;
        }
        if (!error.retryable) throw error;
        await sleep(800 * 2 ** attempt);
      }
    }
    throw lastError;
  };

  return { generateJson, resolveModel };
};
