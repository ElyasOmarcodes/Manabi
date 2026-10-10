/// Matching Arabic text the way readers expect: diacritics, tatweel and the
/// common letter variants (alef forms, ya/alef maqsura, ta marbuta/ha) are
/// ignored, so "الصلاة" finds "الصَّلَاةِ".
RegExp? arabicPattern(String query) {
  final q = query.trim();
  if (q.isEmpty) return null;
  const marks = r'[ً-ٰٟـ]*';
  final buffer = StringBuffer();
  for (final rune in q.runes) {
    final c = String.fromCharCode(rune);
    if (RegExp(r'[ً-ٰٟـ]').hasMatch(c)) continue;
    if (RegExp(r'\s').hasMatch(c)) {
      buffer.write(r'\s+');
      continue;
    }
    buffer.write(switch (c) {
      'ا' || 'أ' || 'إ' || 'آ' || 'ٱ' => '[اأإآٱ]',
      'ي' || 'ى' || 'ی' => '[يىی]',
      'ه' || 'ة' => '[هة]',
      'ك' || 'ک' => '[كک]',
      'و' || 'ؤ' => '[وؤ]',
      _ => RegExp.escape(c),
    });
    buffer.write(marks);
  }
  return RegExp(buffer.toString());
}

/// Ranges of [text] that match [query] (all of its words, or the whole phrase).
List<(int, int)> arabicMatches(String text, String? query) {
  if (query == null || query.trim().isEmpty) return const [];
  final whole = arabicPattern(query);
  final found = whole == null ? const <RegExpMatch>[] : whole.allMatches(text).toList();
  if (found.isNotEmpty || !query.trim().contains(' ')) return [for (final m in found) (m.start, m.end)];
  // No exact phrase: mark each word of the query (words of 2+ letters).
  final out = <(int, int)>[];
  for (final word in query.trim().split(RegExp(r'\s+')).where((w) => w.length > 1)) {
    final p = arabicPattern(word);
    if (p == null) continue;
    out.addAll(p.allMatches(text).map((m) => (m.start, m.end)));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}
