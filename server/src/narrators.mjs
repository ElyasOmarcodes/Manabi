// Turath's narrator index (api.turath.io/narrators, /narrator): search and
// one narrator's biography. Small in-memory cache, short time limit.

const API = "https://api.turath.io";

export const createNarrators = ({ fetch: fetcher = fetch, timeoutMs = 15_000 } = {}) => {
  const cache = new Map();
  const get = async (path, params) => {
    const url = `${API}/${path}?${new URLSearchParams(params)}`;
    const hit = cache.get(url);
    if (hit && hit.until > Date.now()) return hit.value;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetcher(url, { headers: { accept: "application/json" }, signal: controller.signal });
      if (!res.ok) throw Object.assign(new Error(`Turath HTTP ${res.status}`), { code: res.status === 404 ? "NOT_FOUND" : "TURATH_UNAVAILABLE" });
      const value = await res.json();
      cache.set(url, { value, until: Date.now() + 60 * 60_000 });
      if (cache.size > 500) cache.delete(cache.keys().next().value);
      return value;
    } catch (error) {
      if (error.code) throw error;
      throw Object.assign(new Error("Turath could not be reached"), { code: "TURATH_UNAVAILABLE" });
    } finally {
      clearTimeout(timer);
    }
  };
  return {
    search: (q, page = 1) => get("narrators", { page: String(page), limit: "50", ...(q ? { q } : {}) }),
    get: async (id) => {
      const value = await get("narrator", { id: String(id) });
      if (!value || typeof value !== "object" || !value.id) throw Object.assign(new Error(`Narrator ${id} not found`), { code: "NOT_FOUND" });
      return value;
    },
  };
};
