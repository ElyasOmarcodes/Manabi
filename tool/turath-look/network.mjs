// Probes Turath's public narrator endpoints (search and one narrator) and
// the page-range endpoint used to save a book.
const probes = [
  "narrators?page=1&limit=3&q=%D8%A3%D8%A8%D8%A7%D9%86",
  "narrators?page=1&limit=3&search=%D8%A3%D8%A8%D8%A7%D9%86",
  "narrators?page=1&limit=3&query=%D8%A3%D8%A8%D8%A7%D9%86",
  "narrators?page=1&limit=3&name=%D8%A3%D8%A8%D8%A7%D9%86",
  "narrator?id=4210",
  "narrators?id=4210",
  "narrators/4210",
  "man?id=4210",
  "page?book_id=147927&pg=1&end_pg=40",
];
for (const p of probes) {
  try {
    const r = await fetch(`https://api.turath.io/${p}`, { headers: { origin: "https://app.turath.io", referer: "https://app.turath.io/" } });
    const t = await r.text();
    console.log("PROBE", r.status, p, t.length, t.slice(0, 500).replace(/\s+/g, " "));
  } catch (e) {
    console.log("PROBE ERR", p, e.message);
  }
}
const pdf = await fetch("https://files.turath.io/pdf//bksultanya/01_54495.pdf", { method: "HEAD", headers: { origin: "https://example.com" } }).catch((e) => e);
console.log("PDF", pdf.status, JSON.stringify(Object.fromEntries(pdf.headers ?? [])));
