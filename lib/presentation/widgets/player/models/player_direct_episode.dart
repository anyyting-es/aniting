/// An episode that can be played directly from an external source, such as a
/// Plex or Jellyfin media server.
///
/// External playback already carries the URL of every episode, so the player
/// switches between them without going through the AniList / online-stream
/// resolution pipeline (which has no data for these libraries).
class PlayerDirectEpisode {
  /// Episode number inside the season the player is showing.
  final int number;
  final String title;
  final String streamUrl;

  /// Identifier of the item on the server (rating key / item id). Used to
  /// report playback progress back to the right episode when leaving.
  final String sourceId;

  /// Where the server says the user stopped watching this episode.
  final Duration startPosition;

  const PlayerDirectEpisode({
    required this.number,
    required this.title,
    required this.streamUrl,
    this.sourceId = '',
    this.startPosition = Duration.zero,
  });
}
