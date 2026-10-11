// Probes the raw page markup of commentary books (does Turath mark the
// matn?) for مرقاة المفاتيح and مراقي الفلاح.
const H = { origin: "https://app.turath.io", referer: "https://app.turath.io/" };
const get = async (p) => (await fetch(`https://api.turath.io/${p}`, { headers: H })).json();
for (const [id, key] of [[8176, "5,1803"], [412, "1,100"], [137, "1,50"]]) {
  const book = await get(`book?id=${id}&include=indexes&ver=3`);
  const map = book.indexes?.print_pg_to_pg ?? {};
  const pg = map[key] ?? Number(key.split(",")[1]);
  console.log("BOOK", id, book.meta?.name, "pg", pg);
  for (const p of [pg, pg + 1]) {
    const page = await get(`page?book_id=${id}&pg=${p}`);
    console.log("RAW", id, p, JSON.stringify(page.text).slice(0, 3500));
  }
}
