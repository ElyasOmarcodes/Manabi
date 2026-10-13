import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/backend/backend.dart';
import 'package:manabi/core/models/library.dart';
import 'package:manabi/state/downloads.dart';

/// Answers book details after [failures] passing failures.
class _Books implements ManabiBackend {
  _Books({this.failures = 0, this.code = 'NETWORK'});
  int failures;
  final String code;
  int calls = 0;

  @override
  Future<BookDetails> book(String id) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (failures-- > 0) throw BackendException(code);
    return BookDetails(id: id, title: 'كتاب', pageMap: const ['1,1', '1,2']);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('book details asked twice at once share one request, and complete', () async {
    final inner = _Books();
    final b = OfflineFirstBackend(inner);
    final both = await Future.wait([b.book('7'), b.book('7')]).timeout(const Duration(seconds: 5));
    expect(both.map((d) => d.pageCount), [2, 2]);
    expect(inner.calls, 1);
    // Later asks go to the network again.
    await b.book('7').timeout(const Duration(seconds: 5));
    expect(inner.calls, 2);
  });

  test('a passing failure is tried again; a missing book is not', () async {
    final flaky = _Books(failures: 1);
    expect((await OfflineFirstBackend(flaky).book('7').timeout(const Duration(seconds: 5))).pageCount, 2);
    expect(flaky.calls, 2);
    final missing = _Books(failures: 9, code: 'NOT_FOUND');
    await expectLater(OfflineFirstBackend(missing).book('7'), throwsA(isA<BackendException>()));
    expect(missing.calls, 1);
  });
}
