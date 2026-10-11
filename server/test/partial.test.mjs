import assert from "node:assert/strict";
import { test } from "node:test";
import { partialJsonString } from "../src/partial.mjs";

test("reads a string field from unfinished JSON", () => {
  assert.equal(partialJsonString('{"status":"answered","answer":"line\\none \\"q\\" \\u0627', "answer"), 'line\none "q" ا');
  assert.equal(partialJsonString('{"answer":"done","summary":"x"}', "answer"), "done");
  assert.equal(partialJsonString('{"status":"ans', "answer"), undefined);
  assert.equal(partialJsonString('{"answer":"cut\\', "answer"), "cut");
});

import { decodeEntities } from "../src/text.mjs";

test("HTML entities in Turath text are decoded", () => {
  assert.equal(decodeEntities("&quot;مَنْ جَهَّزَ غَازِيًا&quot; &amp; &#1575;&#x0644; &unknown;"), '"مَنْ جَهَّزَ غَازِيًا" & ال &unknown;');
  assert.equal(decodeEntities("plain"), "plain");
});
