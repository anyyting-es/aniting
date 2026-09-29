/// Constantes de tipos de eventos WebSocket emitidos por el servidor Go Seanime.
///
/// El servidor envía mensajes JSON con el formato:
/// ```json
/// { "type": "<event-type>", "payload": <data|null> }
/// ```
class WsEvents {
  WsEvents._();

  // ─── Manga Downloads ─────────────────────────────────────────────────
  /// Emitido cuando la cola de descarga de capítulos cambia
  /// (capítulo añadido, empezó a descargar, completado, o error).
  static const String chapterDownloadQueueUpdated =
      'chapter-download-queue-updated';

  /// Emitido cuando los datos de descargas de manga se actualizan
  /// (capítulo terminó de descargarse, índice reconstruido).
  static const String refreshedMangaDownloadData =
      'refreshed-manga-download-data';

  // ─── Server Lifecycle ────────────────────────────────────────────────
  static const String serverReady = 'server-ready';

  // ─── AniList Collections ─────────────────────────────────────────────
  static const String refreshedAnilistAnimeCollection =
      'refreshed-anilist-anime-collection';
  static const String refreshedAnilistMangaCollection =
      'refreshed-anilist-manga-collection';

  // ─── Extensions ──────────────────────────────────────────────────────
  static const String extensionsReloaded = 'extensions-reloaded';
  static const String extensionUpdatesFound = 'extension-updates-found';

  // ─── Toasts ──────────────────────────────────────────────────────────
  static const String infoToast = 'info-toast';
  static const String errorToast = 'error-toast';
  static const String warningToast = 'warning-toast';
  static const String successToast = 'success-toast';

  // ─── Torrent Stream ──────────────────────────────────────────────────
  static const String torrentstreamState = 'torrentstream-state';
}
