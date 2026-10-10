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
}
