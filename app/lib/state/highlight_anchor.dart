import '../core/turath/arabic_match.dart';
import 'reading_controller.dart';

/// Where a highlight sits on a page. A page has three text spaces: 'title',
/// 'body' (the matn on top and the commentary below are both in it) and
/// 'notes'. Offsets are kept without diacritics, so a mark stays in place
/// whether diacritics are shown or hidden.
const highlightSpaces = ['title', 'body', 'notes'];

final _mark = RegExp('[ً-ْٰـ]');

/// [i] in [s] counted without diacritics.
int toCanonical(String s, int i) {
  var n = 0;
  for (var k = 0; k < i && k < s.length; k++) {
    if (!_mark.hasMatch(s[k])) n++;
  }
  return n;
}

/// The offset in [s] of the [c]th letter counted without diacritics.
int fromCanonical(String s, int c) {
  var n = 0;
  for (var k = 0; k < s.length; k++) {
    if (n == c && !_mark.hasMatch(s[k])) return k;
    if (!_mark.hasMatch(s[k])) n++;
  }
  return s.length;
}

/// Exact places of [phrase] in [text] (never word by word).
List<(int, int)> exactMatches(String text, String phrase) {
  final p = arabicPattern(phrase.trim());
  if (p == null) return const [];
  return [for (final m in p.allMatches(text)) if (m.end > m.start) (m.start, m.end)];
}

typedef PlacedHighlight = ({String space, int start, int end, Highlight highlight});

/// Puts each highlight at one place: an anchored one at the occurrence of
/// its text nearest its saved offset in its own space; an older one (saved
/// without a place) at the first occurrence on the page. A highlight whose
/// text is no longer there is left out.
List<PlacedHighlight> placeHighlights(Map<String, String> spaces, List<Highlight> highlights) {
  final out = <PlacedHighlight>[];
  for (final h in highlights) {
    if (h.text.trim().isEmpty) continue;
    if (h.part != null) {
      final text = spaces[h.part!];
      if (text == null) continue;
      final found = exactMatches(text, h.text);
      if (found.isEmpty) continue;
      final want = h.start ?? 0;
      var best = found.first;
      var gap = 1 << 30;
      for (final m in found) {
        final d = (toCanonical(text, m.$1) - want).abs();
        if (d < gap) {
          gap = d;
          best = m;
        }
      }
      out.add((space: h.part!, start: best.$1, end: best.$2, highlight: h));
      continue;
    }
    for (final space in highlightSpaces) {
      final text = spaces[space];
      if (text == null) continue;
      final found = exactMatches(text, h.text);
      if (found.isEmpty) continue;
      out.add((space: space, start: found.first.$1, end: found.first.$2, highlight: h));
      break;
    }
  }
  return out;
}

/// A selected stretch of one space.
typedef SelectedSpan = ({String space, int start, int end, String text});

/// The placed highlights that a selection touches.
List<Highlight> highlightsUnder(List<PlacedHighlight> placed, List<SelectedSpan> selection) => [
      for (final p in placed)
        if (selection.any((s) => s.space == p.space && s.start < p.end && p.start < s.end)) p.highlight,
    ];

/// A new highlight's place for a selected stretch (leading and trailing
/// spaces dropped), or null when only spaces were selected.
({String text, int start})? anchorFor(String spaceText, int start, int end) {
  var s = start.clamp(0, spaceText.length);
  var e = end.clamp(s, spaceText.length);
  while (s < e && spaceText[s].trim().isEmpty) {
    s++;
  }
  while (e > s && spaceText[e - 1].trim().isEmpty) {
    e--;
  }
  if (e <= s) return null;
  return (text: spaceText.substring(s, e), start: toCanonical(spaceText, s));
}
