import assert from "node:assert/strict";
import { test } from "node:test";
import { locateQuote, normalizeArabic } from "../src/verify.mjs";
import { fixtures } from "./helpers.mjs";

const page = fixtures.page5.text;

test("normalization removes diacritics and unifies letters", () => {
  assert.equal(normalizeArabic("إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ"), "انما الاعمال بالنيات");
  assert.equal(normalizeArabic("الصلاة على النبيّ ﷺ (١)"), "الصلاه علي النبي 1");
});

test("exact quote without diacritics is located and returned with original text", () => {
  const found = locateQuote(page, "انما الأعمال بالنيات وإنما لكل امرئ ما نوى");
  assert.ok(found);
  assert.equal(found.exact, true);
  assert.ok(page.includes(found.text), "returned text is a verbatim slice of the page");
  assert.notEqual(found.text, normalizeArabic(found.text), "diacritics of the source are kept");
  assert.equal(normalizeArabic(found.text), "انما الاعمال بالنيات وانما لكل امري ما نوي");
});

test("quote with a dropped word is accepted fuzzily but displayed from the source", () => {
  const found = locateQuote(page, "فمن كانت هجرته إلى الله ورسوله فهجرته إلى ورسوله");
  assert.ok(found);
  assert.equal(found.exact, false);
  assert.ok(found.text.includes("فَمَنْ كَانَتْ هِجْرَتُهُ"));
  assert.ok(page.includes(found.text));
});

test("fabricated quote is rejected", () => {
  assert.equal(locateQuote(page, "من صلى الفجر في جماعة فهو في ذمة الله حتى يمسي"), undefined);
});

test("too short quotes are not accepted as evidence", () => {
  assert.equal(locateQuote(page, "النيات"), undefined);
  assert.equal(locateQuote(page, ""), undefined);
  assert.equal(locateQuote(page, undefined), undefined);
});
