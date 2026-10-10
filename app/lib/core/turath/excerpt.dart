// Match-centred excerpts – port of Nusus src/turath/excerpt.ts (MIT).

String _stripTags(String v) => v.replaceAll(RegExp(r'<[^>]*>'), '');

final _edge = RegExp('^[‏‎\\s\\[\\](){}<>«»"\'`،,.:;!?…]+|[‏‎\\s\\[\\](){}<>«»"\'`،,.:;!?…]+\$');

String _cleanNeedle(String v) => v.replaceAll(RegExp(r'\s+'), ' ').replaceAll(_edge, '').trim();

List<String> snippetNeedles(String? snippet) {
  if (snippet == null || snippet.isEmpty) return const [];
  final out = <String>[];
  final seen = <String>{};
  void add(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty || !seen.add(normalized)) return;
    out.add(normalized);
    final cleaned = _cleanNeedle(normalized);
    if (cleaned.isNotEmpty && cleaned != normalized && seen.add(cleaned)) out.add(cleaned);
  }

  for (final m in RegExp(r'<em\b[^>]*>([\s\S]*?)</em>', caseSensitive: false).allMatches(snippet)) {
    add(_stripTags(m.group(1) ?? ''));
  }
  add(_stripTags(snippet));
  return out;
}

({String folded, List<int> map}) _fold(String text) {
  final map = <int>[];
  final b = StringBuffer();
  var lastWasSpace = true;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (RegExp(r'\s').hasMatch(ch)) {
      if (!lastWasSpace) {
        map.add(i);
        b.write(' ');
        lastWasSpace = true;
      }
      continue;
    }
    map.add(i);
    b.write(ch);
    lastWasSpace = false;
  }
  var folded = b.toString();
  if (folded.endsWith(' ')) {
    folded = folded.substring(0, folded.length - 1);
    map.removeLast();
  }
  return (folded: folded, map: map);
}

({int index, int length})? _findNeedle(String text, String needle) {
  if (needle.isEmpty) return null;
  final direct = text.indexOf(needle);
  if (direct >= 0) return (index: direct, length: needle.length);
  final f = _fold(text);
  ({int index, int length})? inFolded(String n) {
    final i = f.folded.indexOf(n);
    if (i < 0 || n.isEmpty) return null;
    final start = f.map[i];
    final last = f.map[i + n.length - 1];
    return (index: start, length: last - start + 1);
  }

  final hit = inFolded(needle);
  if (hit != null) return hit;
  if (needle.length < 8) return null;
  final maxProbe = needle.length < 96 ? needle.length : 96;
  for (var size = maxProbe; size >= 8; size = size > 32 ? size - 8 : size - 4) {
    final probe = needle.substring(0, size).trim();
    if (probe.length < 8) continue;
    final i = text.indexOf(probe);
    if (i >= 0) return (index: i, length: probe.length);
    final p = inFolded(probe);
    if (p != null) return p;
  }
  return null;
}

String _safeSlice(String text, int start, int end) {
  var from = start < 0 ? 0 : start;
  var to = end > text.length ? text.length : end;
  if (from > 0 && from < text.length && _isLow(text.codeUnitAt(from)) && _isHigh(text.codeUnitAt(from - 1))) from++;
  if (to > 0 && to < text.length && _isHigh(text.codeUnitAt(to - 1)) && _isLow(text.codeUnitAt(to))) to--;
  return text.substring(from, to);
}

bool _isHigh(int c) => c >= 0xD800 && c <= 0xDBFF;
bool _isLow(int c) => c >= 0xDC00 && c <= 0xDFFF;

/// Bounds [text] to [maxChars], centred on the search match from [snippet].
String boundText(String text, int maxChars, String? snippet) {
  if (text.length <= maxChars) return text;
  ({int index, int length, int rank})? best;
  final needles = snippetNeedles(snippet);
  for (var rank = 0; rank < needles.length; rank++) {
    final found = _findNeedle(text, needles[rank]);
    if (found == null) continue;
    if (best == null || rank < best.rank || (rank == best.rank && found.length > best.length)) {
      best = (index: found.index, length: found.length, rank: rank);
      if (rank == 0 && found.length >= 3) break;
    }
  }
  if (best == null) return _safeSlice(text, 0, maxChars);
  var start = best.index;
  if (best.length < maxChars) {
    start = best.index - ((maxChars - best.length) ~/ 2);
    if (start < 0) start = 0;
    final maxStart = text.length - maxChars < 0 ? 0 : text.length - maxChars;
    if (start > maxStart) start = maxStart;
  }
  return _safeSlice(text, start, start + maxChars);
}
