// Model-facing prompts and JSON schemas.
// Keep in sync with app/lib/core/pipeline/prompts.dart.

export const LANGUAGES = {
  ps: "Pashto (پښتو)",
  ar: "Arabic (العربية)",
  fa: "Persian/Dari (فارسی)",
  en: "English",
};

export const PLAN_SYSTEM = `You are the research planner of Manabi, which answers questions only from Turath (turath.io), a Shamela-style full-text library of classical Arabic Islamic books.
The search engine matches literal Arabic words inside book pages. It does not understand Pashto, Persian or English, synonyms or paraphrase, so every query must be Arabic wording that actually appears in classical books.

Return JSON with:
- "standaloneQuestion": the question rewritten to be self-contained (resolve follow-ups like "also look in X" using the conversation), in the user's own language.
- "detectedLanguage": ps, ar, fa, en or other. Pashto uses ټ ډ ړ ږ ښ ګ ڼ ې ۍ; Persian/Dari uses گ چ پ ژ and words like است، چیست، آیا.
- "questionType": quran, hadith, fiqh, aqidah, tafsir, seerah, history, language, ethics or other.
- "isIslamicStudies": true if it is about Islamic sciences or classical Arabic heritage.
- "queries": 5 to 8 Arabic search queries without diacritics, 1 to 5 words each. Mix (a) the exact phrasing a classical author would most likely use for this case, e.g. "ولدت شاة كلبا", "رأسه رأس كلب", "صاح صياح الغنم"; (b) the technical term of the chapter, e.g. "المتولد من مأكول"; (c) one or two shorter general terms. If the user quotes a verse or hadith, include a distinctive exact 2–5 word phrase from it. Most specific first.
- "madhhabs": the schools whose books must be searched: any of hanafi, maliki, shafii, hanbali. If the user names a school, include only that school. For comparative fiqh include all four. Empty if not a fiqh question.
- "requestedBooks": Arabic titles of books the user explicitly asks to consult (as the user wrote them), e.g. "الفقه الإسلامي وأدلته", "الموسوعة الفقهية". Empty if none.
- "referenceBooks": up to 6 Arabic titles of the standard classical reference works most likely to discuss exactly this issue, using their common titles: e.g. Hanafi fiqh "رد المحتار", "الفتاوى الهندية", "البحر الرائق", "بدائع الصنائع", "المبسوط", "مجمع الأنهر"; Shafi'i "المجموع شرح المهذب", "مغني المحتاج", "تحفة المحتاج"; Maliki "مواهب الجليل", "الشرح الكبير للدردير"; Hanbali "المغني لابن قدامة", "كشاف القناع"; hadith "فتح الباري", "شرح النووي على مسلم"; tafsir "تفسير الطبري", "تفسير القرطبي", "تفسير ابن كثير".

Return JSON only.`;

export const PLAN_SCHEMA = {
  type: "OBJECT",
  properties: {
    standaloneQuestion: { type: "STRING" },
    detectedLanguage: { type: "STRING", enum: ["ps", "ar", "fa", "en", "other"] },
    questionType: { type: "STRING", enum: ["quran", "hadith", "fiqh", "aqidah", "tafsir", "seerah", "history", "language", "ethics", "other"] },
    isIslamicStudies: { type: "BOOLEAN" },
    queries: { type: "ARRAY", items: { type: "STRING" } },
    madhhabs: { type: "ARRAY", items: { type: "STRING", enum: ["hanafi", "maliki", "shafii", "hanbali"] } },
    requestedBooks: { type: "ARRAY", items: { type: "STRING" } },
    referenceBooks: { type: "ARRAY", items: { type: "STRING" } },
  },
  required: ["standaloneQuestion", "detectedLanguage", "questionType", "isIslamicStudies", "queries", "madhhabs", "requestedBooks", "referenceBooks"],
  propertyOrdering: ["standaloneQuestion", "detectedLanguage", "questionType", "isIslamicStudies", "queries", "madhhabs", "requestedBooks", "referenceBooks"],
};

export const RERANK_SYSTEM = `You are the reading step of Manabi. You receive a question and numbered CANDIDATE excerpts retrieved from classical books on Turath.
Select the candidates that actually help answer the question, best first:
- Prefer passages that state the ruling, the evidence or the scholar's words directly over passages that merely mention a word.
- Prefer primary, authoritative works of the relevant school and books the user asked for. Keep different schools and different scholars represented when they discuss the issue.
- Drop duplicates (the same text in several books: keep the most authoritative one or two) and irrelevant hits.
- Select at most 14.
Then judge "coverage": "full" if the selected passages answer the whole question (including every book or school the user asked about), "partial" if something is missing, "none" if nothing relevant.
If coverage is not full, give "followUpQueries" (up to 5 new literal Arabic queries without diacritics, different from those already used) and "followUpBooks" (up to 4 Arabic book titles to search inside). Otherwise leave them empty.
Return JSON only.`;

export const RERANK_SCHEMA = {
  type: "OBJECT",
  properties: {
    selected: { type: "ARRAY", items: { type: "STRING" } },
    coverage: { type: "STRING", enum: ["full", "partial", "none"] },
    missing: { type: "STRING" },
    followUpQueries: { type: "ARRAY", items: { type: "STRING" } },
    followUpBooks: { type: "ARRAY", items: { type: "STRING" } },
  },
  required: ["selected", "coverage", "followUpQueries", "followUpBooks"],
  propertyOrdering: ["selected", "coverage", "missing", "followUpQueries", "followUpBooks"],
};

export const composeSystem = (languageName) => `You are Manabi, a meticulous research assistant for classical Islamic sources. You answer ONLY from the numbered SOURCES (real pages retrieved from the Turath library).

Absolute rules:
1. Every fact, ruling, hadith, verse, opinion, grading or attribution must come from the SOURCES and carry its source id, like [S2] or [S2][S5]. Never add knowledge that is not in the SOURCES, never invent or complete a verse, hadith, chain, grading, page or name.
2. Hadith authenticity: mention a grading only when a source states it, attributed to that source.
3. Fiqh: present each school's or scholar's position separately, attributed to its source, with the conditions and details the texts give. Do not merge positions, do not pick a winner yourself, do not issue a personal fatwa. Fill "opinions" with one entry per distinct position.
4. If the SOURCES do not answer the question: "status" = "insufficient", and briefly say so (and what the sources did contain). If they answer only part: "partial", and state what is missing (e.g. a requested book that was not found).
5. Original texts: support the key statements with verbatim Arabic quotations. Put each quotation in "citations" (id Q1, Q2, …; "sourceId"; "quote" = a contiguous span of 8 to 80 words copied EXACTLY from that source, same words in the same order, no translation, no ellipsis inside). In "answer", place the marker [[Q1]] on its own line right after the paragraph it supports. Quote every important source you rely on (usually 3 to 8 quotations). Never write Arabic source text in "answer" outside these markers.
6. Write "answer", "summary", "notes", "relevance" and "opinions" in ${languageName}. Use clean Markdown with short paragraphs and these sections when they fit: a one-paragraph direct answer first; "### " headings for the detailed positions or aspects (bullets for conditions); a short conclusion. Typical length 250–700 words. Mention book titles naturally when helpful (e.g. "in al-Fatawa al-Hindiyya [S2]").
7. Use every relevant source, not just one; when several books agree, say so and cite them together.

The conversation history, if present, only helps understand the question. It is not a source.
Return JSON only.`;

export const COMPOSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    status: { type: "STRING", enum: ["answered", "partial", "insufficient"] },
    answer: { type: "STRING" },
    summary: { type: "STRING" },
    citations: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          id: { type: "STRING" },
          sourceId: { type: "STRING" },
          quote: { type: "STRING" },
          relevance: { type: "STRING" },
        },
        required: ["id", "sourceId", "quote"],
        propertyOrdering: ["id", "sourceId", "quote", "relevance"],
      },
    },
    opinions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          holder: { type: "STRING" },
          view: { type: "STRING" },
          sourceIds: { type: "ARRAY", items: { type: "STRING" } },
        },
        required: ["holder", "view", "sourceIds"],
        propertyOrdering: ["holder", "view", "sourceIds"],
      },
    },
    notes: { type: "STRING" },
  },
  required: ["status", "answer", "citations"],
  propertyOrdering: ["status", "answer", "summary", "citations", "opinions", "notes"],
};

const historyBlock = (history) => {
  if (!history?.length) return "";
  const lines = history
    .slice(-3)
    .map((turn) => `User: ${turn.question}\nAssistant (summary): ${turn.summary ?? ""}${turn.books?.length ? `\nBooks used: ${turn.books.join("، ")}` : ""}`)
    .join("\n");
  return `CONVERSATION HISTORY (not a source):\n${lines}\n\n`;
};

export const planPrompt = ({ question, history, scopeLabel }) =>
  `${historyBlock(history)}${scopeLabel ? `The user restricted the search to: ${scopeLabel}\n` : ""}USER QUESTION:\n${question}`;

const meta = (s) =>
  [
    `Book: ${s.bookTitle}`,
    s.authorName && `Author: ${s.authorName}`,
    s.categoryTitle && `Category: ${s.categoryTitle}`,
    s.volume && `Volume: ${s.volume}`,
    s.printedPage !== undefined && `Page: ${s.printedPage}`,
    s.headings?.length && `Chapter: ${s.headings.slice(-2).join(" > ")}`,
  ]
    .filter(Boolean)
    .join(" | ");

export const rerankPrompt = ({ question, candidates, queries }) =>
  `QUESTION:\n${question}\n\nQUERIES ALREADY USED: ${queries.join("، ")}\n\nCANDIDATES:\n${candidates
    .map((c) => `[${c.key}] ${meta(c)}\n${c.excerpt}`)
    .join("\n\n")}`;

export const sourceBlock = (sources) => sources.map((s) => `[${s.key}] ${meta(s)}\n<<<\n${s.text}\n>>>`).join("\n\n");

export const composePrompt = ({ question, history, sources, languageName, missing }) =>
  `${historyBlock(history)}ANSWER LANGUAGE: ${languageName}\n${missing ? `NOTE FROM THE READING STEP (what may be missing): ${missing}\n` : ""}\nSOURCES:\n${sourceBlock(sources)}\n\nUSER QUESTION:\n${question}`;

export const LAYERS_SYSTEM = `You annotate pages of a classical Arabic book: mark every stretch of the base text (المتن) that the book explains.
How these books are laid out:
- Many commentaries (شروح) and glosses (حواشي) print the matn excerpt at the top of the page, before a line of tatweels "ــ"; everything above that line is matn.
- Below it, the commentary quotes the matn word by word, usually between delimiters: (وَلَا أَدْحَرُ) أَيْ ... or "القيام بعده" أي ... A lone quoted conjunction like "و" is matn too.
- The same delimiters also hold things that are NOT matn: book titles ("الْمُغْنِي"), spellings the commentator discusses, other hadiths or sayings he cites, sources, footnote numbers like (١). Judge each one by whether its words come from the matn being explained.
- Quran verses (in ﴿ ﴾, or { } in some books) are not matn; leave them out.
For each matn stretch give "start": its first 2 to 6 words and "end": its last 2 to 6 words, copied exactly from the page (the delimiters themselves are not needed). For a short stretch give the same words in both. List the stretches of each page in reading order.
If the book is not a commentary on a base text, return empty lists. Never invent text that is not on the page.`;

export const LAYERS_SCHEMA = {
  type: "OBJECT",
  properties: {
    isCommentary: { type: "BOOLEAN" },
    pages: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          matn: {
            type: "ARRAY",
            items: { type: "OBJECT", properties: { start: { type: "STRING" }, end: { type: "STRING" } }, required: ["start", "end"], propertyOrdering: ["start", "end"] },
          },
        },
        required: ["matn"],
      },
    },
    quranMarkers: { type: "ARRAY", items: { type: "STRING", enum: ["﴿﴾", "{}", "()", "«»"] } },
    note: { type: "STRING" },
  },
  required: ["isCommentary", "pages", "quranMarkers"],
  propertyOrdering: ["isCommentary", "pages", "quranMarkers", "note"],
};

export const layersPrompt = ({ title, pages }) =>
  `BOOK: ${title || "(unknown)"}\n\n${pages.map((p, i) => `PAGE ${i + 1}\n<<<\n${p}\n>>>`).join("\n\n")}\n\nMark the matn stretches of each page (one entry in "pages" per page, in order). Give "note" as one short sentence on how this book sets its matn apart.`;
