// HTTP API for the Manabi app. No framework: node:http, JSON and SSE.
import { createServer } from "node:http";
import { NususError } from "nusus";

const VERSION = "1.0.0";
const MAX_BODY = 32 * 1024;

const json = (res, status, body, headers = {}) => {
  const payload = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...headers });
  res.end(payload);
};

export const errorInfo = (error) => {
  if (error instanceof NususError) {
    if (error.code === "NOT_FOUND") return { status: 404, code: "NOT_FOUND", message: error.message };
    if (error.code === "INVALID_ARGUMENT") return { status: 400, code: "INVALID_ARGUMENT", message: error.message };
    if (error.code === "RATE_LIMITED") return { status: 503, code: "TURATH_RATE_LIMITED", message: "Turath is rate limiting requests, try again shortly" };
    return { status: 502, code: "TURATH_UNAVAILABLE", message: "The Turath library could not be reached" };
  }
  if (error?.name === "GeminiError") {
    if (error.code === "AUTH" || error.code === "NO_API_KEY") return { status: 502, code: "GEMINI_AUTH", message: "The server's Gemini key is missing or invalid" };
    if (error.code === "QUOTA") return { status: 503, code: "GEMINI_QUOTA", message: "Gemini quota exceeded, try again later" };
    return { status: 502, code: "GEMINI_UNAVAILABLE", message: error.message };
  }
  if (error?.code === "INVALID_ARGUMENT") return { status: 400, code: "INVALID_ARGUMENT", message: error.message };
  if (error?.code === "TURATH_UNAVAILABLE") return { status: 502, code: "TURATH_UNAVAILABLE", message: error.message };
  return { status: 500, code: "INTERNAL", message: "Internal server error" };
};

const readJson = (req) =>
  new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY) {
        reject(Object.assign(new Error("request body too large"), { code: "INVALID_ARGUMENT" }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      try {
        resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString("utf8")) : {});
      } catch {
        reject(Object.assign(new Error("invalid JSON body"), { code: "INVALID_ARGUMENT" }));
      }
    });
    req.on("error", reject);
  });

/** Fixed-window rate limiter keyed by client address. */
export const createRateLimiter = ({ limit, windowMs, now = () => Date.now() }) => {
  const hits = new Map();
  return (key) => {
    const t = now();
    const entry = hits.get(key);
    if (!entry || t - entry.start >= windowMs) {
      hits.set(key, { start: t, count: 1 });
      if (hits.size > 10_000) for (const [k, v] of hits) if (t - v.start >= windowMs) hits.delete(k);
      return { ok: true };
    }
    entry.count += 1;
    return entry.count <= limit ? { ok: true } : { ok: false, retryAfter: Math.ceil((entry.start + windowMs - t) / 1000) };
  };
};

const stripRaw = (value) => {
  if (Array.isArray(value)) return value.map(stripRaw);
  if (value && typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) if (k !== "raw") out[k] = stripRaw(v);
    return out;
  }
  return value;
};

const positive = (value) => (value && /^[1-9]\d*$/.test(value) ? value : undefined);

export const createApp = ({ config, pipeline, turath, catalog, gemini, logger = console }) => {
  const askLimiter = createRateLimiter({ limit: config.askLimit, windowMs: config.askWindowMs });
  const readLimiter = createRateLimiter({ limit: config.readLimit, windowMs: 60_000 });

  const clientKey = (req) => {
    if (config.trustProxy) {
      const forwarded = req.headers["x-forwarded-for"];
      if (typeof forwarded === "string" && forwarded) return forwarded.split(",")[0].trim();
    }
    return req.socket.remoteAddress ?? "unknown";
  };

  const corsHeaders = (req) => {
    const origin = req.headers.origin;
    const allowed = config.allowedOrigins;
    const allow = allowed.includes("*") ? "*" : origin && allowed.includes(origin) ? origin : undefined;
    return allow
      ? {
          "access-control-allow-origin": allow,
          "access-control-allow-methods": "GET, POST, OPTIONS",
          "access-control-allow-headers": "content-type, authorization, accept",
          "access-control-max-age": "86400",
          vary: "origin",
        }
      : {};
  };

  const routes = [
    ["GET", /^\/api\/health$/, async () => ({
      ok: true,
      name: "manabi-server",
      version: VERSION,
      gemini: Boolean(gemini),
      model: gemini ? await gemini.resolveModel().catch(() => undefined) : undefined,
      catalog: catalog.metadata(),
    })],
    ["GET", /^\/api\/search$/, async (_m, url) => {
      const q = url.searchParams.get("q")?.trim();
      if (!q) throw Object.assign(new Error("q is required"), { code: "INVALID_ARGUMENT" });
      const option = (name) => positive(url.searchParams.get(name) ?? undefined);
      const result = await turath.search(q, {
        page: Number(option("page") ?? 1),
        bookIds: option("bookId") ? [option("bookId")] : undefined,
        authorIds: option("authorId") ? [option("authorId")] : undefined,
        categoryIds: option("categoryId") ? [option("categoryId")] : undefined,
      });
      return stripRaw(result);
    }],
    ["GET", /^\/api\/books\/([1-9]\d*)$/, async (m) => stripRaw(await turath.getBook(m[1]))],
    ["GET", /^\/api\/authors\/([1-9]\d*)$/, async (m) => stripRaw(await turath.getAuthor(m[1]))],
    ["GET", /^\/api\/pages\/([1-9]\d*)\/([1-9]\d*)$/, async (m) => stripRaw(await turath.getPage(m[1], m[2]))],
    ["GET", /^\/api\/catalog\/categories$/, async () => catalog.listCategories()],
    ["GET", /^\/api\/catalog\/books$/, async (_m, url) => {
      const q = url.searchParams.get("q") ?? "";
      const authorId = positive(url.searchParams.get("authorId") ?? undefined);
      const categoryId = positive(url.searchParams.get("categoryId") ?? undefined);
      const limit = Math.min(200, Number(positive(url.searchParams.get("limit") ?? undefined) ?? 50));
      return catalog.findBooks(q, { limit, authorIds: authorId ? [authorId] : undefined, categoryIds: categoryId ? [categoryId] : undefined });
    }],
    ["GET", /^\/api\/catalog\/authors$/, async (_m, url) => {
      const limit = Math.min(200, Number(positive(url.searchParams.get("limit") ?? undefined) ?? 50));
      return catalog.findAuthors(url.searchParams.get("q") ?? "", { limit });
    }],
  ];

  const handleAsk = async (req, res, cors) => {
    if (!gemini) return json(res, 503, { error: { code: "GEMINI_AUTH", message: "GEMINI_API_KYA is not configured on the server" } }, cors);
    const limited = askLimiter(clientKey(req));
    if (!limited.ok) {
      return json(res, 429, { error: { code: "RATE_LIMITED", message: "Too many questions, please wait" } }, { ...cors, "retry-after": String(limited.retryAfter) });
    }
    const body = await readJson(req);
    const stream = String(req.headers.accept ?? "").includes("text/event-stream");
    if (!stream) return json(res, 200, await pipeline.ask(body), cors);

    res.writeHead(200, { ...cors, "content-type": "text/event-stream; charset=utf-8", "cache-control": "no-store", connection: "keep-alive", "x-accel-buffering": "no" });
    const send = (event, data) => res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    const heartbeat = setInterval(() => res.write(": keep-alive\n\n"), 15_000);
    try {
      const result = await pipeline.ask(body, send);
      send("result", result);
    } catch (error) {
      const info = errorInfo(error);
      if (info.status >= 500) logger.error("ask failed", error?.code ?? error?.name, error?.message);
      send("error", { code: info.code, message: info.message });
    } finally {
      clearInterval(heartbeat);
      res.end();
    }
  };

  const handler = async (req, res) => {
    const cors = corsHeaders(req);
    const url = new URL(req.url ?? "/", "http://localhost");
    res.setHeader("x-content-type-options", "nosniff");
    res.setHeader("referrer-policy", "no-referrer");
    try {
      if (req.method === "OPTIONS") {
        res.writeHead(204, cors);
        return res.end();
      }
      if (config.accessToken && url.pathname.startsWith("/api/") && url.pathname !== "/api/health") {
        if (req.headers.authorization !== `Bearer ${config.accessToken}`) {
          return json(res, 401, { error: { code: "UNAUTHORIZED", message: "Missing or invalid access token" } }, cors);
        }
      }
      if (req.method === "POST" && url.pathname === "/api/ask") return await handleAsk(req, res, cors);
      for (const [method, pattern, fn] of routes) {
        const match = pattern.exec(url.pathname);
        if (!match) continue;
        if (req.method !== method) return json(res, 405, { error: { code: "METHOD_NOT_ALLOWED", message: "Method not allowed" } }, cors);
        const limited = readLimiter(clientKey(req));
        if (!limited.ok) return json(res, 429, { error: { code: "RATE_LIMITED", message: "Too many requests" } }, { ...cors, "retry-after": String(limited.retryAfter) });
        return json(res, 200, await fn(match, url), cors);
      }
      if (url.pathname === "/") return json(res, 200, { name: "manabi-server", docs: "/api/health" }, cors);
      return json(res, 404, { error: { code: "NOT_FOUND", message: "Not found" } }, cors);
    } catch (error) {
      const info = errorInfo(error);
      if (info.status >= 500) logger.error("request failed", url.pathname, error?.code ?? error?.name, error?.message);
      if (!res.headersSent) json(res, info.status, { error: { code: info.code, message: info.message } }, cors);
      else res.end();
    }
  };

  return { handler, listen: (port, host) => new Promise((resolve) => {
    const server = createServer(handler);
    server.listen(port, host, () => resolve(server));
  }) };
};
