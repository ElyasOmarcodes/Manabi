// Prompt builders and JSON schemas – keep identical to server/src/prompts.mjs.
// The system prompt texts are generated into prompt_texts.dart.
export 'prompt_texts.dart';

const languageNames = {
  'ps': 'Pashto (پښتو)',
  'ar': 'Arabic (العربية)',
  'fa': 'Persian/Dari (فارسی)',
  'en': 'English',
};

const _str = {'type': 'STRING'};
const _strList = {'type': 'ARRAY', 'items': _str};

const planSchema = {
  'type': 'OBJECT',
  'properties': {
    'standaloneQuestion': _str,
    'detectedLanguage': {
      'type': 'STRING',
      'enum': ['ps', 'ar', 'fa', 'en', 'other']
    },
    'questionType': {
      'type': 'STRING',
      'enum': ['quran', 'hadith', 'fiqh', 'aqidah', 'tafsir', 'seerah', 'history', 'language', 'ethics', 'other'],
    },
    'isIslamicStudies': {'type': 'BOOLEAN'},
    'queries': _strList,
    'madhhabs': {
      'type': 'ARRAY',
      'items': {
        'type': 'STRING',
        'enum': ['hanafi', 'maliki', 'shafii', 'hanbali']
      }
    },
    'requestedBooks': _strList,
    'referenceBooks': _strList,
  },
  'required': ['standaloneQuestion', 'detectedLanguage', 'questionType', 'isIslamicStudies', 'queries', 'madhhabs', 'requestedBooks', 'referenceBooks'],
  'propertyOrdering': ['standaloneQuestion', 'detectedLanguage', 'questionType', 'isIslamicStudies', 'queries', 'madhhabs', 'requestedBooks', 'referenceBooks'],
};

const rerankSchema = {
  'type': 'OBJECT',
  'properties': {
    'selected': _strList,
    'coverage': {
      'type': 'STRING',
      'enum': ['full', 'partial', 'none']
    },
    'missing': _str,
    'followUpQueries': _strList,
    'followUpBooks': _strList,
  },
  'required': ['selected', 'coverage', 'followUpQueries', 'followUpBooks'],
  'propertyOrdering': ['selected', 'coverage', 'missing', 'followUpQueries', 'followUpBooks'],
};

const composeSchema = {
  'type': 'OBJECT',
  'properties': {
    'status': {
      'type': 'STRING',
      'enum': ['answered', 'partial', 'insufficient']
    },
    'answer': _str,
    'summary': _str,
    'citations': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {'id': _str, 'sourceId': _str, 'quote': _str, 'relevance': _str},
        'required': ['id', 'sourceId', 'quote'],
        'propertyOrdering': ['id', 'sourceId', 'quote', 'relevance'],
      },
    },
    'opinions': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {'holder': _str, 'view': _str, 'sourceIds': _strList},
        'required': ['holder', 'view', 'sourceIds'],
        'propertyOrdering': ['holder', 'view', 'sourceIds'],
      },
    },
    'notes': _str,
  },
  'required': ['status', 'answer', 'citations'],
  'propertyOrdering': ['status', 'answer', 'summary', 'citations', 'opinions', 'notes'],
};

class HistoryTurn {
  const HistoryTurn(this.question, this.summary, [this.books = const []]);
  final String question;
  final String summary;
  final List<String> books;
}

String _historyBlock(List<HistoryTurn> history) {
  if (history.isEmpty) return '';
  final start = history.length > 3 ? history.length - 3 : 0;
  final lines = history
      .sublist(start)
      .map((t) => 'User: ${t.question}\nAssistant (summary): ${t.summary}${t.books.isNotEmpty ? '\nBooks used: ${t.books.join('، ')}' : ''}')
      .join('\n');
  return 'CONVERSATION HISTORY (not a source):\n$lines\n\n';
}

String planPrompt({required String question, List<HistoryTurn> history = const [], String scopeLabel = ''}) =>
    '${_historyBlock(history)}${scopeLabel.isNotEmpty ? 'The user restricted the search to: $scopeLabel\n' : ''}USER QUESTION:\n$question';

/// A page as shown to the model.
class PromptSource {
  const PromptSource({
    required this.key,
    required this.bookTitle,
    required this.text,
    this.authorName,
    this.categoryTitle,
    this.volume,
    this.printedPage,
    this.headings = const [],
  });
  final String key;
  final String bookTitle;
  final String? authorName;
  final String? categoryTitle;
  final String? volume;
  final int? printedPage;
  final List<String> headings;
  final String text;
}

String _meta(PromptSource s) => [
      'Book: ${s.bookTitle}',
      if (s.authorName != null && s.authorName!.isNotEmpty) 'Author: ${s.authorName}',
      if (s.categoryTitle != null && s.categoryTitle!.isNotEmpty) 'Category: ${s.categoryTitle}',
      if (s.volume != null && s.volume!.isNotEmpty) 'Volume: ${s.volume}',
      if (s.printedPage != null) 'Page: ${s.printedPage}',
      if (s.headings.isNotEmpty) 'Chapter: ${s.headings.skip(s.headings.length > 2 ? s.headings.length - 2 : 0).join(' > ')}',
    ].join(' | ');

String rerankPrompt({required String question, required List<PromptSource> candidates, required List<String> queries}) =>
    'QUESTION:\n$question\n\nQUERIES ALREADY USED: ${queries.join('، ')}\n\nCANDIDATES:\n${candidates.map((c) => '[${c.key}] ${_meta(c)}\n${c.text}').join('\n\n')}';

String sourceBlock(List<PromptSource> sources) => sources.map((s) => '[${s.key}] ${_meta(s)}\n<<<\n${s.text}\n>>>').join('\n\n');

String composePrompt({
  required String question,
  List<HistoryTurn> history = const [],
  required List<PromptSource> sources,
  required String languageName,
  String missing = '',
}) =>
    '${_historyBlock(history)}ANSWER LANGUAGE: $languageName\n${missing.isNotEmpty ? 'NOTE FROM THE READING STEP (what may be missing): $missing\n' : ''}\nSOURCES:\n${sourceBlock(sources)}\n\nUSER QUESTION:\n$question';

/// Mirrors LAYERS_SCHEMA in server/src/prompts.mjs.
const layersSchema = {
  'type': 'OBJECT',
  'properties': {
    'isCommentary': {'type': 'BOOLEAN'},
    'pages': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'matn': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'start': {'type': 'STRING'},
                'end': {'type': 'STRING'},
              },
              'required': ['start', 'end'],
              'propertyOrdering': ['start', 'end'],
            }
          },
        },
        'required': ['matn'],
      }
    },
    'quranMarkers': {
      'type': 'ARRAY',
      'items': {
        'type': 'STRING',
        'enum': ['﴿﴾', '{}', '()', '«»']
      }
    },
    'note': {'type': 'STRING'},
  },
  'required': ['isCommentary', 'pages', 'quranMarkers'],
  'propertyOrdering': ['isCommentary', 'pages', 'quranMarkers', 'note'],
};

/// Mirrors layersPrompt in server/src/prompts.mjs.
String layersPrompt({required String title, required List<String> pages}) =>
    'BOOK: ${title.isEmpty ? '(unknown)' : title}\n\n${[for (var i = 0; i < pages.length; i++) 'PAGE ${i + 1}\n<<<\n${pages[i]}\n>>>'].join('\n\n')}\n\n'
    'Mark the matn stretches of each page (one entry in "pages" per page, in order). Give "note" as one short sentence on how this book sets its matn apart.';
