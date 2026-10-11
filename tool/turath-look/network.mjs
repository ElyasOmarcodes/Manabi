// Probes how Turath maps a text page to a PDF page: the book index of a
// sample book, and the app code around "pdf_page".
const H = { origin: "https://app.turath.io", referer: "https://app.turath.io/" };
const book = await (await fetch("https://api.turath.io/book?id=1681&include=indexes&ver=3", { headers: H })).json();
const idx = book.indexes ?? {};
console.log("KEYS", Object.keys(book), Object.keys(idx));
console.log("META", JSON.stringify(book.meta).slice(0, 1500));
console.log("PAGEMAP", JSON.stringify((idx.page_map ?? []).slice(0, 30)));
for (const k of Object.keys(idx)) if (k !== "page_map" && k !== "headings") console.log("IDX", k, JSON.stringify(idx[k]).slice(0, 800));
const page = await (await fetch("https://api.turath.io/page?book_id=1681&pg=18", { headers: H })).json();
console.log("PAGE18", JSON.stringify(page.meta ?? page).slice(0, 800));
const html = await (await fetch("https://app.turath.io/")).text();
const scripts = [...html.matchAll(/src="([^"]+\.js)"/g)].map((m) => new URL(m[1], "https://app.turath.io/").href);
console.log("SCRIPTS", scripts);
const seen = new Set();
const queue = [...scripts];
while (queue.length && seen.size < 60) {
  const url = queue.shift();
  if (seen.has(url)) continue;
  seen.add(url);
  const js = await (await fetch(url)).text().catch(() => "");
  for (const m of js.matchAll(/["'](\.?\.?\/?[\w./-]*?(?:assets|_next|static|chunks)[\w./-]*\.js)["']/g)) {
    try { queue.push(new URL(m[1], url).href); } catch {}
  }
  for (const word of ["pdf_page", "pdfPage", "pdf_volume", "page_offset", "pdf_offset"]) {
    let i = js.indexOf(word);
    let n = 0;
    while (i >= 0 && n < 6) {
      console.log("CODE", word, url.split("/").pop(), js.slice(Math.max(0, i - 500), i + 500).replace(/\s+/g, " "));
      i = js.indexOf(word, i + word.length);
      n++;
    }
  }
}
