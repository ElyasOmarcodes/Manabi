// Quote verification: every Arabic quote shown to the user must be a real
// span of the retrieved Turath text. The model only *points* at a span; the
// text we display is always cut from the source itself.
//
// Keep this file in sync with app/lib/core/pipeline/quote_verifier.dart.

const DIACRITIC = /[ؐ-ًؚ-ٰٟۖ-ۭـ‌-‏]/;
const LIGATURE = /[﴾-﵏ﷰ-﷿]/;

const MAP = new Map([
  ["أ", "ا"], ["إ", "ا"], ["آ", "ا"], ["ٱ", "ا"],
  ["ى", "ي"], ["ی", "ي"], ["ئ", "ي"], ["ې", "ي"], ["ۍ", "ي"],
  ["ة", "ه"], ["ؤ", "و"], ["ک", "ك"],
]);

const isDigitOrLetter = (ch) => /[\p{L}\p{N}]/u.test(ch);

const digit = (ch) => {
  const code = ch.codePointAt(0);
  if (code >= 0x0660 && code <= 0x0669) return String(code - 0x0660);
  if (code >= 0x06f0 && code <= 0x06f9) return String(code - 0x06f0);
  return undefined;
};

/**
 * Normalizes Arabic text for matching and keeps, for every normalized
 * character, the index of the original character it came from.
 */
export const normalizeWithMap = (text) => {
  let out = "";
  const map = [];
  let pendingSpace = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (DIACRITIC.test(ch)) continue;
    let mapped = digit(ch) ?? MAP.get(ch) ?? ch;
    if (LIGATURE.test(ch) || !isDigitOrLetter(mapped)) {
      pendingSpace = out.length > 0;
      continue;
    }
    mapped = mapped.toLowerCase();
    if (pendingSpace) {
      out += " ";
      map.push(i);
      pendingSpace = false;
    }
    out += mapped;
    map.push(i);
  }
  return { text: out, map };
};

export const normalizeArabic = (text) => normalizeWithMap(text).text;

const tokenize = (normalized) => {
  const tokens = [];
  const re = /\S+/g;
  let m;
  while ((m = re.exec(normalized)) !== null) tokens.push({ value: m[0], start: m.index, end: m.index + m[0].length });
  return tokens;
};

/** Extends an original-text end index over trailing combining marks. */
const extendEnd = (original, end) => {
  let e = end;
  while (e < original.length && DIACRITIC.test(original[e])) e += 1;
  return e;
};

const sliceOriginal = (original, norm, startNorm, endNorm) => {
  const start = norm.map[startNorm];
  const end = extendEnd(original, norm.map[endNorm - 1] + 1);
  return original.slice(start, end).trim();
};

const lcsLength = (a, b) => {
  const prev = new Array(b.length + 1).fill(0);
  const cur = new Array(b.length + 1).fill(0);
  let best = 0;
  for (let i = 1; i <= a.length; i += 1) {
    for (let j = 1; j <= b.length; j += 1) {
      cur[j] = a[i - 1] === b[j - 1] ? prev[j - 1] + 1 : Math.max(prev[j], cur[j - 1]);
    }
    for (let j = 0; j <= b.length; j += 1) prev[j] = cur[j];
    best = prev[b.length];
  }
  return best;
};

export const MIN_QUOTE_TOKENS = 3;
export const FUZZY_THRESHOLD = 0.8;

/**
 * Locates `quote` inside `source`.
 * Returns `{ text, exact, score }` where `text` is the span cut from the
 * ORIGINAL source (with its diacritics), or `undefined` when not found.
 */
export const locateQuote = (source, quote) => {
  if (typeof source !== "string" || typeof quote !== "string") return undefined;
  const src = normalizeWithMap(source);
  const q = normalizeArabic(quote);
  const qTokens = q.split(" ").filter(Boolean);
  if (qTokens.length < MIN_QUOTE_TOKENS) return undefined;

  const exactAt = src.text.indexOf(q);
  if (exactAt >= 0) {
    return { text: sliceOriginal(source, src, exactAt, exactAt + q.length), exact: true, score: 1 };
  }

  const sTokens = tokenize(src.text);
  const m = qTokens.length;
  const windowLength = m + Math.ceil(m * 0.25);
  const firstWords = new Set(qTokens.slice(0, 3));
  let best = { score: 0, from: -1, to: -1 };
  for (let s = 0; s < sTokens.length; s += 1) {
    if (!firstWords.has(sTokens[s].value)) continue;
    const window = sTokens.slice(s, s + windowLength);
    const values = window.map((t) => t.value);
    const score = lcsLength(qTokens, values) / m;
    if (score > best.score) {
      // Trim the window to the last token that belongs to the quote.
      const quoteSet = new Set(qTokens);
      let last = window.length - 1;
      while (last > 0 && !quoteSet.has(window[last].value)) last -= 1;
      best = { score, from: s, to: s + last };
    }
  }
  if (best.score < FUZZY_THRESHOLD) return undefined;
  return {
    text: sliceOriginal(source, src, sTokens[best.from].start, sTokens[best.to].end),
    exact: false,
    score: Math.round(best.score * 100) / 100,
  };
};
