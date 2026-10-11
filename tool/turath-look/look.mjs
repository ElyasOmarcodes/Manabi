// Visits app.turath.io and saves screenshots of its library, reader and
// settings (with their panels open), plus a dump of each page's controls, so
// the Manabi library and reader can follow the same structure.
// Usage: node look.mjs <outDir>
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const out = process.argv[2] || "turath-shots";
fs.mkdirSync(out, { recursive: true });
const base = "https://app.turath.io";
const book = "/book/1681?page=20";

const sizes = {
  phone: { viewport: { width: 412, height: 900 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
  desk: { viewport: { width: 1366, height: 860 } },
};

// Each step: open a URL (or stay), click controls by aria-label/title/text, then shoot.
const steps = [
  { name: "library-all", url: "/books" },
  { name: "library-authors", url: "/books/authors" },
  { name: "library-categories-open", url: "/books/categories", click: ["text=العقيدة"] },
  { name: "book-info", url: "/books", click: ['[aria-label="معلومات عن الكتاب"]'] },
  { name: "category-page", url: "/category/6" },
  { name: "author-page", url: "/author/44" },
  { name: "search-filter", url: "/search?q=" + encodeURIComponent("إنما الأعمال بالنيات"), click: ['[aria-label="تصفية البحث"]'] },
  { name: "search-options", url: "/search?q=" + encodeURIComponent("إنما الأعمال بالنيات"), click: ['[aria-label="خيارات البحث"]'] },
  { name: "reader", url: book },
  { name: "reader-tools", url: book, click: ['[aria-label="عرض الأدوات"]'] },
  { name: "reader-mode", url: book, click: ['[aria-label="وضع القراءة"]'] },
  { name: "reader-search", url: book, click: ['[aria-label="بحث في الكتاب"]'] },
  { name: "reader-page-menu", url: book, click: ['[aria-label="المزيد"]', "text=…", "text=..."] },
  { name: "reader-highlights", url: book, click: ['[aria-label="التظليل"]', "text=تظليل"] },
  { name: "reader-bookmarks", url: book, click: ['[aria-label="العلامات المرجعية"]'] },
  { name: "reader-history", url: book, click: ['[aria-label="السجل"]'] },
  { name: "reader-settings-gear", url: book, click: ['[aria-label*="إعدادات القراءة"]', '[aria-label*="خيارات"]', '[aria-label*="الإعدادات"]'] },
  { name: "settings", url: "/settings", full: true },
  { name: "settings-appearance", url: "/settings", click: ["text=المظهر واللغة"], full: true },
  { name: "settings-reading", url: "/settings", click: ["text=خيارات صفحة القراءة"], full: true },
  { name: "settings-tabs", url: "/settings", click: ["text=التبويبات"], full: true },
];

const controls = (page) =>
  page.evaluate(() => {
    const seen = new Set();
    const rows = [];
    for (const el of document.querySelectorAll("button, a, [role=button], [role=tab], [role=menuitem], [role=switch], [role=radio], input, select, label, summary")) {
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      const t = (el.getAttribute("aria-label") || el.getAttribute("title") || el.innerText || el.getAttribute("placeholder") || "").trim().replace(/\s+/g, " ").slice(0, 70);
      const k = `${el.tagName}|${t}`;
      if (!t || seen.has(k)) continue;
      seen.add(k);
      const state = el.getAttribute("aria-checked") ?? el.getAttribute("aria-pressed") ?? (el.checked !== undefined ? String(el.checked) : "");
      rows.push(`${el.tagName.toLowerCase()} "${t}" ${state} @${Math.round(r.x)},${Math.round(r.y)}`);
    }
    return rows.filter((r) => !/@\d+,\d+$/.test(r) || true).slice(0, 160).join("\n");
  });

const browser = await chromium.launch();
for (const [size, opts] of Object.entries(sizes)) {
  const ctx = await browser.newContext({ ...opts, locale: "ar" });
  const page = await ctx.newPage();
  for (const step of steps) {
    try {
      if (step.url) await page.goto(base + step.url, { waitUntil: "domcontentloaded", timeout: 45_000 });
      await page.waitForTimeout(3500);
      let hit = "";
      for (const sel of step.click || []) {
        const loc = page.locator(sel).first();
        if (await loc.isVisible().catch(() => false)) {
          await loc.click({ timeout: 5000 }).catch(() => {});
          hit = sel;
          break;
        }
      }
      await page.waitForTimeout(1500);
      await page.screenshot({ path: path.join(out, `${size}-${step.name}.png`), fullPage: Boolean(step.full) });
      console.log(`\n=== ${size}-${step.name} ${page.url()} clicked=${hit || "-"}\n${await controls(page).catch(() => "")}`);
    } catch (e) {
      console.log("error", size, step.name, e.message);
    }
  }
  await ctx.close();
}
await browser.close();
