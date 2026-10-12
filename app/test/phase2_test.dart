import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/gemini/gemini_client.dart';
import 'package:manabi/state/search_history.dart';

void main() {
  group('search history', () {
    setUp(SearchHistory.reset);

    test('suggests the book\'s own searches first, ignoring diacritics', () {
      SearchHistory.add('الصلاة');
      SearchHistory.add('إنما الأعمال', bookId: '1');
      SearchHistory.add('الزكاة');
      final all = SearchHistory.suggest('', bookId: '1');
      expect(all.first, (text: 'إنما الأعمال', inBook: true));
      expect(all.map((s) => s.text), ['إنما الأعمال', 'الزكاة', 'الصلاة']);
      expect(SearchHistory.suggest('الأعمَال').map((s) => s.text), ['إنما الأعمال']);
      expect(SearchHistory.suggest('اعمال').map((s) => s.text), ['إنما الأعمال']);
    });

    test('a phrase typed in full is not offered again, and can be forgotten', () {
      SearchHistory.add('الصلاة');
      SearchHistory.add('صلاة الجمعة');
      expect(SearchHistory.suggest('الصلاة').map((s) => s.text), isEmpty);
      expect(SearchHistory.suggest('صلاة').map((s) => s.text), ['صلاة الجمعة', 'الصلاة']);
      SearchHistory.remove('صلاة الجمعة');
      expect(SearchHistory.suggest('صلاة').map((s) => s.text), ['الصلاة']);
    });
  });

  group('models', () {
    test('only text models, Gemini first, each with a cost class', () {
      final list = chatModels([
        {'name': 'models/gemma-3-27b-it', 'displayName': 'Gemma 3 27B', 'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/gemini-2.5-pro', 'inputTokenLimit': 1048576, 'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/gemini-2.5-flash-lite', 'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/text-embedding-004', 'supportedGenerationMethods': ['embedContent']},
        {'name': 'models/gemini-2.5-flash-preview-tts', 'supportedGenerationMethods': ['generateContent']},
        {'name': 'models/gemini-3-flash', 'supportedGenerationMethods': ['generateContent']},
      ]);
      expect([for (final m in list) (m.id, m.cost)], [
        ('gemini-3-flash', 'medium'),
        ('gemini-2.5-pro', 'high'),
        ('gemini-2.5-flash-lite', 'low'),
        ('gemma-3-27b-it', 'low'),
      ]);
      expect(list[1].input, 1048576);
      expect(isGemma('gemma-3-27b-it'), isTrue);
    });

    test('JSON is read from a reply wrapped in prose or fences', () {
      expect(parseJsonReply('{"a":1}'), {'a': 1});
      expect(parseJsonReply('Here:\n```json\n{"a":{"b":2}}\n```'), {
        'a': {'b': 2}
      });
    });
  });
}
