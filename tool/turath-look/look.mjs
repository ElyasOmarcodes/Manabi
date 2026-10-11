// Visits app.turath.io and saves screenshots of its library and reader, plus a
// short dump of each page's controls, so the Manabi library/reader can follow it.
// Usage: node look.mjs <outDir>
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const out = process.argv[2] || "turath-shots";
fs.mkdirSync(out, { recursive: true });
const base = "https://app.turath.io";

const browser = await chromium.launch();
const sizes = { phone: { width: 412, height: 900, deviceScaleFactor: 2, isMobile: true, hasTouch: true }, desk: { width: 1366, height: 860 } };

const controls = (page) =>
  page.evaluate(() => {
    const seen = new Set();
    const rows = [];
    for (const el of document.querySelectorAll("button, a, [role=button], [role=tab], [role=menuitem], input, select, label")) {
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      const t = (el.getAttribute("aria-label") || el.getAttribute("title") || el.innerText || el.getAttribute("placeholder") || "").trim().replace(/\s+/g, " ").slice(0, 60);
      const k = `${el.tagName}|${t}|${el.getAttribute("href") || ""}`;
      if (!t || seen.has(k)) continue;
      seen.add(k);
      rows.push(`${el.tagName.toLowerCase()} "${t}" ${el.getAttribute("href") || ""} @${Math.round(r.x)},${Math.round(r.y)}`);
    }
    return rows.slice(0, 120).join("\n");
  });

async function shot(page, name, note = "") {
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(out, `${name}.png`), fullPage: false });
  console.log(`\n=== ${name} ${page.url()} ${note}\n${await controls(page).catch(() => "")}`);
}

async function clickText(page, texts) {
  for (const t of texts) {
    const loc = page.getByText(t, { exact: false }).first();
    if (await loc.isVisible().catch(() => false)) {
      await loc.click().catch(() => {});
      return t;
    }
    const lab = page.locator(`[aria-label*="${t}"], [title*="${t}"]`).first();
    if (await lab.isVisible().catch(() => false)) {
      await lab.click().catch(() => {});
      return t;
    }
  }
  return null;
}

for (const [size, opts] of Object.entries(sizes)) {
  const ctx = await browser.newContext({ ...opts, locale: "ar" });
  const page = await ctx.newPage();
  const go = async (url) => {
    await page.goto(url, { waitUntil: "networkidle", timeout: 60_000 }).catch((e) => console.log("goto", url, e.message));
  };
  try {
    await go(base + "/");
    await shot(page, `${size}-01-home`);
    await page.mouse.wheel(0, 900);
    await shot(page, `${size}-02-home-scrolled`);

    // The first category on the home page, if any.
    const cat = page.locator('a[href*="/category"], a[href*="cat"]').first();
    if (await cat.isVisible().catch(() => false)) {
      await cat.click().catch(() => {});
      await shot(page, `${size}-03-category`);
    }

    await go(base + "/search?q=" + encodeURIComponent("إنما الأعمال بالنيات"));
    await shot(page, `${size}-04-search`);

    await go(base + "/book/1681");
    await shot(page, `${size}-05-book`);
    await go(base + "/book/1681?page=20");
    await shot(page, `${size}-06-reader`);

    for (const [i, labels] of [
      [7, ["الفهرس", "فهرس", "المحتويات", "Contents", "Index"]],
      [8, ["بحث", "ابحث", "Search"]],
      [9, ["الإعدادات", "إعدادات", "خيارات", "Settings", "عرض"]],
      [10, ["المزيد", "More", "القائمة", "Menu"]],
      [11, ["حجم الخط", "الخط", "Font"]],
      [12, ["الوضع الليلي", "ليلي", "Dark", "السمة"]],
      [13, ["معلومات", "بطاقة", "Info", "عن الكتاب"]],
    ]) {
      const hit = await clickText(page, labels);
      await shot(page, `${size}-${String(i).padStart(2, "0")}-${hit ? "click" : "miss"}`, `clicked=${hit}`);
      await page.keyboard.press("Escape").catch(() => {});
    }
  } catch (e) {
    console.log("error", size, e.message);
  }
  await ctx.close();
}
await browser.close();
