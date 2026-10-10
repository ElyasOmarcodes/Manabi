// Offline Turath catalog bundled with the Nusus SDK.
import { findAuthors, findBooks, getCatalogMetadata, listCategories } from "nusus/turath";

// The raw tuples are not exported by the package, so load them next to the
// exported entry point (nusus/dist/turath/index.js).
const entry = import.meta.resolve("nusus/turath");
const deep = (file) => import(new URL(file, entry).href);

const { CATALOG_BOOKS, CATALOG_CATEGORIES, CATALOG_SCANNED_AT } = await deep("catalog-data.js");
const { CATALOG_AUTHORS } = await deep("catalog-authors.js");

const authorNames = new Map(CATALOG_AUTHORS.map(([id, name]) => [String(id), name]));
const books = new Map(CATALOG_BOOKS.map(([id, title, authorId, categoryId]) => [String(id), { title, authorId: String(authorId), categoryId: String(categoryId) }]));
const categories = new Map(CATALOG_CATEGORIES.map(([id, title]) => [String(id), title]));

export const catalog = {
  scannedAt: CATALOG_SCANNED_AT,
  raw: { books: CATALOG_BOOKS, authors: CATALOG_AUTHORS, categories: CATALOG_CATEGORIES },
  authorName: (id) => (id === undefined ? undefined : authorNames.get(String(id))),
  book: (id) => books.get(String(id)),
  categoryTitle: (id) => (id === undefined ? undefined : categories.get(String(id))),
  findBooks,
  findAuthors,
  listCategories,
  metadata: getCatalogMetadata,
};
