// Quote verification – Dart port of server/src/verify.mjs (keep in sync).
//
// Every Arabic quote shown to the user must be a real span of the retrieved
// Turath text. The model only points at a span; the text we display is cut
// from the source itself, with its original diacritics.
import 'dart:math' as math;

final _diacritic = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ‌-‏]');
final _ligature = RegExp('[﴾-﵏ﷰ-﷿]');
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

const _map = {
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', //
  'ى': 'ي', 'ی': 'ي', 'ئ': 'ي', 'ې': 'ي', 'ۍ': 'ي',
  'ة': 'ه', 'ؤ': 'و', 'ک': 'ك',
};

String? _digit(int code) {
  if (code >= 0x0660 && code <= 0x0669) return '${code - 0x0660}';
  if (code >= 0x06F0 && code <= 0x06F9) return '${code - 0x06F0}';
  return null;
}

class NormalizedText {
  NormalizedText(this.text, this.map);
  final String text;

  /// Original code-unit index for every normalized code unit.
  final List<int> map;
}

NormalizedText normalizeWithMap(String text) {
  final out = StringBuffer();
  final map = <int>[];
  var pendingSpace = false;
  var length = 0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (_diacritic.hasMatch(ch)) continue;
    var mapped = _digit(ch.codeUnitAt(0)) ?? _map[ch] ?? ch;
    if (_ligature.hasMatch(ch) || !_letterOrDigit.hasMatch(mapped)) {
      pendingSpace = length > 0;
      continue;
    }
    mapped = mapped.toLowerCase();
    if (pendingSpace) {
      out.write(' ');
      map.add(i);
      length++;
      pendingSpace = false;
    }
    out.write(mapped);
    for (var k = 0; k < mapped.length; k++) {
      map.add(i);
    }
    length += mapped.length;
  }
  return NormalizedText(out.toString(), map);
}

String normalizeArabic(String text) => normalizeWithMap(text).text;

class LocatedQuote {
  const LocatedQuote(this.text, {required this.exact, required this.score});
  final String text;
  final bool exact;
  final double score;
}

const minQuoteTokens = 3;
const fuzzyThreshold = 0.8;

class _Token {
  const _Token(this.value, this.start, this.end);
  final String value;
  final int start;
  final int end;
}

List<_Token> _tokenize(String normalized) =>
    RegExp(r'\S+').allMatches(normalized).map((m) => _Token(m.group(0)!, m.start, m.end)).toList();

int _extendEnd(String original, int end) {
  var e = end;
  while (e < original.length && _diacritic.hasMatch(original[e])) {
    e++;
  }
  return e;
}

String _slice(String original, NormalizedText norm, int startNorm, int endNorm) {
  final start = norm.map[startNorm];
  final end = _extendEnd(original, norm.map[endNorm - 1] + 1);
  return original.substring(start, end).trim();
}

int _lcs(List<String> a, List<String> b) {
  final prev = List<int>.filled(b.length + 1, 0);
  final cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      cur[j] = a[i - 1] == b[j - 1] ? prev[j - 1] + 1 : math.max(prev[j], cur[j - 1]);
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = cur[j];
    }
  }
  return prev[b.length];
}

/// Locates [quote] inside [source]; returns the original span or null.
LocatedQuote? locateQuote(String? source, String? quote) {
  if (source == null || quote == null) return null;
  final src = normalizeWithMap(source);
  final q = normalizeArabic(quote);
  final qTokens = q.split(' ').where((t) => t.isNotEmpty).toList();
  if (qTokens.length < minQuoteTokens) return null;

  final exactAt = src.text.indexOf(q);
  if (exactAt >= 0) {
    return LocatedQuote(_slice(source, src, exactAt, exactAt + q.length), exact: true, score: 1);
  }

  final sTokens = _tokenize(src.text);
  final m = qTokens.length;
  final windowLength = m + (m * 0.25).ceil();
  final firstWords = qTokens.take(3).toSet();
  final quoteSet = qTokens.toSet();
  var bestScore = 0.0;
  var bestFrom = -1;
  var bestTo = -1;
  for (var s = 0; s < sTokens.length; s++) {
    if (!firstWords.contains(sTokens[s].value)) continue;
    final window = sTokens.sublist(s, math.min(sTokens.length, s + windowLength));
    final score = _lcs(qTokens, window.map((t) => t.value).toList()) / m;
    if (score > bestScore) {
      var last = window.length - 1;
      while (last > 0 && !quoteSet.contains(window[last].value)) {
        last--;
      }
      bestScore = score;
      bestFrom = s;
      bestTo = s + last;
    }
  }
  if (bestScore < fuzzyThreshold) return null;
  return LocatedQuote(
    _slice(source, src, sTokens[bestFrom].start, sTokens[bestTo].end),
    exact: false,
    score: (bestScore * 100).round() / 100,
  );
}
