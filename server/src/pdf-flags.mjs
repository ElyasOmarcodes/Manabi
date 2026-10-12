// Which books have Turath's scanned PDF, for the badge in book lists. Asks
// Turath's book endpoint (metadata only, no page index) once per book and
// keeps the answer (in memory, and in MANABI_DATA_DIR when set).
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

// The list built monthly from Turath (tool/pdf-flags/crawl.mjs), when present.
const SEED = new URL("./data/pdf-flags.json", import.meta.url);

export const createPdfFlags = ({ fetch: fetcher = fetch, dataDir, timeoutMs = 12_000, concurrency = 6, seed = SEED } = {}) => {
  const known = new Map();
  const file = dataDir ? join(dataDir, "pdf-flags.json") : undefined;
  let timer;
  const save = () => {
    if (!file) return;
    mkdir(dataDir, { recursive: true })
      .then(() => writeFile(file, JSON.stringify(Object.fromEntries(known))))
      .catch(() => {});
  };
  const one = async (id) => {
    const res = await fetcher(`https://api.turath.io/book?id=${id}&ver=3`, { signal: AbortSignal.timeout(timeoutMs) });
    if (!res.ok) return undefined;
    const j = await res.json();
    const files = j?.meta?.pdf_links?.files;
    return Array.isArray(files) && files.some((f) => typeof f === "string" && f.trim());
  };
  return {
    load: async () => {
      if (seed) {
        try {
          const j = JSON.parse(await readFile(seed, "utf8"));
          for (const id of j.with ?? []) known.set(String(id), true);
          for (const id of j.without ?? []) known.set(String(id), false);
        } catch {}
      }
      if (!file) return;
      try {
        for (const [k, v] of Object.entries(JSON.parse(await readFile(file, "utf8")))) known.set(k, v === true);
      } catch {}
    },
    /** Every answer known so far, { id: true|false } (for the app's first-run library). */
    all: () => Object.fromEntries(known),
    /** { id: true|false } for the ids asked (unknown ones that fail are left out). */
    lookup: async (ids) => {
      const out = {};
      const todo = [];
      for (const id of ids) {
        if (known.has(id)) out[id] = known.get(id);
        else todo.push(id);
      }
      let next = 0;
      const worker = async () => {
        while (next < todo.length) {
          const id = todo[next++];
          try {
            const v = await one(id);
            if (v === undefined) continue;
            known.set(id, v);
            out[id] = v;
          } catch {}
        }
      };
      await Promise.all(Array.from({ length: Math.min(concurrency, todo.length) }, worker));
      if (todo.length && file && !timer) {
        timer = setTimeout(() => ((timer = undefined), save()), 5_000);
        timer.unref?.();
      }
      return out;
    },
  };
};
