/// Finds the layers of a classical page: Quran verses and, in commentaries
/// (شروح) and glosses (حواشي), the base text (المتن).
///
/// Turath's text has no markup for the matn, so it is found from how these
/// books are laid out:
/// * a matn block printed at the top of the page, before a line of tatweels
///   (ــ), as in مرقاة المفاتيح or مراقي الفلاح;
/// * matn words quoted in the commentary between delimiters, e.g.
///   (وَلَا أَدْحَرُ) or "القيام بعده". A delimiter can be matn "always", or
///   only when its words are really in the matn ("verified"), which tells a
///   quoted lemma from a quoted book title in the same quotes.
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
final _digitsOnly = RegExp(r'^[\s\d٠-٩۰-۹*/.\-–،,^]*$');

/// The longest span one delimiter pair may enclose, by marker. A pair that
/// never closes (a stray "(" is common in these texts) is dropped instead of
/// swallowing the rest of the page.
const _maxSpan = <String, int>{'()': 700, '«»': 900, '""': 450, '“”': 450, '[]': 500, '{}': 900, '﴿﴾': 4000};

// ── Letter skeleton ────────────────────────────────────────────────────

/// Words of [text] reduced to bare letters: no diacritics, tatweel or
/// punctuation, one form per letter (أ/إ/آ → ا, ى → ي, ة → ه), so a quote
/// can be found in the matn however it was vowelled or punctuated.
List<String> skeletonWords(String text) {
  final out = <String>[];
  final word = StringBuffer();
  void flush() {
    if (word.isEmpty) return;
    var w = word.toString();
    word.clear();
    if (w == 'ابن') w = 'بن';
    out.add(w);
  }

  for (final rune in text.runes) {
    final c = _letter(rune);
    if (c == null) {
      if (!_isMark(rune)) flush();
      continue;
    }
    word.writeCharCode(c);
  }
  flush();
  return out;
}

bool _isMark(int r) => (r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640 || (r >= 0x06D6 && r <= 0x06ED) || (r >= 0x0610 && r <= 0x061A);

int? _letter(int r) {
  if (r >= 0x0660 && r <= 0x0669) return 0x30 + r - 0x0660;
  if (r >= 0x06F0 && r <= 0x06F9) return 0x30 + r - 0x06F0;
  if (r >= 0x30 && r <= 0x39) return r;
  switch (r) {
    case 0x0623 || 0x0625 || 0x0622 || 0x0671:
      return 0x0627;
    case 0x0649 || 0x06CC:
      return 0x064A;
    case 0x0629:
      return 0x0647;
    case 0x06A9:
      return 0x0643;
    case 0x0624:
      return 0x0648;
    case 0x0626:
      return 0x064A;
  }
  if ((r >= 0x0621 && r <= 0x064A) || (r >= 0x066E && r <= 0x06D3) || (r >= 0x06FA && r <= 0x06FF)) return r;
  return null;
}

/// Is [quote] in [context] (as a run of words)? Long quotes may differ a
/// little from the matn (a word left out, another edition).
bool quotedFrom(List<String> quote, List<String> context, {Set<String>? contextSet}) {
  if (quote.isEmpty || context.isEmpty) return false;
  // A lone conjunction quoted from the matn ("و" يسن …) joins its next word.
  if (quote.length == 1 && (quote.single == 'و' || quote.single == 'ف')) return context.any((w) => w.startsWith(quote.single));
  if (quote.length <= 3) return _containsRun(context, quote);
  final set = contextSet ?? context.toSet();
  final found = quote.where((w) => set.contains(w) || set.contains(_bare(w)) || set.contains('و$w')).length;
  if (found / quote.length < 0.75) return false;
  // And some of it in order, not scattered common words.
  for (var i = 0; i + 3 <= quote.length; i++) {
    if (_containsRun(context, quote.sublist(i, i + 3))) return true;
  }
  return false;
}

/// A word without a joined و or ف ("والقيام" → "القيام").
String _bare(String w) => w.length > 2 && (w.startsWith('و') || w.startsWith('ف')) ? w.substring(1) : w;

bool _sameWord(String a, String b) => a == b || _bare(a) == b || a == _bare(b);

bool _containsRun(List<String> hay, List<String> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (!_sameWord(hay[i + j], needle[j])) continue outer;
    }
    return true;
  }
  return false;
}

// ── Page structure ─────────────────────────────────────────────────────

/// The line of tatweels (ــ) that ends the matn printed on top of the page.
final matnSeparator = RegExp(r'^[ \t]*ـ{2,}[ \t]*$', multiLine: true);

/// The matn block on top of the page and where the commentary starts, or
/// null when the page has none.
({int blockEnd, int sharhStart})? matnBlock(String text) {
  final m = matnSeparator.firstMatch(text);
  if (m == null) return null;
  if (!_arabicLetter.hasMatch(text.substring(0, m.start))) return null;
  var start = m.end;
  while (start < text.length && (text[start] == '\n' || text[start] == ' ')) {
    start++;
  }
  var end = m.start;
  while (end > 0 && (text[end - 1] == '\n' || text[end - 1] == ' ')) {
    end--;
  }
  return (blockEnd: end, sharhStart: start);
}

// ── Delimited spans ────────────────────────────────────────────────────

bool _validInner(String inner, int maxSpan) => inner.length + 2 <= maxSpan && _arabicLetter.hasMatch(inner) && !_digitsOnly.hasMatch(inner);

/// A quote pair holds whole bracketed groups: "… («قال …" is a mispairing.
bool _balanced(String inner) {
  for (final (o, c) in const [('(', ')'), ('«', '»'), ('[', ']'), ('﴿', '﴾')]) {
    if (o.allMatches(inner).length != c.allMatches(inner).length) return false;
  }
  return true;
}

/// Words too common to show that a one-word quote comes from the matn.
const _common = {'ان', 'في', 'من', 'علي', 'عن', 'الي', 'ما', 'لا', 'قال', 'اي', 'هو', 'هي', 'او', 'ثم', 'بن', 'الله', 'ذلك', 'هذا', 'كان', 'قد', 'لم', 'لن', 'اذا', 'به', 'له', 'منه'};

bool _inside(int i, List<(int, int)> ranges) => ranges.any((r) => i >= r.$1 && i < r.$2);

/// Top-level spans enclosed by [marker] (delimiters included), skipping
/// footnote numbers like (١), anything inside [exclude], and openers that
/// never close.
List<(int, int)> markerRanges(String text, String marker, {List<(int, int)> exclude = const [], int? maxSpan}) {
  final pair = layerMarkers[marker];
  if (pair == null) return const [];
  final (open, close) = pair;
  final limit = maxSpan ?? _maxSpan[marker] ?? 700;
  if (open == close) return _quoteRanges(text, open, exclude, limit).first;
  final pairs = <(int, int)>[];
  final stack = <int>[];
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c != open && c != close) continue;
    if (_inside(i, exclude)) continue;
    if (c == open) {
      stack.add(i);
    } else if (stack.isNotEmpty) {
      final s = stack.removeLast();
      if (_validInner(text.substring(s + 1, i), limit)) pairs.add((s, i + 1));
    }
  }
  // Keep the outermost valid pairs: an invalid outer pair (too long, never
  // closed) leaves its inner ones in place.
  pairs.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : b.$2.compareTo(a.$2));
  final out = <(int, int)>[];
  for (final p in pairs) {
    if (out.isNotEmpty && p.$1 < out.last.$2) continue;
    out.add(p);
  }
  return out;
}

/// Pairs of a symmetric quote mark, line by line. Returns both alignments
/// of each line (first, second, ...) and (second, third, ...): a quote left
/// open on an earlier page shifts every pair after it.
List<List<(int, int)>> _quoteRanges(String text, String q, List<(int, int)> exclude, int limit) {
  final even = <(int, int)>[];
  final odd = <(int, int)>[];
  var lineStart = 0;
  while (lineStart <= text.length) {
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = text.length;
    final marks = <int>[
      for (var i = lineStart; i < lineEnd; i++)
        if (text[i] == q && !_inside(i, exclude)) i,
    ];
    for (final (offset, into) in [(0, even), (1, odd)]) {
      var i = offset;
      while (i + 1 < marks.length) {
        final s = marks[i], e = marks[i + 1];
        final inner = text.substring(s + 1, e);
        if (_validInner(inner, limit) && _balanced(inner)) {
          into.add((s, e + 1));
          i += 2;
        } else {
          i += 1;
        }
      }
    }
    lineStart = lineEnd + 1;
  }
  return [even, odd];
}

/// Every pair of neighbouring quote marks on a line that could be a quote.
List<(int, int)> _neighbourPairs(String text, String q, List<(int, int)> exclude, int limit) {
  final out = <(int, int)>[];
  var lineStart = 0;
  while (lineStart <= text.length) {
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = text.length;
    int? prev;
    for (var i = lineStart; i < lineEnd; i++) {
      if (text[i] != q || _inside(i, exclude)) continue;
      if (prev != null) {
        final inner = text.substring(prev + 1, i);
        if (_validInner(inner, limit) && _balanced(inner)) out.add((prev, i + 1));
      }
      prev = i;
    }
    lineStart = lineEnd + 1;
  }
  return out;
}

/// Verses: ﴿…﴾ always, plus the extra markers given (e.g. {…} in books
/// that use braces for verses).
List<(int, int)> quranRanges(String text, {List<String> extra = const []}) {
  final ranges = [for (final m in {'﴿﴾', ...extra}) ...markerRanges(text, m, maxSpan: 4000)];
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  return ranges;
}

// ── Rules ──────────────────────────────────────────────────────────────

/// How one book sets its matn apart.
class MatnRules {
  const MatnRules({this.block = false, this.always = const [], this.verified = const []});

  /// Text above the ــ line is matn.
  final bool block;

  /// Delimiters whose content is always matn.
  final List<String> always;

  /// Delimiters whose content is matn when its words are in the matn.
  final List<String> verified;

  bool get isEmpty => !block && always.isEmpty && verified.isEmpty;

  @override
  String toString() => 'MatnRules(block: $block, always: $always, verified: $verified)';
}

/// Matn ranges of a page [text] under [rules]. [context] holds matn blocks
/// of earlier pages (most recent first), used to verify quotes.
List<(int, int)> matnRanges(String text, MatnRules rules, {List<String> context = const [], List<(int, int)> verses = const []}) {
  final out = <(int, int)>[];
  final block = matnBlock(text);
  final exclude = [...verses];
  if (block != null) {
    if (rules.block) out.add((0, block.blockEnd));
    // Quotes inside the block are part of it, not lemmas.
    exclude.add((0, block.sharhStart));
  }
  final contexts = [
    if (block != null) skeletonWords(text.substring(0, block.blockEnd)),
    for (final c in context) skeletonWords(c),
  ].where((c) => c.isNotEmpty).toList();
  final sets = [for (final c in contexts) c.toSet()];
  bool verify(int s, int e) {
    final words = skeletonWords(text.substring(s + 1, e - 1));
    if (words.length == 1 && _common.contains(words.single)) return false;
    for (var i = 0; i < contexts.length; i++) {
      if (quotedFrom(words, contexts[i], contextSet: sets[i])) return true;
    }
    return false;
  }

  for (final m in {...rules.always, ...rules.verified}) {
    final pair = layerMarkers[m];
    if (pair == null) continue;
    final always = rules.always.contains(m);
    if (!always && contexts.isEmpty) continue;
    final List<(int, int)> spans;
    if (pair.$1 == pair.$2) {
      final [even, odd] = _quoteRanges(text, pair.$1, exclude, _maxSpan[m] ?? 450);
      if (always) {
        // The alignment whose pairs are found in the matn more often.
        spans = contexts.isEmpty || even.where((r) => verify(r.$1, r.$2)).length >= odd.where((r) => verify(r.$1, r.$2)).length ? even : odd;
      } else {
        // Any two neighbouring marks may be a pair; keep those quoting the matn.
        spans = _bestNonOverlapping(_neighbourPairs(text, pair.$1, exclude, _maxSpan[m] ?? 450).where((r) => verify(r.$1, r.$2)).toList());
      }
    } else {
      spans = [for (final r in markerRanges(text, m, exclude: exclude)) if (always || verify(r.$1, r.$2)) r];
    }
    out.addAll(spans);
  }
  return _merge(out);
}

List<(int, int)> _bestNonOverlapping(List<(int, int)> spans) {
  spans.sort((a, b) => a.$1.compareTo(b.$1));
  final out = <(int, int)>[];
  for (final s in spans) {
    if (out.isNotEmpty && s.$1 < out.last.$2) {
      if (s.$2 - s.$1 > out.last.$2 - out.last.$1) out[out.length - 1] = s;
      continue;
    }
    out.add(s);
  }
  return out;
}

List<(int, int)> _merge(List<(int, int)> ranges) {
  final sorted = [...ranges]..sort((a, b) => a.$1.compareTo(b.$1));
  final out = <(int, int)>[];
  for (final r in sorted) {
    if (out.isNotEmpty && r.$1 <= out.last.$2) {
      if (r.$2 > out.last.$2) out[out.length - 1] = (out.last.$1, r.$2);
    } else {
      out.add(r);
    }
  }
  return out;
}

// ── Detection without AI ───────────────────────────────────────────────

/// How strongly a marker looks like the matn delimiter across sample pages.
class MarkerScore {
  const MarkerScore(this.marker, this.perPage, this.coverage, this.averageLength, {this.verifiedRate});
  final String marker;
  final double perPage;

  /// Share of the text inside the marker.
  final double coverage;
  final double averageLength;

  /// Share of its spans found in the pages' matn blocks (null: no blocks).
  final double? verifiedRate;

  /// Frequent, not tiny, and neither all nor nothing of the page.
  double get score => perPage * (averageLength >= 8 ? 1 : 0.3) * (coverage > 0.03 && coverage < 0.8 ? 1 : 0.2);
}

/// Scores each matn marker on the sample pages (verses and matn blocks
/// excluded first).
List<MarkerScore> scoreMatnMarkers(List<String> pages, {List<String> quranMarkers = const []}) {
  final pageCount = pages.isEmpty ? 1 : pages.length;
  final blocks = [
    for (final t in pages)
      if (matnBlock(t) case final b?) skeletonWords(t.substring(0, b.blockEnd)),
  ];
  final scores = <MarkerScore>[];
  for (final marker in matnMarkerIds) {
    if (quranMarkers.contains(marker)) continue;
    var pairs = 0, inside = 0, total = 0, verified = 0;
    for (final text in pages) {
      final b = matnBlock(text);
      final exclude = [...quranRanges(text, extra: quranMarkers), if (b != null) (0, b.sharhStart)];
      final pair = layerMarkers[marker]!;
      final ranges = pair.$1 == pair.$2 ? _quoteRanges(text, pair.$1, exclude, _maxSpan[marker]!).first : markerRanges(text, marker, exclude: exclude);
      pairs += ranges.length;
      inside += ranges.fold(0, (sum, r) => sum + r.$2 - r.$1);
      total += text.length - (b?.sharhStart ?? 0);
      for (final (s, e) in ranges) {
        final words = skeletonWords(text.substring(s + 1, e - 1));
        if (blocks.any((c) => quotedFrom(words, c))) verified++;
      }
    }
    scores.add(MarkerScore(marker, pairs / pageCount, total == 0 ? 0 : inside / total, pairs == 0 ? 0 : inside / pairs,
        verifiedRate: blocks.isEmpty || pairs == 0 ? null : verified / pairs));
  }
  scores.sort((a, b) => b.score.compareTo(a.score));
  return scores;
}

/// The book's matn rules guessed from sample pages, without AI.
MatnRules detectMatnRules(List<String> pages, {List<String> quranMarkers = const []}) {
  final withBlock = pages.where((t) => matnBlock(t) != null).length;
  final block = withBlock > 0;
  final scores = scoreMatnMarkers(pages, quranMarkers: quranMarkers);
  final always = <String>[], verified = <String>[];
  if (block) {
    // Measured against the matn itself: quotes found in it are lemmas.
    final perPageMin = 0.5;
    for (final s in scores) {
      final rate = s.verifiedRate;
      if (rate == null || s.perPage < perPageMin) continue;
      if (rate >= 0.7) {
        always.add(s.marker);
      } else if (rate >= 0.15) {
        verified.add(s.marker);
      }
    }
  } else if (scores.isNotEmpty && scores.first.score >= 1.5) {
    final best = scores.first;
    always.add(best.marker);
    if (scores.length > 1 && scores[1].score >= best.score * 0.7 && scores[1].score >= 1.5) always.add(scores[1].marker);
  }
  return MatnRules(block: block, always: always, verified: verified);
}

/// The likely matn markers (without AI). Empty when the pages show no matn.
List<String> detectMatnMarkers(List<String> pages, {List<String> quranMarkers = const []}) {
  final r = detectMatnRules(pages, quranMarkers: quranMarkers);
  return [...r.always, ...r.verified];
}

final _haraka = RegExp('[ً-ْ]');

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

// ── AI annotation ──────────────────────────────────────────────────────

/// Finds AI-marked matn stretches (given by their first and last words) in
/// [text], in order. A stretch right inside its delimiters takes them too.
List<(int, int)> locateSpans(String text, List<(String, String)> spans) {
  final index = _LetterIndex(text);
  final out = <(int, int)>[];
  var cursor = 0;
  for (final (start, end) in spans) {
    final s = index.find(start, cursor);
    if (s == null) continue;
    final e = index.find(end, s.$1, last: true, within: 6000);
    final span = (s.$1, e == null || e.$2 < s.$2 ? s.$2 : e.$2);
    var a = span.$1, b = span.$2;
    // Take the enclosing delimiters: "(قال" … ")" .
    var pa = a;
    while (pa > 0 && text[pa - 1] == ' ') {
      pa--;
    }
    var pb = b;
    while (pb < text.length && text[pb] == ' ') {
      pb++;
    }
    if (pa > 0 && pb < text.length) {
      for (final (o, c) in layerMarkers.values) {
        if (text[pa - 1] == o && text[pb] == c) {
          a = pa - 1;
          b = pb + 1;
          break;
        }
      }
    }
    out.add((a, b));
    cursor = span.$2;
  }
  return _merge(out);
}

String _lettersOf(String text) {
  final buf = StringBuffer();
  for (final rune in text.runes) {
    final c = _letter(rune);
    if (c != null) buf.writeCharCode(c);
  }
  return buf.toString();
}

/// Letter-only view of a text with a map back to its offsets.
class _LetterIndex {
  _LetterIndex(this._text) {
    final text = _text;
    final buf = StringBuffer();
    var i = 0;
    for (final rune in text.runes) {
      final c = _letter(rune);
      if (c != null) {
        buf.writeCharCode(c);
        _at.add(i);
      }
      i += rune > 0xFFFF ? 2 : 1;
    }
    _letters = buf.toString();
    _textLength = i;
  }
  final String _text;
  late final String _letters;
  final _at = <int>[];
  late final int _textLength;

  /// The text range of [snippet] at or after offset [from].
  (int, int)? find(String snippet, int from, {bool last = false, int within = 1 << 30}) {
    final needle = _lettersOf(snippet);
    if (needle.isEmpty) return null;
    var k = 0;
    while (k < _at.length && _at[k] < from) {
      k++;
    }
    final hit = _letters.indexOf(needle, k);
    if (hit < 0) return null;
    final start = _at[hit];
    if (start - from > within) return null;
    final endIdx = hit + needle.length - 1;
    var end = _at[endIdx] + 1;
    // With the last letter's marks.
    while (end < _text.length && _isMark(_text.codeUnitAt(end))) {
      end++;
    }
    return (start, end > _textLength ? _textLength : end);
  }
}

/// How well [rules] reproduce [truth] (matn letters marked by AI) on
/// [pages]: F1 over Arabic letters, 0…1.
double rulesAgreement(List<String> pages, List<List<(int, int)>> truth, MatnRules rules) {
  var tp = 0, fp = 0, fn = 0;
  for (var p = 0; p < pages.length; p++) {
    final text = pages[p];
    final verses = quranRanges(text);
    final predicted = matnRanges(text, rules, context: [for (var q = p - 1; q >= 0; q--) _blockText(pages[q])].whereType<String>().toList(), verses: verses);
    final gold = truth[p];
    for (var i = 0; i < text.length; i++) {
      if (!_arabicLetter.hasMatch(text[i]) || _inside(i, verses)) continue;
      final a = _inside(i, predicted), b = _inside(i, gold);
      if (a && b) tp++;
      if (a && !b) fp++;
      if (!a && b) fn++;
    }
  }
  if (tp == 0) return fp == 0 && fn == 0 ? 1 : 0;
  final precision = tp / (tp + fp), recall = tp / (tp + fn);
  return 2 * precision * recall / (precision + recall);
}

String? _blockText(String text) {
  final b = matnBlock(text);
  return b == null ? null : text.substring(0, b.blockEnd);
}

/// The rules that best reproduce an AI annotation of sample pages, and how
/// closely (0…1). Tries the block rule and each delimiter as never, always
/// or verified, improving one choice at a time.
(MatnRules, double) learnMatnRules(List<String> pages, List<List<(int, int)>> truth) {
  final hasBlock = pages.any((t) => matnBlock(t) != null);
  var block = hasBlock;
  final mode = {for (final m in matnMarkerIds) m: 0}; // 0 never, 1 always, 2 verified
  MatnRules build() => MatnRules(
        block: block,
        always: [for (final e in mode.entries) if (e.value == 1) e.key],
        verified: [for (final e in mode.entries) if (e.value == 2) e.key],
      );
  var best = rulesAgreement(pages, truth, build());
  for (var round = 0; round < 2; round++) {
    var changed = false;
    if (hasBlock) {
      block = !block;
      final s = rulesAgreement(pages, truth, build());
      if (s > best + 1e-9) {
        best = s;
        changed = true;
      } else {
        block = !block;
      }
    }
    for (final m in matnMarkerIds) {
      final keep = mode[m]!;
      for (final option in [0, 1, if (hasBlock) 2]) {
        if (option == mode[m]) continue;
        final before = mode[m]!;
        mode[m] = option;
        final s = rulesAgreement(pages, truth, build());
        if (s > best + 1e-9) {
          best = s;
          changed = true;
        } else {
          mode[m] = before;
        }
      }
      if (mode[m] != keep) changed = true;
    }
    if (!changed) break;
  }
  return (build(), best);
}
