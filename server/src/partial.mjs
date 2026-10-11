// Reads one string field out of a JSON object that is still being streamed,
// e.g. the "answer" of a reply whose closing quote has not arrived yet.

const ESCAPES = { '"': '"', "\\": "\\", "/": "/", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t" };

export const partialJsonString = (text, key) => {
  const at = text.indexOf(`"${key}"`);
  if (at < 0) return undefined;
  let i = text.indexOf(":", at + key.length + 2);
  if (i < 0) return undefined;
  i += 1;
  while (i < text.length && /\s/.test(text[i])) i += 1;
  if (text[i] !== '"') return undefined;
  i += 1;
  let out = "";
  while (i < text.length) {
    const c = text[i];
    if (c === '"') return out;
    if (c !== "\\") {
      out += c;
      i += 1;
      continue;
    }
    const e = text[i + 1];
    if (e === undefined) break;
    if (e === "u") {
      const hex = text.slice(i + 2, i + 6);
      if (hex.length < 4) break;
      out += String.fromCharCode(parseInt(hex, 16));
      i += 6;
    } else {
      out += ESCAPES[e] ?? e;
      i += 2;
    }
  }
  return out;
};
