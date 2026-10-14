// Measures the research pipeline on a fixed set of questions whose answer is
// known to be in certain books (eval/questions.json): did the sources reach
// one of them, how many books and verified quotes, time, tokens and calls.
// With EVAL_COMPARE=1 every question also runs on the old pipeline (no web
// step, no chapter expansion, one follow-up round) for a side-by-side view.
//   node scripts/eval.mjs            (GEMINI_API_KEY; EVAL_LIMIT, EVAL_DEPTH)
import { writeFileSync } from "node:fs";
import { createTurathClient } from "nusus/turath";
import { catalog } from "../src/catalog.mjs";
import { createGemini } from "../src/gemini.mjs";
import { createPipeline } from "../src/pipeline.mjs";
import questions from "../eval/questions.json" with { type: "json" };

const key = process.env.GEMINI_API_KEY || process.env.GEMINI_API_KYA;
if (!key) {
  console.log("No Gemini key available; nothing to measure.");
  process.exit(0);
}
const limit = Number(process.env.EVAL_LIMIT || questions.length);
const depth = process.env.EVAL_DEPTH || "standard";
const compare = process.env.EVAL_COMPARE === "1" || process.env.EVAL_COMPARE === "true";
const norm = (s) => String(s ?? "").replace(/[ً-ٰٟـ]/g, "").replace(/[أإآٱ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه").replace(/\s+/g, " ").trim();

const gemini = createGemini({ apiKey: key });
const turath = createTurathClient({ timeout: 20_000 });
const modes = { agent: {}, ...(compare ? { old: { web: false, expand: false, limits: { followUpRounds: 1 } } } : {}) };

const runOne = async (q, features) => {
  const pipeline = createPipeline({ gemini, turath, catalog, features });
  const acts = [];
  const started = Date.now();
  try {
    const r = await pipeline.ask({ question: q.question, language: q.language, depth }, (event, data) => event === "activity" && acts.push(data));
    const books = [...new Set(r.sources.map((s) => s.bookTitle))];
    const found = q.expect.filter((e) => books.some((b) => norm(b).includes(norm(e))));
    return {
      status: r.status,
      hit: found.length > 0,
      found,
      books,
      sources: r.sources.length,
      quotes: r.sources.reduce((n, s) => n + s.quotes.length, 0),
      ms: Date.now() - started,
      input: r.usage?.input ?? 0,
      output: r.usage?.output ?? 0,
      calls: r.usage?.calls ?? 0,
      searches: acts.filter((a) => a.kind === "search").length,
      rounds: acts.filter((a) => a.kind === "followup").length,
      expanded: acts.filter((a) => a.kind === "expand").length,
      web: acts.filter((a) => a.kind === "web").flatMap((a) => a.books ?? []),
    };
  } catch (error) {
    return { status: `error ${error.code ?? ""} ${String(error.message).slice(0, 80)}`, hit: false, found: [], books: [], sources: 0, quotes: 0, ms: Date.now() - started, input: 0, output: 0, calls: 0, searches: 0, rounds: 0, expanded: 0, web: [] };
  }
};

const results = [];
for (const q of questions.slice(0, limit)) {
  const row = { id: q.id, kind: q.kind, question: q.question };
  for (const [mode, features] of Object.entries(modes)) {
    row[mode] = await runOne(q, features);
    const r = row[mode];
    console.log(`#${q.id} ${mode.padEnd(5)} ${r.hit ? "HIT " : "miss"} ${r.status.padEnd(12)} ${String(r.ms).padStart(6)}ms ${String(r.input).padStart(6)}+${r.output} tok ${r.calls} calls ${r.searches} searches ${r.rounds} rounds ${r.expanded} expanded | ${r.found.join("، ") || "-"} | web: ${r.web.join("، ") || "-"}`);
  }
  results.push(row);
}

const pct = (xs, p) => {
  const s = [...xs].sort((a, b) => a - b);
  return s.length ? s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))] : 0;
};
const lines = ["| | hit rate | answered | books | quotes | p50 s | p95 s | tokens in | tokens out | calls |", "|---|---|---|---|---|---|---|---|---|---|"];
for (const mode of Object.keys(modes)) {
  const rs = results.map((r) => r[mode]);
  const avg = (f) => (rs.reduce((n, r) => n + f(r), 0) / rs.length).toFixed(1);
  lines.push(
    `| ${mode} | ${rs.filter((r) => r.hit).length}/${rs.length} | ${rs.filter((r) => r.status === "answered" || r.status === "partial").length}/${rs.length} | ${avg((r) => r.books.length)} | ${avg((r) => r.quotes)} | ${(pct(rs.map((r) => r.ms), 50) / 1000).toFixed(1)} | ${(pct(rs.map((r) => r.ms), 95) / 1000).toFixed(1)} | ${avg((r) => r.input)} | ${avg((r) => r.output)} | ${avg((r) => r.calls)} |`,
  );
}
const table = lines.join("\n");
console.log(`\n${table}`);
writeFileSync(process.env.EVAL_OUT || "eval-report.json", JSON.stringify({ depth, results }, null, 1));
if (process.env.GITHUB_STEP_SUMMARY) writeFileSync(process.env.GITHUB_STEP_SUMMARY, `## Research evaluation (${depth})\n\n${table}\n`, { flag: "a" });
