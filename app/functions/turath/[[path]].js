// Cloudflare Pages Function: /turath/<endpoint>?... → https://api.turath.io/<endpoint>?...
// A browser cannot call api.turath.io (it sends no CORS headers), so the web
// app reads the library through its own site. Only reads, only Turath's API.
const ENDPOINTS = new Set(["book", "page", "author", "search", "narrators", "narrator"]);

export async function onRequest({ request, params }) {
  if (request.method !== "GET") return new Response("Method not allowed", { status: 405 });
  const path = [].concat(params.path ?? []).join("/");
  if (!ENDPOINTS.has(path)) return new Response("Not found", { status: 404 });
  const url = new URL(request.url);
  const res = await fetch(`https://api.turath.io/${path}${url.search}`, {
    headers: { accept: "application/json", "user-agent": "Manabi web (library relay)" },
    // Books and pages rarely change; searches stay fresh.
    cf: path === "search" ? undefined : { cacheTtl: 86400, cacheEverything: true },
  });
  const headers = new Headers({
    "content-type": res.headers.get("content-type") ?? "application/json",
    "cache-control": path === "search" ? "no-store" : "public, max-age=3600",
  });
  const retry = res.headers.get("retry-after");
  if (retry) headers.set("retry-after", retry);
  return new Response(res.body, { status: res.status, headers });
}
