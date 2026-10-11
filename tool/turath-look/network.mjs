// Lists the data requests behind Turath's narrators (رواة): the library tab
// and a narrator link in a hadith page, with screenshots of both.
import { chromium } from "playwright";
import fs from "node:fs";

const out = process.argv[2] || "turath-shots";
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 412, height: 900 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
const page = await ctx.newPage();
ctx.on("response", async (r) => {
  const url = r.url();
  if (/\.(js|css|woff2?|png|svg|ico|jpg|wasm|mjs|ttf)(\?|$)/.test(url) || /sentry|cloudflareinsights|blob:|csrf|api\/me|performance/.test(url)) return;
  let preview = "";
  try {
    if (/json/.test(r.headers()["content-type"] ?? "")) preview = (await r.text()).slice(0, 600).replace(/\s+/g, " ");
  } catch {}
  console.log("NET", r.status(), url, preview);
});
const text = async () => (await page.evaluate(() => document.body.innerText)).split("\n").filter(Boolean).slice(0, 60).join(" | ");

await page.goto("https://app.turath.io/books/narrators", { waitUntil: "domcontentloaded" });
await page.waitForTimeout(6000);
await page.screenshot({ path: `${out}/phone-narrators.png` });
console.log("TEXT narrators:", await text());
const first = page.locator("main a, [role=main] a, a[href*='narrator'], a[href*='man']").first();
console.log("first link", await first.getAttribute("href").catch(() => null));

await page.goto("https://app.turath.io/book/1681?page=19", { waitUntil: "domcontentloaded" });
await page.waitForTimeout(6000);
const links = await page.evaluate(() => [...document.querySelectorAll("a[href]")].map((a) => a.getAttribute("href")).filter((h) => /inr|man|narr|rawi/i.test(h)).slice(0, 10));
console.log("NARRATOR LINKS", JSON.stringify(links));
const target = page.locator("text=عُبَيْدُ اللهِ بْنُ مُوسَى").first();
if (await target.isVisible().catch(() => false)) {
  await target.click().catch((e) => console.log("click failed", e.message));
  await page.waitForTimeout(4000);
  await page.screenshot({ path: `${out}/phone-narrator-popup.png` });
  console.log("TEXT after click:", await text());
  console.log("URL", page.url());
}
await browser.close();
