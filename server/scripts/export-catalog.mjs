// Exports the Nusus offline Turath catalog to the Flutter app assets.
//   node scripts/export-catalog.mjs [output-path]
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { catalog } from "../src/catalog.mjs";

const out = process.argv[2] ?? new URL("../../app/assets/catalog/catalog.json", import.meta.url).pathname;
const payload = {
  source: "Turath catalog snapshot bundled with the Nusus SDK (https://github.com/mwijanarko1/nusus)",
  scannedAt: catalog.scannedAt,
  categories: catalog.raw.categories,
  authors: catalog.raw.authors,
  books: catalog.raw.books,
};
mkdirSync(path.dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(payload));
console.log(`wrote ${out}: ${payload.books.length} books, ${payload.authors.length} authors, ${payload.categories.length} categories`);
