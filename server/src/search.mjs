// Turath full-text search with the options of Turath's own search screen,
// which the Nusus client does not pass on (checked on app.turath.io):
//   precision 1 = some of the words, 2 = all the words (default), 3 = the words in order
//   stem=0       exact forms only (Turath's "البحث الموسع" off)
//   non_author=0 leave out footnotes and editors' introductions
//   scope=toc    search the books' tables of contents
import { NususError } from "nusus";
import { decodePassage } from "./text.mjs";

const entry = import.meta.resolve("nusus/turath");
const { normalizeSearchHit } = await import(new URL("normalize.js", entry).href);

export const hasAdvancedOptions = (o) => (o.precision !== undefined && o.precision !== 2) || o.stem === false || o.nonAuthor === false || o.toc === true;

export const createAdvancedSearch = ({ fetch: fetcher = fetch, timeoutMs = 15_000 } = {}) =>
  async (q, { page = 1, bookId, authorId, categoryId, precision, stem, nonAuthor, toc } = {}) => {
    const url = new URL("https://api.turath.io/search");
    const params = {
      q,
      ver: 3,
      page,
      precision: precision ?? 2,
      author: authorId,
      book: bookId,
      cat_id: categoryId,
      stem: stem === false ? 0 : undefined,
      non_author: nonAuthor === false ? 0 : undefined,
      scope: toc ? "toc" : undefined,
    };
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, String(v));
    let res;
    try {
      res = await fetcher(url, { signal: AbortSignal.timeout(timeoutMs), headers: { accept: "application/json" } });
    } catch (e) {
      throw new NususError("TURATH_UNAVAILABLE", `Turath search failed: ${e?.message ?? e}`);
    }
    if (res.status === 429) throw new NususError("RATE_LIMITED", "Turath is rate limiting requests");
    if (!res.ok) throw new NususError("TURATH_UNAVAILABLE", `Turath search returned ${res.status}`);
    const raw = await res.json();
    if (!raw || typeof raw.count !== "number" || !Array.isArray(raw.data)) throw new NususError("TURATH_UNAVAILABLE", "Turath returned an invalid search response");
    const items = [];
    for (const hit of raw.data) {
      try {
        items.push(decodePassage(normalizeSearchHit(hit)));
      } catch {
        // A hit without its book name is skipped, as Nusus does.
      }
    }
    return { items, totalMatches: raw.count, page };
  };
