// Lists the data requests app.turath.io makes on its library pages, with a
// short preview of each JSON response, to find the catalog source it uses.
import { chromium } from "playwright";

const browser = await chromium.launch();
const page = await browser.newPage();
page.on("response", async (r) => {
  const url = r.url();
  if (/\.(js|css|woff2?|png|svg|ico|jpg)(\?|$)/.test(url)) return;
  let preview = "";
  try {
    const type = r.headers()["content-type"] || "";
    if (/json|text\/plain|octet/.test(type) || url.includes("api") || url.includes("files")) {
      const body = await r.body();
      preview = `${body.length}B ${body.slice(0, 400).toString("utf8").replace(/\s+/g, " ")}`;
    }
  } catch {}
  console.log("NET", r.status(), url, preview);
});
for (const path of ["/books", "/books/authors", "/author/44", "/book/1681?page=20"]) {
  await page.goto("https://app.turath.io" + path, { waitUntil: "domcontentloaded" }).catch(() => {});
  await page.waitForTimeout(5000);
}
await browser.close();
