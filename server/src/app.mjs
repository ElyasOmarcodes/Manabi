// HTTP API for the Manabi app. No framework: node:http, JSON and SSE.
import { createServer } from "node:http";
import { NususError } from "nusus";
import { LAYERS_SCHEMA, LAYERS_SYSTEM, layersPrompt } from "./prompts.mjs";
import { createNarrators } from "./narrators.mjs";
import { createPdfFlags } from "./pdf-flags.mjs";
import { scopeTargets } from "./pipeline.mjs";
import { createAdvancedSearch, hasAdvancedOptions } from "./search.mjs";
import { decodingTurath } from "./text.mjs";

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

/** Turath's scanned PDFs: files.turath.io/pdf/<root><file>, one or more per volume. */
const pdfLinks = (links) => {
  if (!links || typeof links !== "object" || !Array.isArray(links.files)) return undefined;
  const root = typeof links.root === "string" ? links.root : "";
  const files = links.files.filter((f) => typeof f === "string" && f.trim());
  return files.length ? { root, files } : undefined;
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

export const createApp = ({ config, pipeline, turath: client, catalog, gemini, narrators = createNarrators(), advancedSearch = createAdvancedSearch(), pdfFlags = createPdfFlags(), discovered, logger = console }) => {
  const turath = decodingTurath(client);
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
    // The text models the server's key can call, for the chat's model picker.
    ["GET", /^\/api\/models$/, async () => {
      if (!gemini?.models) return { models: [], auto: undefined };
      const [models, auto] = await Promise.all([gemini.models(), gemini.resolveModel().catch(() => undefined)]);
      return { models, auto };
    }],
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
      // Turath's own search options (precision, word forms, footnotes, contents).
      const precision = Number(url.searchParams.get("precision"));
      const advanced = {
        precision: [1, 2, 3].includes(precision) ? precision : undefined,
        stem: url.searchParams.get("stem") === "0" ? false : undefined,
        nonAuthor: url.searchParams.get("notes") === "0" ? false : undefined,
        toc: url.searchParams.get("toc") === "1" ? true : undefined,
      };
      const page = Number(option("page") ?? 1);
      // One search per scope target (Turath filters one id of each kind),
      // merged in turn; the totals add up.
      const targets = scopeTargets({
        ...(url.searchParams.has("bookIds") || url.searchParams.has("authorIds") || url.searchParams.has("categoryIds")
          ? { bookIds: url.searchParams.get("bookIds") ?? "", authorIds: url.searchParams.get("authorIds") ?? "", categoryIds: url.searchParams.get("categoryIds") ?? "" }
          : { bookId: option("bookId"), authorId: option("authorId"), categoryId: option("categoryId") }),
      });
      const one = async (t = {}) => {
        if (hasAdvancedOptions(advanced)) {
          const found = await advancedSearch(q, { page, bookId: t.bookIds?.[0], authorId: t.authorIds?.[0], categoryId: t.categoryIds?.[0], ...advanced });
          for (const item of found.items) discovered?.note({ id: item.book?.id, title: item.book?.title, authorId: item.author?.id, authorName: item.author?.name, categoryId: item.category?.id });
          return found;
        }
        return turath.search(q, { page, ...t });
      };
      if (targets.length <= 1) return stripRaw(await one(targets[0]));
      const results = await Promise.all(targets.map((t) => one(t).catch(() => ({ items: [], totalMatches: 0 }))));
      const items = [];
      const seen = new Set();
      for (let i = 0; results.some((r) => i < r.items.length); i += 1) {
        for (const r of results) {
          const item = r.items[i];
          const key = item && `${item.book?.id ?? item.bookId}:${item.location?.internalPage ?? item.internalPage}`;
          if (item && !seen.has(key)) {
            seen.add(key);
            items.push(item);
          }
        }
      }
      return stripRaw({ items, totalMatches: results.reduce((n, r) => n + (r.totalMatches ?? 0), 0), page });
    }],
    // Which of these books have a scanned PDF (at most 60 ids).
    ["GET", /^\/api\/books\/pdf$/, async (_m, url) => {
      const ids = [...new Set((url.searchParams.get("ids") ?? "").split(",").map((s) => s.trim()).filter((s) => /^[1-9]\d{0,7}$/.test(s)))].slice(0, 60);
      return { pdf: ids.length ? await pdfFlags.lookup(ids) : {} };
    }],
    ["GET", /^\/api\/books\/([1-9]\d*)$/, async (m) => {
      const book = await turath.getBook(m[1]);
      // The reader needs Turath's page map (internal page → "volume,printed page").
      const indexes = book.raw?.indexes ?? {};
      return {
        ...stripRaw(book),
        pageMap: Array.isArray(indexes.page_map) ? indexes.page_map : undefined,
        volumeBounds: indexes.volume_bounds && typeof indexes.volume_bounds === "object" ? indexes.volume_bounds : undefined,
        pdf: pdfLinks(book.raw?.meta?.pdf_links),
      };
    }],
    ["GET", /^\/api\/authors\/([1-9]\d*)$/, async (m) => stripRaw(await turath.getAuthor(m[1]))],
    ["GET", /^\/api\/pages\/([1-9]\d*)\/([1-9]\d*)$/, async (m) => stripRaw(await turath.getPage(m[1], m[2]))],
    // A short run of pages (for saving a book offline); missing pages are skipped.
    ["GET", /^\/api\/pages\/([1-9]\d*)\/([1-9]\d*)-([1-9]\d*)$/, async (m) => {
      const from = Number(m[2]);
      const to = Math.min(Number(m[3]), from + 9);
      if (to < from) throw Object.assign(new Error("invalid page range"), { code: "INVALID_ARGUMENT" });
      const pages = await Promise.all(Array.from({ length: to - from + 1 }, (_, i) => turath.getPage(m[1], from + i).catch(() => undefined)));
      return { items: stripRaw(pages.filter(Boolean)) };
    }],
    ["GET", /^\/api\/narrators$/, async (_m, url) => narrators.search(url.searchParams.get("q")?.trim() ?? "", Number(positive(url.searchParams.get("page") ?? undefined) ?? 1))],
    ["GET", /^\/api\/narrators\/([1-9]\d*)$/, async (m) => narrators.get(m[1])],
    ["GET", /^\/api\/catalog\/categories$/, async () => catalog.listCategories()],
    // Books outside the bundled snapshot that the server has met on Turath.
    ["GET", /^\/api\/catalog\/discovered$/, async () => discovered?.list() ?? { count: 0, books: [] }],
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

  // Answers keep running when the client disconnects (a phone app that goes to
  // the background loses its stream). The client retries with the same
  // requestId and gets the finished answer, or rejoins the running one,
  // without spending Gemini quota again.
  const jobs = new Map();
  // Finished steps of failed answers, so retrying resumes instead of starting over.
  const memos = new Map();
  const JOB_TTL_MS = 20 * 60 * 1000;
  const startJob = (id, body) => {
    const memo = (id && memos.get(id)) || new Map();
    if (id) {
      memos.set(id, memo);
      setTimeout(() => memos.delete(id), JOB_TTL_MS).unref?.();
    }
    const job = { events: [], listeners: new Set(), result: undefined, error: undefined };
    const emit = (event, data) => {
      job.events.push([event, data]);
      for (const l of job.listeners) l(event, data);
    };
    job.done = pipeline
      .ask(body, emit, memo)
      .then((result) => {
        job.result = result;
        logger.info?.("ask", result.status, `${result.sources?.length ?? 0} sources`, result.model, `${result.elapsedMs}ms`, result.depth ?? "");
      })
      .catch((error) => {
        job.error = error;
        const info = errorInfo(error);
        if (info.status >= 500) logger.error("ask failed", error?.code ?? error?.name, error?.message);
        else logger.info?.("ask rejected", info.code, String(info.message ?? "").slice(0, 160));
      })
      .finally(() => {
        job.listeners.clear();
        if (!id) return;
        // Failed answers are not kept: a retry should really try again.
        if (job.error) jobs.delete(id);
        else setTimeout(() => jobs.delete(id), JOB_TTL_MS).unref?.();
      });
    if (id) jobs.set(id, job);
    return job;
  };

  const handleAsk = async (req, res, cors) => {
    if (!gemini) return json(res, 503, { error: { code: "GEMINI_AUTH", message: "GEMINI_API_KEY is not configured on the server" } }, cors);
    const body = await readJson(req);
    const id = typeof body?.requestId === "string" && /^[A-Za-z0-9-]{8,64}$/.test(body.requestId) ? body.requestId : undefined;
    let job = id ? jobs.get(id) : undefined;
    if (!job) {
      const limited = askLimiter(clientKey(req));
      if (!limited.ok) {
        return json(res, 429, { error: { code: "RATE_LIMITED", message: "Too many questions, please wait" } }, { ...cors, "retry-after": String(limited.retryAfter) });
      }
      job = startJob(id, body);
    }
    const stream = String(req.headers.accept ?? "").includes("text/event-stream");
    if (!stream) {
      await job.done;
      if (job.error) throw job.error;
      return json(res, 200, job.result, cors);
    }

    res.writeHead(200, { ...cors, "content-type": "text/event-stream; charset=utf-8", "cache-control": "no-store", connection: "keep-alive", "x-accel-buffering": "no" });
    const send = (event, data) => res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    const heartbeat = setInterval(() => res.write(": keep-alive\n\n"), 15_000);
    for (const [event, data] of job.events) send(event, data);
    job.listeners.add(send);
    req.on("close", () => job.listeners.delete(send));
    try {
      await job.done;
      if (job.error) {
        const info = errorInfo(job.error);
        send("error", { code: info.code, message: info.message });
      } else {
        send("result", job.result);
      }
    } finally {
      job.listeners.delete(send);
      clearInterval(heartbeat);
      res.end();
    }
  };

  // Which delimiters hold a commentary's base text (matn) and its verses,
  // judged by the model from a few sample pages.
  const handleLayers = async (req, res, cors) => {
    if (!gemini) return json(res, 503, { error: { code: "GEMINI_AUTH", message: "GEMINI_API_KEY is not configured on the server" } }, cors);
    const limited = askLimiter(clientKey(req));
    if (!limited.ok) return json(res, 429, { error: { code: "RATE_LIMITED", message: "Too many requests, please wait" } }, { ...cors, "retry-after": String(limited.retryAfter) });
    const body = await readJson(req);
    const pages = (Array.isArray(body?.pages) ? body.pages : []).filter((p) => typeof p === "string" && p.trim()).slice(0, 4).map((p) => p.slice(0, 5000));
    if (!pages.length) throw Object.assign(new Error("pages are required"), { code: "INVALID_ARGUMENT" });
    const result = await gemini.generateJson({
      system: LAYERS_SYSTEM,
      prompt: layersPrompt({ title: typeof body.title === "string" ? body.title.slice(0, 200) : "", pages }),
      schema: LAYERS_SCHEMA,
      temperature: 0,
      tier: "fast",
    });
    return json(res, 200, { ...result.data, model: result.model, usage: result.usage }, cors);
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
      if (req.method === "POST" && url.pathname === "/api/layers") return await handleLayers(req, res, cors);
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
