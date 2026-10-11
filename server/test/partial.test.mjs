import assert from "node:assert/strict";
import { test } from "node:test";
import { partialJsonString } from "../src/partial.mjs";

test("reads a string field from unfinished JSON", () => {
  assert.equal(partialJsonString('{"status":"answered","answer":"line\\none \\"q\\" \\u0627', "answer"), 'line\none "q" ا');
  assert.equal(partialJsonString('{"answer":"done","summary":"x"}', "answer"), "done");
  assert.equal(partialJsonString('{"status":"ans', "answer"), undefined);
  assert.equal(partialJsonString('{"answer":"cut\\', "answer"), "cut");
});
