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

const WORKERS = 6;
const PAUSE_MS = 100;
// Stop in time for the workflow to commit what was learned; the next run
// goes on from there.
const BUDGET_MS = Number(process.env.CRAWL_MINUTES ?? 70) * 60_000;
const FULL = process.argv.includes("--full");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const one = async (id) => {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(`https://api.turath.io/book?id=${id}&ver=3`, { signal: AbortSignal.timeout(20_000), headers: { "user-agent": "Manabi (PDF list, monthly)" } });
      if (res.status === 404) return undefined;
      if (res.status === 429 || res.status >= 500) throw new Error(`HTTP ${res.status}`);
      const j = await res.json();
      const files = j?.meta?.pdf_links?.files;
      return Array.isArray(files) && files.some((f) => typeof f === "string" && f.trim());
    } catch {
      await sleep(2000 * (attempt + 1));
    }
  }
  return undefined;
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
  for (const f of outputs) fs.writeFileSync(f, data);
  return { yes: yes.length, no: no.length };
};

const started = Date.now();
let next = 0;
let done = 0;
let failed = 0;
await Promise.all(
  Array.from({ length: WORKERS }, async () => {
    while (next < todo.length && Date.now() - started < BUDGET_MS) {
      const id = todo[next++];
      const v = await one(id);
      if (v === undefined) failed++;
      else known.set(id, v);
      if (++done % 250 === 0) {
        const c = save();
        console.log(`${done}/${todo.length} asked · ${c.yes} with a PDF · ${failed} failed · ${Math.round((Date.now() - started) / 1000)}s`);
      }
      await sleep(PAUSE_MS);
    }
  }),
);
const c = save();
console.log(`saved: ${c.yes} with a PDF, ${c.no} without, ${ids.length - c.yes - c.no} still unknown (${done} asked this run, ${failed} failed)`);
