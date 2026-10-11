// Turath books outside the bundled catalog snapshot, collected from the
// official API responses the server already gets (search hits, pages, book
// metadata). Turath publishes no catalog listing, so the library grows from
// what readers actually reach. Kept in memory, and in a JSON file when
// MANABI_DATA_DIR is set.
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

export const createDiscovered = ({ catalog, dataDir, max = 50_000 } = {}) => {
  const books = new Map();
  const file = dataDir ? join(dataDir, "discovered-books.json") : undefined;
  let dirty = false;
  let timer;

  const save = () => {
    if (!file || !dirty) return;
    dirty = false;
    const rows = [...books.entries()].map(([id, b]) => [id, b.title, b.authorId ?? "", b.categoryId ?? "", b.authorName ?? null]);
    mkdir(dataDir, { recursive: true })
      .then(() => writeFile(file, JSON.stringify(rows)))
      .catch(() => {});
  };

  const note = ({ id, title, authorId, authorName, categoryId }) => {
    id = id === undefined || id === null ? "" : String(id);
    title = typeof title === "string" ? title.trim() : "";
    if (!/^\d+$/.test(id) || !title || catalog?.book(id) || books.size >= max) return;
    const old = books.get(id);
    const next = {
      title,
      authorId: authorId ? String(authorId) : old?.authorId,
      authorName: authorName || old?.authorName || catalog?.authorName(authorId),
      categoryId: categoryId ? String(categoryId) : old?.categoryId,
    };
    if (old && old.title === next.title && old.authorId === next.authorId && old.authorName === next.authorName && old.categoryId === next.categoryId) return;
    books.set(id, next);
    dirty = true;
    if (file && !timer) {
      timer = setTimeout(() => {
        timer = undefined;
        save();
      }, 5_000);
      timer.unref?.();
    }
  };

  const fromItem = (item) => note({ id: item?.book?.id, title: item?.book?.title, authorId: item?.author?.id, authorName: item?.author?.name, categoryId: item?.category?.id });

  const seen = (r) => {
    if (!r || typeof r !== "object") return;
    if (Array.isArray(r)) return r.forEach(seen);
    if (Array.isArray(r.items)) r.items.forEach(seen);
    if (Array.isArray(r.pages)) r.pages.forEach(seen);
    if (r.book?.id) fromItem(r);
  };

  /** Wraps a Turath client so every book it returns is noted. */
  const watch = (client) => {
    const wrapped = { ...client };
    for (const name of ["search", "searchAll", "getPage", "getPages", "retrieve", "getContext", "getContextByPage"]) {
      if (typeof client[name] !== "function") continue;
      wrapped[name] = async (...args) => {
        const r = await client[name](...args);
        try {
          seen(r);
        } catch {
          // Noting is best effort.
        }
        return r;
      };
    }
    if (typeof client.getBook === "function") {
      wrapped.getBook = async (...args) => {
        const b = await client.getBook(...args);
        note({ id: b?.id, title: b?.title, authorId: b?.author?.id, authorName: b?.author?.name, categoryId: b?.category?.id });
        return b;
      };
    }
    return wrapped;
  };

  const load = async () => {
    if (!file) return;
    try {
      for (const [id, title, authorId, categoryId, authorName] of JSON.parse(await readFile(file, "utf8"))) {
        books.set(String(id), { title, authorId: authorId || undefined, categoryId: categoryId || undefined, authorName: authorName ?? undefined });
      }
    } catch {
      // No file yet.
    }
  };

  return {
    note,
    watch,
    load,
    save,
    get size() {
      return books.size;
    },
    list: () => ({ count: books.size, books: [...books.entries()].map(([id, b]) => [id, b.title, b.authorId ?? "", b.categoryId ?? "", b.authorName ?? null]) }),
  };
};
