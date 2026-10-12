// Which books of the bundled catalog have Turath's scanned PDF, for the
// badge in book lists from the very first launch. One light metadata
// request per book (no pages, no files), a few at a time with pauses, so
// Turath is not loaded. Run by .github/workflows/pdf-flags.yml.
//   node tool/pdf-flags/crawl.mjs
import fs from "node:fs";

const root = new URL("../../", import.meta.url);
const catalog = JSON.parse(fs.readFileSync(new URL("app/assets/catalog/catalog.json", root), "utf8"));
const ids = [...new Set(catalog.books.map((b) => Number(b[0])))].filter((n) => n > 0).sort((a, b) => a - b);
const outputs = [new URL("app/assets/catalog/pdf_flags.json", root), new URL("server/src/data/pdf-flags.json", root)];

const WORKERS = 4;
const PAUSE_MS = 150;
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

const yes = [];
const no = [];
let next = 0;
let done = 0;
const started = Date.now();
await Promise.all(
  Array.from({ length: WORKERS }, async () => {
    while (next < ids.length) {
      const id = ids[next++];
      const v = await one(id);
      if (v === true) yes.push(id);
      else if (v === false) no.push(id);
      if (++done % 500 === 0) console.log(`${done}/${ids.length} · ${yes.length} with a PDF · ${Math.round((Date.now() - started) / 1000)}s`);
      await sleep(PAUSE_MS);
    }
  }),
);
yes.sort((a, b) => a - b);
no.sort((a, b) => a - b);
const unknown = ids.length - yes.length - no.length;
console.log(`done: ${yes.length} with a PDF, ${no.length} without, ${unknown} unknown`);
// A run that failed for most books keeps the old list.
if (unknown > ids.length * 0.2) {
  console.error("too many books could not be read; the list is left as it was");
  process.exit(1);
}
const data = JSON.stringify({ scannedAt: new Date().toISOString().slice(0, 10), with: yes, without: no }) + "\n";
for (const f of outputs) fs.writeFileSync(f, data);
