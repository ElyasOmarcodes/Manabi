import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/models/library.dart';
import 'package:manabi/state/reading_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('page map converts between internal and printed pages', () {
    final book = BookDetails.fromJson({
      'id': '1',
      'title': 'كتاب',
      'volumes': ['1', '2'],
      'pageMap': ['1,1', '1,2', '1,3', '2,1', '2,2'],
      'volumeBounds': {
        '1': [1, 3],
        '2': [4, 5]
      },
      'toc': [
        {'title': 'باب الطهارة', 'level': 1, 'page': 1},
        {'title': 'باب الصلاة', 'level': 1, 'page': 4},
      ],
    });
    expect(book.pageCount, 5);
    expect(book.locate(4), (volume: '2', printed: 1));
    expect(book.internalFor('2', 2), 5);
    expect(book.internalFor('1', 3), 3);
    expect(book.headingFor(5)?.title, 'باب الصلاة');
    expect(book.headingFor(2)?.title, 'باب الطهارة');
  });

  test('bookmarks and reading positions are remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final r = ReadingController();
    await r.load();
    await r.toggleBookmark(Bookmark(bookId: '7', bookTitle: 'ب', page: 12, savedAt: DateTime(2026)));
    await r.savePosition('7', 'ب', 12);
    final again = ReadingController();
    await again.load();
    expect(again.isBookmarked('7', 12), isTrue);
    expect(again.positionOf('7')?.page, 12);
    await again.toggleBookmark(again.bookmarks.single);
    expect(again.bookmarks, isEmpty);
  });

  test('heading path walks up the table of contents', () {
    final book = BookDetails.fromJson({
      'id': '1',
      'title': 'صحيح',
      'toc': [
        {'title': 'بدء الوحي', 'level': 1, 'page': 1},
        {'title': 'كتاب الإيمان', 'level': 1, 'page': 3},
        {'title': 'باب أمور الإيمان', 'level': 2, 'page': 4},
        {'title': 'فصل', 'level': 3, 'page': 5},
      ],
    });
    expect(book.headingPath(5).map((e) => e.title), ['كتاب الإيمان', 'باب أمور الإيمان', 'فصل']);
    expect(book.headingPath(4).map((e) => e.title), ['كتاب الإيمان', 'باب أمور الإيمان']);
    expect(book.headingPath(2).map((e) => e.title), ['بدء الوحي']);
  });

  test('favourites, highlights, visited pages and reader settings persist', () async {
    SharedPreferences.setMockInitialValues({});
    final r = ReadingController();
    await r.load();
    await r.toggleFavorite('9', 'الموطأ');
    await r.addHighlight(Highlight(bookId: '9', bookTitle: 'الموطأ', page: 3, text: 'إنما الأعمال بالنيات', color: 2, savedAt: DateTime(2026)));
    await r.savePosition('9', 'الموطأ', 3);
    await r.savePosition('9', 'الموطأ', 4);
    await r.setReadingMode('pages');
    await r.setHideDiacritics(true);
    await r.setDigits('latin');
    final again = ReadingController();
    await again.load();
    expect(again.isFavorite('9'), isTrue);
    expect(again.highlightsOf('9', 3).single.color, 2);
    expect(again.visitedOf('9'), [4, 3]);
    expect((again.readingMode, again.hideDiacritics, again.digits), ('pages', true, 'latin'));
    await again.clearHistory();
    expect(again.positionOf('9'), isNull);
    expect(again.isFavorite('9'), isTrue, reason: 'clearing history keeps favourites');
    await again.clearAll();
    expect([...again.favorites, ...again.highlights, ...again.bookmarks], isEmpty);
    await again.resetDisplay();
    expect(again.readingMode, 'scroll');
  });

  test('reader text helpers', () {
    expect(stripDiacritics('إِنَّمَا الْأَعْمَالُ'), 'إنما الأعمال');
    expect(readerDigits(120, 'arabic'), '١٢٠');
    expect(readerDigits('3', 'latin'), '3');
  });
}
