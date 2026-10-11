// Lists the requests app.turath.io makes when a book's PDF is opened, to find
// where its PDF links point.
import { chromium } from "playwright";

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1366, height: 860 } });
const page = await ctx.newPage();
const log = (r) => {
  const url = r.url();
  if (/\.(js|css|woff2?|png|svg|ico|jpg|wasm|mjs)(\?|$)/.test(url) || /sentry|cloudflareinsights|blob:/.test(url)) return;
  console.log("NET", r.status(), r.headers()["content-type"] ?? "", url);
};
ctx.on("response", log);
ctx.on("page", (p) => console.log("POPUP", p.url()));
await page.goto("https://app.turath.io/book/1681?page=20", { waitUntil: "domcontentloaded" });
await page.waitForTimeout(6000);
for (const sel of ['[aria-label="PDF"]', "text=PDF"]) {
  const loc = page.locator(sel).first();
  if (await loc.isVisible().catch(() => false)) {
    await loc.click().catch((e) => console.log("click failed", e.message));
    console.log("clicked", sel);
    break;
  }
}
await page.waitForTimeout(8000);
console.log("URL after", page.url());
for (const p of ctx.pages()) console.log("PAGE", p.url());
const links = await page.evaluate(() => [...document.querySelectorAll("a[href], iframe[src], embed[src], object[data]")].map((e) => e.getAttribute("href") || e.getAttribute("src") || e.getAttribute("data")).filter((h) => /pdf/i.test(h)).slice(0, 20));
console.log("PDF LINKS", JSON.stringify(links));
await browser.close();
