// 1) The PDF files Turath lists for a few books (روح المعاني shows only a
//    cover in Manabi) and which file/page Turath's reader opens.
// 2) What Turath's smart (AI) search requests, to learn how it finds and
//    reads its sources.
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const out = process.argv[2] || "turath-shots";
fs.mkdirSync(out, { recursive: true });
const H = { origin: "https://app.turath.io", referer: "https://app.turath.io/" };
for (const id of [22835, 1681, 8176]) {
  const b = await (await fetch(`https://api.turath.io/book?id=${id}&include=indexes&ver=3`, { headers: H })).json();
  console.log("PDFLINKS", id, JSON.stringify(b.meta?.pdf_links));
  console.log("VOLS", id, JSON.stringify(b.indexes?.volumes), JSON.stringify(b.indexes?.volume_bounds));
  const meta = await (await fetch(`https://api.turath.io/book?id=${id}&ver=3`, { headers: H })).json();
  console.log("METAONLY", id, Object.keys(meta), JSON.stringify(meta.meta?.pdf_links ?? null).slice(0, 200));
}

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 412, height: 900 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: "ar" });
const page = await ctx.newPage();
page.on("request", (req) => {
  const u = req.url();
  if (/turath\.io\/(api|search|page|book|ai|chat|ask)|api\.turath\.io/.test(u) && !/diagnostics|csrf|patches/.test(u)) {
    console.log("REQ", req.method(), decodeURIComponent(u).slice(0, 400), (req.postData() ?? "").slice(0, 600));
  }
});
page.on("response", async (res) => {
  const u = res.url();
  if (!/ai|chat|ask|answer|smart|rag/i.test(u) || /diagnostics/.test(u)) return;
  let body = "";
  try {
    body = (await res.text()).slice(0, 1500);
  } catch {}
  console.log("RES", res.status(), decodeURIComponent(u).slice(0, 300), body.replace(/\s+/g, " "));
});

// The PDF reader of روح المعاني at a page in the middle of a volume.
await page.goto("https://app.turath.io/book/22835?page=1500", { waitUntil: "domcontentloaded", timeout: 45_000 });
await page.waitForTimeout(5000);
await page.locator('[aria-label="PDF"]').first().click({ timeout: 5000 }).catch(() => console.log("no PDF button"));
await page.waitForTimeout(6000);
console.log("PDFURL", decodeURIComponent(page.url()));
await page.screenshot({ path: path.join(out, "ruh-pdf.png") });

// Smart search.
await page.goto("https://app.turath.io/search?mode=ai", { waitUntil: "domcontentloaded", timeout: 45_000 });
await page.waitForTimeout(3000);
const smart = page.getByText("ذكي").first();
await smart.click({ timeout: 5000 }).catch(() => console.log("no smart tab"));
await page.waitForTimeout(1500);
const input = page.locator("input, textarea").first();
await input.fill("ما حكم مس المصحف للمحدث؟").catch(() => console.log("no input"));
await input.press("Enter").catch(() => {});
await page.waitForTimeout(45000);
console.log("SMARTURL", decodeURIComponent(page.url()));
console.log("TEXT", (await page.evaluate(() => document.body.innerText)).replace(/\s+/g, " ").slice(0, 3000));
await page.screenshot({ path: path.join(out, "smart.png") });
await browser.close();
