/// Turath's book card ("الكتاب: …", "المؤلف: …", "الناشر: …") split into
/// labelled fields, and the lines that are not fields (notes such as
/// "[ترقيم الكتاب موافق للمطبوع]").
({List<(String, String)> fields, List<String> notes}) splitBookInfo(String info) {
  final fields = <(String, String)>[];
  final notes = <String>[];
  final field = RegExp(r'^([^:：\[\]()]{2,32}?)\s*[:：]\s*(.+)$');
  for (final raw in plainText(info).split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final m = field.firstMatch(line);
    if (m != null && m.group(1)!.trim().split(RegExp(r'\s+')).length <= 4) {
      fields.add((m.group(1)!.trim(), m.group(2)!.trim()));
    } else if (fields.isNotEmpty && notes.isEmpty && !line.startsWith('[') && !line.startsWith('(')) {
      // A value that runs onto the next line.
      final (k, v) = fields.removeLast();
      fields.add((k, '$v $line'));
    } else {
      notes.add(line);
    }
  }
  return (fields: fields, notes: notes);
}

/// Text from Turath's light HTML: line breaks kept, tags dropped.
String plainText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll('\r', '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
