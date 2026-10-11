/// Turath page text arrives with HTML entities (`&quot;` `&amp;` `&#8230;` …);
/// they are decoded once so the reader, quotes and citations show real text.
library;

const _named = {
  'quot': '"', 'amp': '&', 'lt': '<', 'gt': '>', 'apos': "'", 'nbsp': ' ', 'laquo': '«', 'raquo': '»', 'hellip': '…', //
  'ndash': '–', 'mdash': '—', 'zwnj': '\u200c', 'zwj': '\u200d', 'lrm': '\u200e', 'rlm': '\u200f',
};
final _entity = RegExp(r'&(#x[0-9a-f]+|#\d+|[a-z]+);', caseSensitive: false);

String decodeHtmlEntities(String value) {
  if (!value.contains('&')) return value;
  return value.replaceAllMapped(_entity, (m) {
    final code = m[1]!;
    if (code.startsWith('#')) {
      final hex = code.length > 1 && (code[1] == 'x' || code[1] == 'X');
      final n = int.tryParse(hex ? code.substring(2) : code.substring(1), radix: hex ? 16 : 10);
      return n != null && n > 0 && n <= 0x10FFFF ? String.fromCharCode(n) : m[0]!;
    }
    return _named[code.toLowerCase()] ?? m[0]!;
  });
}
