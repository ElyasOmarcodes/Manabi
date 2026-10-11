// Turath page text arrives with HTML entities (&quot; &amp; &#8230; …);
// they are decoded once here so readers, quotes and citations see real text.

const NAMED = { quot: '"', amp: "&", lt: "<", gt: ">", apos: "'", nbsp: " ", laquo: "«", raquo: "»", hellip: "…", ndash: "–", mdash: "—", zwnj: "‌", zwj: "‍", lrm: "‎", rlm: "‏" };

export const decodeEntities = (value) =>
  typeof value !== "string" || !value.includes("&")
    ? value
    : value.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (whole, code) => {
        if (code[0] === "#") {
          const n = code[1] === "x" || code[1] === "X" ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
          return Number.isFinite(n) && n > 0 && n <= 0x10ffff ? String.fromCodePoint(n) : whole;
        }
        return NAMED[code.toLowerCase()] ?? whole;
      });

/** Narrators linked in a raw hadith page: <a href="inr://man-ID">name</a>. */
export const narratorsIn = (raw) =>
  typeof raw !== "string"
    ? []
    : [...raw.matchAll(/<a href="inr:\/\/man-(\d+)"[^>]*>([^<]+)<\/a>/g)].map((m) => ({ id: m[1], name: decodeEntities(m[2]).trim().replace(/[،,]+$/, "").trim() }));

export const decodePassage = (p) => {
  if (!p || typeof p !== "object") return p;
  const out = { ...p, text: decodeEntities(p.text), snippet: decodeEntities(p.snippet) };
  const narrators = narratorsIn(p.raw?.text);
  if (narrators.length) out.narrators = narrators;
  if (p.raw && typeof p.raw === "object") out.raw = { ...p.raw, snip: decodeEntities(p.raw.snip) };
  return out;
};

/** Wraps a Nusus Turath client so every page and search hit has decoded text. */
export const decodingTurath = (turath) => {
  if (!turath || turath.__decoding) return turath;
  const wrapped = Object.create(turath);
  wrapped.__decoding = true;
  if (typeof turath.search === "function") {
    wrapped.search = async (...args) => {
      const result = await turath.search(...args);
      return result && Array.isArray(result.items) ? { ...result, items: result.items.map(decodePassage) } : result;
    };
  }
  if (typeof turath.getPage === "function") wrapped.getPage = async (...args) => decodePassage(await turath.getPage(...args));
  return wrapped;
};
