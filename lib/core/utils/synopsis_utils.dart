/// Universal utility for cleaning and formatting AniList, MAL, and media descriptions/synopses.
///
/// Strips HTML tags, decodes HTML entities, removes trailing source and note footers
/// (e.g. `(Source: ...)`, `Note: ...`, `[Written by MAL Rewrite]`), and normalizes
/// excessive spaces and line breaks.
library;

String cleanSynopsis(String? raw) {
  if (raw == null) return '';
  var text = raw.trim();
  if (text.isEmpty) return '';

  // 1. Convert common break/paragraph tags to newlines
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
  text = text.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n');

  // 2. Decode HTML entities
  text = text
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&rsquo;', "'")
      .replaceAll('&lsquo;', "'")
      .replaceAll('&ldquo;', '"')
      .replaceAll('&rdquo;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–')
      .replaceAll('&hellip;', '…')
      .replaceAll('&nbsp;', ' ');

  // 3. Strip all remaining HTML tags
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');

  // 4. Strip common metadata/credit footers such as:
  //    (Source: ...)
  //    [Source: ...]
  //    Source: ...
  //    __Source:__ ... / **Source:** ... / *Source:* ...
  //    (Note: ...) / [Note: ...] / Note: ... / Notes: ...
  //    [Written by MAL Rewrite] / (Written by ...)
  text = text.replaceAll(
    RegExp(r'[\(\[]\s*Source\s*:[^\)\]]+[\)\]]', caseSensitive: false),
    '',
  );
  text = text.replaceAll(
    RegExp(r'[\(\[]\s*Notes?\s*:[^\)\]]+[\)\]]', caseSensitive: false),
    '',
  );
  text = text.replaceAll(
    RegExp(r'[\(\[]\s*Written by[^\)\]]+[\)\]]', caseSensitive: false),
    '',
  );
  text = text.replaceAll(
    RegExp(r'^(?:__|[\*_]{1,2})?\s*Source\s*:[^\n]*$', multiLine: true, caseSensitive: false),
    '',
  );
  text = text.replaceAll(
    RegExp(r'^(?:__|[\*_]{1,2})?\s*Notes?\s*:[^\n]*$', multiLine: true, caseSensitive: false),
    '',
  );

  // 5. Clean line-by-line whitespace
  final lines = text.split('\n');
  final cleanedLines = <String>[];
  for (final line in lines) {
    // Replace multiple horizontal spaces/tabs within line with a single space
    final trimmed = line.replaceAll(RegExp(r'[^\S\r\n]+'), ' ').trim();
    cleanedLines.add(trimmed);
  }
  text = cleanedLines.join('\n');

  // 6. Normalize excessive blank lines (more than two consecutive newlines become \n\n)
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}
