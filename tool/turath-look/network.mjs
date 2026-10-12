// Does Turath's PDF server answer byte-range requests (so the app can read
// one page of a scanned volume without downloading the whole file), and
// may a browser on another origin make them (CORS)?
const url = "https://files.turath.io/pdf/shamela/roohm_04.pdf";
const show = (label, res) =>
  console.log(
    label,
    res.status,
    JSON.stringify(Object.fromEntries(["accept-ranges", "content-range", "content-length", "content-type", "cache-control", "etag", "last-modified", "access-control-allow-origin", "access-control-expose-headers", "access-control-allow-headers"].map((h) => [h, res.headers.get(h)]))),
  );
for (const origin of ["https://app.turath.io", "http://localhost:8080"]) {
  show(`HEAD ${origin}`, await fetch(url, { method: "HEAD", headers: { origin } }));
  const r = await fetch(url, { headers: { origin, range: "bytes=0-65535" } });
  const body = await r.arrayBuffer();
  show(`RANGE ${origin} got=${body.byteLength}`, r);
  show(`PREFLIGHT ${origin}`, await fetch(url, { method: "OPTIONS", headers: { origin, "access-control-request-method": "GET", "access-control-request-headers": "range" } }));
}
// A tail range (PDF cross-reference tables sit at the end).
const tail = await fetch(url, { headers: { range: "bytes=-65536" } });
show(`TAIL got=${(await tail.arrayBuffer()).byteLength}`, tail);
// How long one metadata request takes (to size a polite PDF-flag crawl).
const t = Date.now();
for (const id of [22835, 1681, 8176, 147927, 9769]) await fetch(`https://api.turath.io/book?id=${id}&ver=3`);
console.log("META5_MS", Date.now() - t);
