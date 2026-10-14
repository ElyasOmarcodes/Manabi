// The web app's PDF reader (app/web/pdfjs) in a real browser on a real
// Turath volume: through a relay like the site's /turath-pdf, and straight
// from files.turath.io (another site), timing page N and counting bytes.
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";

const dir = path.resolve("../../app/web/pdfjs");
const file = process.argv[2] || "shamela/roohm_04.pdf";
const page = Number(process.argv[3] || 284);
let relayed = 0, requests = 0;
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://x");
  if (url.pathname.startsWith("/turath-pdf/")) {
    requests++;
    const r = await fetch(`https://files.turath.io/pdf/${url.pathname.slice(12)}`, { headers: req.headers.range ? { range: req.headers.range } : {} });
    const h = { "content-type": "application/pdf", "accept-ranges": "bytes" };
    for (const k of ["content-length", "content-range"]) if (r.headers.get(k)) h[k] = r.headers.get(k);
    res.writeHead(r.status, h);
    // Streamed like the Pages Function; a request the browser drops stops here.
    const reader = r.body.getReader();
    let gone = false;
    res.on("close", () => { gone = true; reader.cancel().catch(() => {}); });
    for (;;) {
      const { done, value } = await reader.read().catch(() => ({ done: true }));
      if (done || gone) break;
      relayed += value.length;
      if (!res.write(value)) await new Promise((ok) => res.once("drain", ok).once("close", ok));
    }
    return res.end();
  }
  if (url.pathname === "/") {
    res.writeHead(200, { "content-type": "text/html" });
    return res.end(`<!doctype html><img id=o style="width:600px"><script type=module>
import "./pdfjs/manabi_pdf.mjs";
const src = new URLSearchParams(location.search).get("src");
const t = performance.now();
const [id, n] = await manabiPdf.open(src, null, null);
const opened = performance.now() - t;
const u = await manabiPdf.render(id, ${page}, 900);
document.getElementById("o").src = u;
window.result = { pages: n, openMs: Math.round(opened), pageMs: Math.round(performance.now() - t) };
</script>`);
  }
  const f = path.join(dir, url.pathname.replace("/pdfjs/", ""));
  if (!f.startsWith(dir) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "content-type": "text/javascript" });
  fs.createReadStream(f).pipe(res);
});
await new Promise((r) => server.listen(8790, r));
const browser = await chromium.launch();
for (const [label, src] of [["relay", `http://127.0.0.1:8790/turath-pdf/${file}`], ["direct", `https://files.turath.io/pdf/${file}`]]) {
  const p = await browser.newPage();
  let bytes = 0;
  p.on("requestfinished", async (r) => { if (r.url().includes(".pdf")) { try { bytes += (await r.sizes()).responseBodySize; } catch {} } });
  relayed = 0; requests = 0;
  await p.goto(`http://127.0.0.1:8790/?src=${encodeURIComponent(src)}`);
  try {
    await p.waitForFunction(() => window.result, null, { timeout: 120000 });
    const r = await p.evaluate(() => window.result);
    await p.waitForTimeout(300);
    console.log(`web pdf ${label}: ${r.pages} pages, open ${r.openMs} ms, page ${page} drawn at ${r.pageMs} ms, ${label === "relay" ? `${requests} requests, ${relayed >> 10} KB` : `${bytes >> 10} KB`}`);
  } catch (e) {
    console.log(`web pdf ${label}: failed or slower than 120 s (${String(e.message).slice(0, 80)}), ${bytes >> 10} KB so far`);
  }
  await p.close();
}
// The deployed site, its own Pages Function as the relay.
const site = process.env.SITE || "https://manabi-app-7di.pages.dev";
{
  const p = await browser.newPage();
  let bytes = 0, n = 0;
  p.on("requestfinished", async (r) => { if (r.url().includes("/turath-pdf/")) { n++; try { bytes += (await r.sizes()).responseBodySize; } catch {} } });
  try {
    await p.goto(`${site}/manifest.json`);
    const r = await p.evaluate(async ([file, page]) => {
      await import("/pdfjs/manabi_pdf.mjs");
      const t = performance.now();
      const [id, count] = await manabiPdf.open(`/turath-pdf/${file}`, null, null);
      const opened = performance.now() - t;
      await manabiPdf.render(id, page, 900);
      return { pages: count, openMs: Math.round(opened), pageMs: Math.round(performance.now() - t) };
    }, [file, page]);
    await p.waitForTimeout(300);
    console.log(`web pdf site: ${r.pages} pages, open ${r.openMs} ms, page ${page} drawn at ${r.pageMs} ms, ${n} requests, ${bytes >> 10} KB`);
  } catch (e) {
    console.log(`web pdf site: failed (${String(e.message).slice(0, 120)}), ${n} requests, ${bytes >> 10} KB so far`);
  }
  await p.close();
}
await browser.close();
server.close();
