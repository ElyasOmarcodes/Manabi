// Match-centred excerpts from the Nusus SDK (not part of its public exports,
// so it is loaded next to the exported entry point).
const entry = import.meta.resolve("nusus/turath");
const mod = await import(new URL("excerpt.js", entry).href);

/** @type {(text: string, maxChars: number, snippet?: string) => { text: string, offset: number, truncated: boolean }} */
export const boundText = (text, maxChars, snippet) => mod.boundText(String(text ?? ""), maxChars, typeof snippet === "string" ? snippet : undefined);
