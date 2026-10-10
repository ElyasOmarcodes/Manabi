import '../../core/models/answer.dart';
import '../../core/models/chat.dart';
import '../../l10n/gen/app_localizations.dart';
import '../widgets/answer_markdown.dart';

String _location(AnswerSource s, AppLocalizations l) => [
      if (s.volume != null) '${l.volume} ${s.volume}',
      if (s.printedPage != null) '${l.page} ${s.printedPage}',
      if (s.internalPage != null) '${l.turathPage} ${s.internalPage}',
    ].join('، ');

/// One source as plain text (for copy).
String sourceAsText(AnswerSource s, AppLocalizations l) {
  final b = StringBuffer('[${s.n}] ${s.bookTitle}');
  if (s.authorName != null) b.write(' — ${s.authorName}');
  final loc = _location(s, l);
  if (loc.isNotEmpty) b.write(' ($loc)');
  for (final q in s.quotes) {
    b.write('\n«${q.text}»');
  }
  b.write('\n${s.url}');
  return b.toString();
}

/// One answer as plain text (copy / share / .txt).
String answerAsText(ChatTurn t, AppLocalizations l) {
  final r = t.result;
  final b = StringBuffer()
    ..writeln('${l.question}: ${t.question}')
    ..writeln();
  if (r == null) return b.toString();
  b
    ..writeln(r.isDocumented ? l.statusAnswered : l.statusInsufficient)
    ..writeln()
    ..writeln(stripMarkdown(r.answer));
  if (r.opinions.isNotEmpty) {
    b
      ..writeln()
      ..writeln(l.opinions);
    for (final o in r.opinions) {
      b.writeln('• ${o.holder}: ${o.view} ${o.sources.map((n) => '[$n]').join()}');
    }
  }
  if (r.sources.isNotEmpty) {
    b
      ..writeln()
      ..writeln('${l.sources}:');
    for (final s in r.sources) {
      b
        ..writeln(sourceAsText(s, l))
        ..writeln();
    }
  }
  b
    ..writeln('—')
    ..writeln(l.generatedBy)
    ..writeln(l.disclaimer);
  return b.toString();
}

String _mdEscape(String s) => s.replaceAll('|', r'\|');

/// A whole chat (or one answer) as Markdown.
String turnsAsMarkdown(String title, List<ChatTurn> turns, AppLocalizations l) {
  final b = StringBuffer('# ${_mdEscape(title)}\n\n');
  for (final t in turns) {
    final r = t.result;
    b.writeln('## ${l.question}\n\n${t.question}\n');
    if (r == null) continue;
    b.writeln('### ${l.answer} — ${r.isDocumented ? l.statusAnswered : l.statusInsufficient}\n');
    b.writeln('${r.answer}\n');
    if (r.opinions.isNotEmpty) {
      b.writeln('### ${l.opinions}\n');
      for (final o in r.opinions) {
        b.writeln('- **${o.holder}:** ${o.view} ${o.sources.map((n) => '[$n]').join()}');
      }
      b.writeln();
    }
    if (r.sources.isNotEmpty) {
      b.writeln('### ${l.sources}\n');
      for (final s in r.sources) {
        final loc = _location(s, l);
        b.writeln('${s.n}. **${s.bookTitle}**${s.authorName != null ? ' — ${s.authorName}' : ''}${loc.isNotEmpty ? ' ($loc)' : ''}  ');
        b.writeln('   <${s.url}>');
        for (final q in s.quotes) {
          b.writeln('\n   > ${q.text}');
        }
        b.writeln();
      }
    }
    b.writeln('---\n');
  }
  b.writeln('_${l.generatedBy}. ${l.disclaimer}_');
  return b.toString();
}

String turnsAsText(String title, List<ChatTurn> turns, AppLocalizations l) =>
    '$title\n${'=' * 24}\n\n${turns.map((t) => answerAsText(t, l)).join('\n\n${'-' * 24}\n\n')}';

String safeFileName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final short = cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  return short.isEmpty ? 'manabi' : 'manabi - $short';
}
