import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/gemini/gemini_client.dart';
import 'package:manabi/core/models/scope.dart';
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

  group('scopes', () {
    test('each book, and each author within each category, is one search', () {
      const s = SearchScope(books: [(id: '5', name: 'A'), (id: '6', name: 'B')], authors: [(id: '1', name: 'X'), (id: '2', name: 'Y')], categories: [(id: '30', name: 'C')]);
      expect(s.targets, [
        (bookId: '5', authorId: null, categoryId: null),
        (bookId: '6', authorId: null, categoryId: null),
        (bookId: null, authorId: '1', categoryId: '30'),
        (bookId: null, authorId: '2', categoryId: '30'),
      ]);
      expect(s.label(), 'A · B +3');
      expect(s.toRequest()['bookIds'], '5,6');
    });

    test('one book with its author is just the book; old saved scopes still load', () {
      final s = SearchScope.all.withBook('5', 'A').withAuthor('9', 'X');
      expect(s.targets, [(bookId: '5', authorId: null, categoryId: null)]);
      final old = SearchScope.fromJson({'bookId': '5', 'bookTitle': 'A'});
      expect(old.bookId, '5');
      expect(SearchScope.fromJson(s.toJson()), s);
      expect(SearchScope.all.targets.single, (bookId: null, authorId: null, categoryId: null));
    });
  });
}
