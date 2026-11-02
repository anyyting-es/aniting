enum MediaServerLibraryType {
  movie,
  show,
  anime,
  music,
  other;

  static MediaServerLibraryType fromRawType(String? raw) {
    if (raw == null) return MediaServerLibraryType.other;
    final lower = raw.toLowerCase();
    if (lower.contains('anime')) return MediaServerLibraryType.anime;
    if (lower.contains('movie') || lower.contains('film')) {
      return MediaServerLibraryType.movie;
    }
    if (lower.contains('show') || lower.contains('tv') || lower.contains('series')) {
      return MediaServerLibraryType.show;
    }
    if (lower.contains('music') || lower.contains('audio')) {
      return MediaServerLibraryType.music;
    }
    return MediaServerLibraryType.other;
  }
}

/// Representa una sección o biblioteca dentro del servidor (Plex o Jellyfin).
class MediaServerLibrary {
  final String id;
  final String serverId;
  final String title;
  final MediaServerLibraryType type;
  final String? icon;

  const MediaServerLibrary({
    required this.id,
    required this.serverId,
    required this.title,
    required this.type,
    this.icon,
  });
}
