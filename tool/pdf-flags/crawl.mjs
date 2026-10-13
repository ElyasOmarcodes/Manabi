// Which books of the bundled catalog have Turath's scanned PDF, for the
// badge in book lists from the very first launch. One light metadata
// request per book (no pages, no files), a few at a time with pauses, so
// Turath is not loaded. Run by .github/workflows/pdf-flags.yml.
//   node tool/pdf-flags/crawl.mjs          (only books not yet known)
//   node tool/pdf-flags/crawl.mjs --full   (all books again)
import fs from "node:fs";

const root = new URL("../../", import.meta.url);
const catalog = JSON.parse(fs.readFileSync(new URL("app/assets/catalog/catalog.json", root), "utf8"));
const ids = [...new Set(catalog.books.map((b) => Number(b[0])))].filter((n) => n > 0).sort((a, b) => a - b);
const outputs = [new URL("app/assets/catalog/pdf_flags.json", root), new URL("server/src/data/pdf-flags.json", root)];

const WORKERS = 4;
const PAUSE_MS = 250;
// Stop in time for the workflow to commit what was learned; the next run
// goes on from there.
const BUDGET_MS = Number(process.env.CRAWL_MINUTES ?? 70) * 60_000;
const FULL = process.argv.includes("--full");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Turath turns away bursts for a while (429s, timeouts). Then every worker
// waits together, longer each time, and the book is asked again later.
let coolUntil = 0;
let cooldown = 20_000;
const backOff = (retryAfter) => {
  // Turath's Retry-After can be an hour; never wait more than five minutes at a time.
  const wait = Math.min(Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : cooldown, 300_000);
  coolUntil = Math.max(coolUntil, Date.now() + wait);
  cooldown = Math.min(cooldown * 2, 300_000);
};

/** true / false, or "retry" when Turath did not answer this time. */
const one = async (id) => {
  try {
    const res = await fetch(`https://api.turath.io/book?id=${id}&ver=3`, { signal: AbortSignal.timeout(20_000), headers: { "user-agent": "Manabi (PDF list, monthly)" } });
    // A book Turath no longer has has no PDF either.
    if (res.status === 404) return false;
    if (res.status === 429 || res.status >= 500) {
      backOff(Number(res.headers.get("retry-after")));
      return "retry";
    }
    const j = await res.json();
    cooldown = Math.max(20_000, cooldown / 2);
    const files = j?.meta?.pdf_links?.files;
    return Array.isArray(files) && files.some((f) => typeof f === "string" && f.trim());
  } catch {
    backOff();
    return "retry";
  }
};

// What earlier runs learned (a monthly --full run asks again about all).
const known = new Map();
try {
  const old = JSON.parse(fs.readFileSync(outputs[0], "utf8"));
  for (const id of old.with ?? []) known.set(id, true);
  for (const id of old.without ?? []) known.set(id, false);
} catch {}
const todo = FULL ? ids : ids.filter((id) => !known.has(id));
console.log(`${ids.length} books, ${known.size} known, ${todo.length} to ask${FULL ? " (full run)" : ""}`);

const save = () => {
  const yes = [];
  const no = [];
  for (const id of ids) {
    const v = known.get(id);
    if (v === true) yes.push(id);
    else if (v === false) no.push(id);
  }
  const data = JSON.stringify({ scannedAt: new Date().toISOString().slice(0, 10), with: yes, without: no }) + "\n";
  for (const f of outputs) {
    fs.mkdirSync(new URL(".", f), { recursive: true });
    fs.writeFileSync(f, data);
  }
  return { yes: yes.length, no: no.length };
};

const started = Date.now();
const queue = [...todo];
const tries = new Map();
let done = 0;
let failed = 0;
let waited = 0;
const timeLeft = () => Date.now() - started < BUDGET_MS;
await Promise.all(
  Array.from({ length: WORKERS }, async () => {
    while (queue.length && timeLeft()) {
      if (Date.now() < coolUntil) {
        // Not past the budget, so the run always ends in time to commit.
        const ms = Math.min(coolUntil - Date.now(), BUDGET_MS - (Date.now() - started));
        waited += ms;
        await sleep(ms);
        continue;
      }
      const id = queue.shift();
      const v = await one(id);
      if (v === "retry") {
        const n = (tries.get(id) ?? 0) + 1;
        tries.set(id, n);
        if (n < 6) queue.push(id);
        else failed++;
      } else {
        known.set(id, v);
        if (++done % 250 === 0) {
          const c = save();
          console.log(`${done}/${todo.length} known · ${c.yes} with a PDF · ${queue.length} waiting · ${Math.round(waited / 1000)}s cooling · ${Math.round((Date.now() - started) / 1000)}s`);
        }
      }
      await sleep(PAUSE_MS);
    }
  }),
);
const c = save();
const unknown = ids.length - c.yes - c.no;
console.log(`saved: ${c.yes} with a PDF, ${c.no} without, ${unknown} still unknown (${done} learned this run, ${failed} given up)`);
// For the workflow: go on in another run while something is learned.
if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, `unknown=${unknown}\nlearned=${done}\n`);
