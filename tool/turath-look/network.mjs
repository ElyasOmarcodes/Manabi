// Tries each option of Turath's full-text search (options and filter menus)
// and logs the search request it makes and the number of results, so
// Manabi's search can offer the same options with the same meaning.
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const out = process.argv[2] || "turath-shots";
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 412, height: 900 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: "ar" });
const page = await ctx.newPage();
page.on("response", async (res) => {
  const url = res.url();
  if (!url.includes("api.turath.io") && !url.includes("turath.io/api")) return;
  let note = "";
  try {
    const j = await res.json();
    note = j && typeof j === "object" ? `count=${j.count ?? j.total ?? "?"} keys=${Object.keys(j).slice(0, 8)}` : "";
    if (Array.isArray(j?.data) && j.data[0]) note += ` first=${JSON.stringify(j.data[0]).slice(0, 300)}`;
  } catch {}
  console.log("API", res.status(), decodeURIComponent(url), note);
});

const controls = () =>
  page.evaluate(() => {
    const rows = [];
    for (const el of document.querySelectorAll("button, a, [role=button], [role=menuitem], [role=switch], [role=radio], [role=checkbox], [role=option], input, select, label, li")) {
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      const t = (el.getAttribute("aria-label") || el.innerText || el.getAttribute("placeholder") || "").trim().replace(/\s+/g, " ").slice(0, 80);
      if (!t) continue;
      const state = el.getAttribute("aria-checked") ?? el.getAttribute("aria-pressed") ?? (el.checked !== undefined ? String(el.checked) : "");
      rows.push(`${el.tagName.toLowerCase()} "${t}" ${state}`);
    }
    return [...new Set(rows)].slice(0, 120).join("\n");
  });

const q = "إنما الأعمال بالنيات";
const open = async () => {
  await page.goto("https://app.turath.io/search?q=" + encodeURIComponent(q), { waitUntil: "domcontentloaded", timeout: 45_000 });
  await page.waitForTimeout(4000);
};
const shot = (name) => page.screenshot({ path: path.join(out, `${name}.png`) }).catch(() => {});
const clickText = async (text) => {
  const loc = page.getByText(text, { exact: false }).first();
  if (!(await loc.isVisible().catch(() => false))) return false;
  await loc.click({ timeout: 5000 }).catch(() => {});
  return true;
};

await open();
console.log("\n=== BASE", page.url());

const options = ["بعض الكلمات", "كل الكلمات متتالية", "كل الكلمات", "البحث الموسع", "بحث في الهامش والمقدمات", "إظهار كل نتيجة بتمامها", "إخفاء الحركات", "البحث في الكتب المحمّلة فقط"];
for (const opt of options) {
  await open();
  await page.locator('[aria-label="خيارات البحث"]').first().click({ timeout: 5000 }).catch(() => {});
  await page.waitForTimeout(800);
  const hit = await clickText(opt);
  console.log(`\n=== OPTION ${opt} clicked=${hit}`);
  await page.waitForTimeout(3500);
  console.log("URL", decodeURIComponent(page.url()));
  if (opt === "إظهار كل نتيجة بتمامها" || opt === "البحث الموسع") {
    await page.keyboard.press("Escape").catch(() => {});
    await page.waitForTimeout(600);
    await shot(`option-${options.indexOf(opt)}`);
  }
  console.log("LS", await page.evaluate(() => JSON.stringify(Object.fromEntries(Object.entries(localStorage).filter(([k]) => /search|opt|prec|setting/i.test(k)).map(([k, v]) => [k, v.slice(0, 300)])))));
}

const filters = ["الكتاب", "المؤلف", "القسم", "حال الطبع", "نوع المحتوى", "قرن وفاة المؤلف", "البحث بـ«و» و«أو»", "الكتب التسعة", "الحديث وشروحه", "ابن تيمية وابن القيم"];
for (const f of filters) {
  await open();
  await page.locator('[aria-label="تصفية البحث"]').first().click({ timeout: 5000 }).catch(() => {});
  await page.waitForTimeout(800);
  const hit = await clickText(f);
  await page.waitForTimeout(2500);
  console.log(`\n=== FILTER ${f} clicked=${hit} URL ${decodeURIComponent(page.url())}`);
  console.log(await controls());
  await shot(`filter-${filters.indexOf(f)}`);
  // Pick the first choice offered, to see the request it makes.
  if (["حال الطبع", "نوع المحتوى", "قرن وفاة المؤلف"].includes(f)) {
    const choice = page.locator('[role=option], [role=checkbox], [role=menuitem], li').nth(1);
    const t = await choice.innerText().catch(() => "");
    await choice.click({ timeout: 3000 }).catch(() => {});
    await page.waitForTimeout(3000);
    console.log(`CHOSE "${t.trim().slice(0, 60)}" URL ${decodeURIComponent(page.url())}`);
    await page.keyboard.press("Escape").catch(() => {});
    await page.waitForTimeout(2500);
  }
}
await browser.close();
