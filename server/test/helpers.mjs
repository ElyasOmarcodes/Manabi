// Test helpers: an offline Turath fetch backed by real recorded API responses
// (fixtures recorded from api.turath.io by the Nusus project, MIT licensed).
import { readFileSync } from "node:fs";
import { createTurathClient } from "nusus/turath";

const load = (name) => JSON.parse(readFileSync(new URL(`./fixtures/${name}`, import.meta.url), "utf8"));
export const fixtures = {
  author: load("author-44.json"),
  book: load("book-147927.json"),
  page5: load("page-147927-5.json"),
  search: load("search-book-147927.json"),
};

const respond = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

export const fixtureFetch = ({ emptySearch = false, fail = false } = {}) => {
  const calls = [];
  const fn = async (input) => {
    const url = new URL(String(input));
    calls.push(url);
    if (fail) return new Response("upstream down", { status: 500 });
    const p = url.searchParams;
    switch (url.pathname) {
      case "/search": {
        if (emptySearch) return respond({ count: 0, data: [] });
        // Queries about intention (نية) hit the recorded page 5 (hadith of intention);
        // everything else returns the recorded search for "الإسلام".
        if (/ني/.test(p.get("q") ?? "")) {
          return respond({ count: 1, data: [{ book_id: 147927, cat_id: 6, author_id: 44, meta: fixtures.page5.meta, text: fixtures.page5.text }] });
        }
        return respond(fixtures.search);
      }
      case "/page": {
        if (p.get("book_id") !== "147927") return respond({});
        const pg = Number(p.get("pg"));
        if (pg === 5) return respond(fixtures.page5);
        const hit = fixtures.search.data.find((h) => JSON.parse(h.meta).page_id === pg);
        return respond(hit ? { meta: hit.meta, text: hit.text } : {});
      }
      case "/book":
        return p.get("id") === "147927" ? respond(fixtures.book) : respond({ error: "not found" }, 404);
      case "/author":
        return respond(p.get("id") === "44" ? fixtures.author : {});
      default:
        return respond({}, 404);
    }
  };
  fn.calls = calls;
  return fn;
};

export const fixtureTurath = (options) => createTurathClient({ fetch: fixtureFetch(options), timeout: 2_000 });

/** Scripted Gemini double: returns queued JSON objects in order. */
export const scriptedGemini = (...outputs) => {
  const prompts = [];
  return {
    prompts,
    resolveModel: async () => "test-model",
    generateJson: async (request) => {
      prompts.push(request);
      const next = outputs.shift();
      if (next instanceof Error) throw next;
      if (!next) throw new Error("unexpected Gemini call");
      return { data: typeof next === "function" ? next(request) : next, model: "test-model" };
    },
  };
};
