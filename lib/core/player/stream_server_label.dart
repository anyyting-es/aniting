/// Formats an online-stream server name for the player UI.
///
/// Providers often encode the audio language as a bracketed or parenthesized
/// tag, e.g. `Server 1 [Latino]`, `Server 1 [Sub]` and
/// `Server 1 [Castellano]`. Stripping the tag makes all three options read
/// `Server 1`, so the tag is converted into a visible suffix instead:
/// `Server 1 • Latino`, `Server 1 • Sub`, `Server 1 • Castellano`.
String formatStreamServerLabel(
  String server, {
  String quality = '',
  bool includeQuality = false,
}) {
  var base = server;
  final suffixes = <String>[];

  for (final entry in _audioTags.entries) {
    if (!base.contains(entry.key)) continue;
    if (!suffixes.contains(entry.value)) suffixes.add(entry.value);
    base = base.replaceAll(entry.key, '');
  }

  base = base.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  final parts = <String>[
    if (base.isNotEmpty) base,
    ...suffixes,
    if (includeQuality &&
        quality.isNotEmpty &&
        quality != 'auto' &&
        quality != 'default')
      quality,
  ];

  return parts.isEmpty ? server.trim() : parts.join(' • ');
}

/// Audio tags used by the different providers, normalized for display.
const _audioTags = <String, String>{
  '[Latino]': 'Latino',
  '(Latino)': 'Latino',
  '[Castellano]': 'Castellano',
  '(Castellano)': 'Castellano',
  '[English Dub]': 'English Dub',
  '(English Dub)': 'English Dub',
  '[Dub]': 'Dub',
  '[DUB]': 'Dub',
  '(Dub)': 'Dub',
  '[Sub (Multi)]': 'Sub (Multi)',
  '[SUB]': 'Sub (Multi)',
  '[Sub]': 'Sub',
  '(Sub)': 'Sub',
};
