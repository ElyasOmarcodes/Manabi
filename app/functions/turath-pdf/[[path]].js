// Cloudflare Pages Function: /turath-pdf/<path>.pdf → https://files.turath.io/pdf/<path>.pdf
// files.turath.io answers byte ranges but does not let a page on another site
// read Accept-Ranges or Content-Range, so a browser's PDF reader there falls
// back to downloading the whole volume. Through the site itself it reads
// only the pages shown.
export async function onRequest({ request, params }) {
  if (request.method !== "GET" && request.method !== "HEAD") return new Response("Method not allowed", { status: 405 });
  const path = [].concat(params.path ?? []).join("/");
  if (!/^[\w./-]+\.pdf$/i.test(path) || path.includes("..")) return new Response("Not found", { status: 404 });
  const range = request.headers.get("range");
  const res = await fetch(`https://files.turath.io/pdf/${path}`, {
    method: request.method,
    headers: { ...(range ? { range } : {}), "user-agent": "Manabi web (PDF relay)" },
  });
  const headers = new Headers({ "content-type": "application/pdf", "accept-ranges": "bytes", "cache-control": "public, max-age=86400" });
  for (const h of ["content-length", "content-range", "etag", "last-modified"]) {
    const v = res.headers.get(h);
    if (v) headers.set(h, v);
  }
  return new Response(res.body, { status: res.status, headers });
}
