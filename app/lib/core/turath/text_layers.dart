/// Finds the layers of a classical page: Quran verses and, in commentaries
/// (شروح) and glosses (حواشي), the base text (المتن) set off by delimiters.
library;

/// Delimiters that can enclose the matn (or a verse), by id.
const layerMarkers = <String, (String, String)>{
  '()': ('(', ')'),
  '«»': ('«', '»'),
  '""': ('"', '"'),
  '“”': ('“', '”'),
  '[]': ('[', ']'),
  '{}': ('{', '}'),
  '﴿﴾': ('﴿', '﴾'),
};

/// Markers offered for the matn (﴿﴾ is reserved for verses).
const matnMarkerIds = ['()', '«»', '""', '“”', '[]', '{}'];

final _arabicLetter = RegExp('[ء-يٮ-ۓۺ-ۿ]');
final _digitsOnly = RegExp(r'^[\s\d٠-٩۰-۹*/.\-–،,]*$');

/// Top-level spans enclosed by [marker] (delimiters included), skipping
/// footnote numbers like (١) and anything inside [exclude].
List<(int, int)> markerRanges(String text, String marker, {List<(int, int)> exclude = const [], int maxLength = 3000}) {
  final pair = layerMarkers[marker];
  if (pair == null) return const [];
  final (open, close) = pair;
  bool excluded(int i) => exclude.any((r) => i >= r.$1 && i < r.$2);
  final out = <(int, int)>[];
  void add(int s, int e) {
    final inner = text.substring(s + 1, e - 1);
    if (e - s > maxLength || !_arabicLetter.hasMatch(inner) || _digitsOnly.hasMatch(inner)) return;
    out.add((s, e));
  }

  if (open == close) {
    int? start;
    for (var i = 0; i < text.length; i++) {
      if (text[i] != open || excluded(i)) continue;
      if (start == null) {
        start = i;
      } else {
        add(start, i + 1);
        start = null;
      }
    }
    return out;
  }
  var depth = 0;
  var start = -1;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c != open && c != close) continue;
    if (excluded(i)) continue;
    if (c == open) {
      if (depth == 0) start = i;
      depth++;
    } else if (depth > 0) {
      depth--;
      if (depth == 0) add(start, i + 1);
    }
  }
  return out;
}

/// Verses: ﴿…﴾ always, plus the extra markers given (e.g. {…} in books
/// that use braces for verses).
List<(int, int)> quranRanges(String text, {List<String> extra = const []}) {
  final ranges = [for (final m in {'﴿﴾', ...extra}) ...markerRanges(text, m, maxLength: 4000)];
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  return ranges;
}

/// How strongly a marker looks like the matn delimiter across sample pages.
class MarkerScore {
  const MarkerScore(this.marker, this.perPage, this.coverage, this.averageLength);
  final String marker;
  final double perPage;

  /// Share of the text inside the marker.
  final double coverage;
  final double averageLength;

  /// Frequent, not tiny, and neither all nor nothing of the page.
  double get score => perPage * (averageLength >= 8 ? 1 : 0.3) * (coverage > 0.03 && coverage < 0.8 ? 1 : 0.2);
}

/// Scores each matn marker on the sample pages (verses excluded first).
List<MarkerScore> scoreMatnMarkers(List<String> pages, {List<String> quranMarkers = const []}) {
  final pageCount = pages.isEmpty ? 1 : pages.length;
  final scores = <MarkerScore>[];
  for (final marker in matnMarkerIds) {
    if (quranMarkers.contains(marker)) continue;
    var pairs = 0, inside = 0, total = 0;
    for (final text in pages) {
      final verses = quranRanges(text, extra: quranMarkers);
      final ranges = markerRanges(text, marker, exclude: verses);
      pairs += ranges.length;
      inside += ranges.fold(0, (sum, r) => sum + r.$2 - r.$1);
      total += text.length;
    }
    scores.add(MarkerScore(marker, pairs / pageCount, total == 0 ? 0 : inside / total, pairs == 0 ? 0 : inside / pairs));
  }
  scores.sort((a, b) => b.score.compareTo(a.score));
  return scores;
}

/// The likely matn markers (without AI): the strongest one, plus a second
/// one if it is nearly as strong. Empty when the pages show no matn.
List<String> detectMatnMarkers(List<String> pages, {List<String> quranMarkers = const []}) {
  final scores = scoreMatnMarkers(pages, quranMarkers: quranMarkers);
  if (scores.isEmpty || scores.first.score < 1.5) return const [];
  final best = scores.first;
  return [
    best.marker,
    if (scores.length > 1 && scores[1].score >= best.score * 0.7 && scores[1].score >= 1.5) scores[1].marker,
  ];
}

final _haraka = RegExp('[\u064B-\u0652]');

/// Does a book use braces for verses? Its {…} hold fully vowelled text
/// (as verses are printed) and it has no ﴿﴾.
bool bracesAreVerses(List<String> pages) {
  var vowelled = 0, braces = 0, ornate = 0;
  for (final t in pages) {
    ornate += markerRanges(t, '﴿﴾').length;
    for (final (s, e) in markerRanges(t, '{}')) {
      braces++;
      final inner = t.substring(s + 1, e - 1);
      final letters = _arabicLetter.allMatches(inner).length;
      if (letters > 0 && _haraka.allMatches(inner).length / letters > 0.45) vowelled++;
    }
  }
  return ornate == 0 && braces > 0 && vowelled / braces >= 0.6;
}
