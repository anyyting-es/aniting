enum MediaServerType {
  plex,
  jellyfin,
  emby;

  String get displayName {
    switch (this) {
      case MediaServerType.plex:
        return 'Plex';
      case MediaServerType.jellyfin:
        return 'Jellyfin';
      case MediaServerType.emby:
        return 'Emby';
    }
  }
}
