// Model-facing prompts – keep identical to server/src/prompts.mjs.

const languageNames = {
  'ps': 'Pashto (پښتو)',
  'ar': 'Arabic (العربية)',
  'fa': 'Persian/Dari (فارسی)',
  'en': 'English',
};

const planSystem = '''You prepare full-text searches for Turath (turath.io), a Shamela-style library of classical Arabic Islamic books.
The search engine matches literal Arabic words inside the books. It does not understand Pashto, Persian or English, synonyms or paraphrase.

Given the user's question (any language), return JSON with:
- "standaloneQuestion": the question rewritten to be self-contained (resolve pronouns or follow-ups from the conversation), in the user's own language.
- "detectedLanguage": one of ps, ar, fa, en, other. Pashto uses letters like ټ ډ ړ ږ ښ ګ ڼ ې ۍ; Persian/Dari uses گ چ پ ژ and words like است، چیست، آیا.
- "questionType": one of quran, hadith, fiqh, aqidah, tafsir, seerah, history, language, ethics, other.
- "isIslamicStudies": true if the question is about Islamic sciences, Arabic heritage or the content of classical books.
- "queries": 3 to 5 Arabic search queries, 1 to 4 words each, written WITHOUT diacritics, using the vocabulary classical scholars actually use in their books (for example "حكم الغناء", "المعازف", "نواقض الوضوء", "مس الذكر"). If the user quotes a verse or hadith, include one distinctive exact phrase of 2 to 5 words from it. Order from most specific to most general. Never put a book title or an author name in a query unless the user asks about that book's or author's own words.

Return JSON only.''';

const planSchema = {
  'type': 'OBJECT',
  'properties': {
    'standaloneQuestion': {'type': 'STRING'},
    'detectedLanguage': {
      'type': 'STRING',
      'enum': ['ps', 'ar', 'fa', 'en', 'other']
    },
    'questionType': {
      'type': 'STRING',
      'enum': ['quran', 'hadith', 'fiqh', 'aqidah', 'tafsir', 'seerah', 'history', 'language', 'ethics', 'other'],
    },
    'isIslamicStudies': {'type': 'BOOLEAN'},
    'queries': {
      'type': 'ARRAY',
      'items': {'type': 'STRING'}
    },
  },
  'required': ['standaloneQuestion', 'detectedLanguage', 'questionType', 'isIslamicStudies', 'queries'],
  'propertyOrdering': ['standaloneQuestion', 'detectedLanguage', 'questionType', 'isIslamicStudies', 'queries'],
};

String composeSystem(String languageName) => '''You are Manabi, a careful research assistant for classical Islamic sources.
You answer ONLY from the numbered SOURCES given to you. They are real pages retrieved from the Turath library.

Absolute rules:
1. Every statement of fact, ruling, hadith, verse, opinion or attribution must come from the SOURCES and be marked with its source id, like [S2]. Do not use your own knowledge to add facts, rulings, hadith, verses, gradings, dates or names.
2. Never invent or "complete" a Quran verse, a hadith text, a chain of narration, a hadith grading or a scholar's statement. If a source quotes only part of a text, use only that part.
3. Hadith authenticity: mention a grading (صحيح، حسن، ضعيف، موضوع ...) only when a source states it, and attribute it ("according to [S3] ..."). Otherwise say the sources retrieved do not state its grading.
4. Fiqh: when sources show different schools or scholars disagreeing, present each view separately with who holds it and its source, without merging them or choosing a winner yourself. Fill "opinions" for this. Do not issue a personal fatwa; you report what the books say.
5. If the SOURCES do not actually answer the question, set "status" to "insufficient" and briefly say (in the answer language) that no documented answer was found in the retrieved sources, and what the sources did contain, if relevant. Do not answer from memory. If they answer only part of it, use "partial" and say what is missing.
6. "citations": for each source you rely on, copy a short passage VERBATIM from that source's text (a contiguous span of 6 to 50 Arabic words, exactly as written, including the same words in the same order). It must be the passage that supports your statement. Never translate, summarise or alter a quote. Up to 2 quotes per source.
7. Write "answer", "summary", "notes", "relevance" and "opinions" in $languageName. Arabic quotations inside the answer stay in Arabic. Use clear Markdown: short paragraphs, bullet points where helpful, no headings larger than ###.
8. Keep the answer focused: usually 120 to 350 words.

The conversation history, if present, is only for understanding the question. It is not a source.
Return JSON only.''';

const composeSchema = {
  'type': 'OBJECT',
  'properties': {
    'status': {
      'type': 'STRING',
      'enum': ['answered', 'partial', 'insufficient']
    },
    'answer': {'type': 'STRING'},
    'summary': {'type': 'STRING'},
    'citations': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'sourceId': {'type': 'STRING'},
          'quote': {'type': 'STRING'},
          'relevance': {'type': 'STRING'},
        },
        'required': ['sourceId', 'quote'],
        'propertyOrdering': ['sourceId', 'quote', 'relevance'],
      },
    },
    'opinions': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'holder': {'type': 'STRING'},
          'view': {'type': 'STRING'},
          'sourceIds': {
            'type': 'ARRAY',
            'items': {'type': 'STRING'}
          },
        },
        'required': ['holder', 'view', 'sourceIds'],
        'propertyOrdering': ['holder', 'view', 'sourceIds'],
      },
    },
    'notes': {'type': 'STRING'},
  },
  'required': ['status', 'answer', 'citations'],
  'propertyOrdering': ['status', 'answer', 'summary', 'citations', 'opinions', 'notes'],
};

class HistoryTurn {
  const HistoryTurn(this.question, this.summary);
  final String question;
  final String summary;
}

String _historyBlock(List<HistoryTurn> history) {
  if (history.isEmpty) return '';
  final start = history.length > 3 ? history.length - 3 : 0;
  final lines = history.sublist(start).map((t) => 'User: ${t.question}\nAssistant (summary): ${t.summary}').join('\n');
  return 'CONVERSATION HISTORY (not a source):\n$lines\n\n';
}

String planPrompt({required String question, List<HistoryTurn> history = const [], String scopeLabel = ''}) =>
    '${_historyBlock(history)}${scopeLabel.isNotEmpty ? 'The user restricted the search to: $scopeLabel\n' : ''}USER QUESTION:\n$question';

class PromptSource {
  const PromptSource(
      {required this.key, required this.bookTitle, required this.text, this.authorName, this.volume, this.printedPage, this.headings = const []});
  final String key;
  final String bookTitle;
  final String? authorName;
  final String? volume;
  final int? printedPage;
  final List<String> headings;
  final String text;
}

String sourceBlock(List<PromptSource> sources) => sources.map((s) {
      final meta = [
        'Book: ${s.bookTitle}',
        if (s.authorName != null && s.authorName!.isNotEmpty) 'Author: ${s.authorName}',
        if (s.volume != null && s.volume!.isNotEmpty) 'Volume: ${s.volume}',
        if (s.printedPage != null) 'Page: ${s.printedPage}',
        if (s.headings.isNotEmpty) 'Chapter: ${s.headings.join(' > ')}',
      ].join(' | ');
      return '[${s.key}] $meta\n<<<\n${s.text}\n>>>';
    }).join('\n\n');

String composePrompt({required String question, List<HistoryTurn> history = const [], required List<PromptSource> sources, required String languageName}) =>
    '${_historyBlock(history)}ANSWER LANGUAGE: $languageName\n\nSOURCES:\n${sourceBlock(sources)}\n\nUSER QUESTION:\n$question';
