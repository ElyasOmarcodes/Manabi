// Entry point. Configuration comes only from environment variables.
//   GEMINI_API_KYA   Gemini API key (repository secret name; GEMINI_API_KEY is accepted too)
//   GEMINI_MODEL     optional model override, e.g. gemini-2.5-flash
//   PORT / HOST      listen address (default 8787 / 0.0.0.0)
//   ALLOWED_ORIGINS  comma separated CORS origins, default *
//   ASK_LIMIT        questions per client per window (default 20)
//   ASK_WINDOW_MIN   window in minutes (default 10)
//   TRUST_PROXY      1 to trust X-Forwarded-For (behind a reverse proxy)
//   ACCESS_TOKEN     optional bearer token required for /api/* (except health)
import { createTurathClient } from "nusus/turath";
import { createApp } from "./app.mjs";
import { catalog } from "./catalog.mjs";
import { createGemini } from "./gemini.mjs";
import { createPipeline } from "./pipeline.mjs";

const env = process.env;
const apiKey = env.GEMINI_API_KYA || env.GEMINI_API_KEY || "";

const config = {
  port: Number(env.PORT ?? 8787),
  host: env.HOST ?? "0.0.0.0",
  allowedOrigins: (env.ALLOWED_ORIGINS ?? "*").split(",").map((s) => s.trim()).filter(Boolean),
  askLimit: Number(env.ASK_LIMIT ?? 20),
  askWindowMs: Number(env.ASK_WINDOW_MIN ?? 10) * 60_000,
  readLimit: Number(env.READ_LIMIT ?? 240),
  trustProxy: env.TRUST_PROXY === "1",
  accessToken: env.ACCESS_TOKEN || undefined,
};

const turath = createTurathClient({ timeout: 15_000 });
const gemini = apiKey ? createGemini({ apiKey, model: env.GEMINI_MODEL }) : undefined;
const pipeline = createPipeline({ gemini, turath, catalog });
const app = createApp({ config, pipeline, turath, catalog, gemini });

const server = await app.listen(config.port, config.host);
console.log(`manabi-server listening on http://${config.host}:${config.port} (gemini: ${gemini ? "configured" : "MISSING GEMINI_API_KYA"})`);

const shutdown = () => server.close(() => process.exit(0));
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
