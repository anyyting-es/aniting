class ApiEndpoints {
  // Status & Auth
  static const String status = '/status';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String settings = '/settings';

  // Library
  static const String libraryCollection = '/library/collection';
  static const String libraryScan = '/library/scan';
  static const String animeEntry = '/library/anime-entry';
  static const String animeUpdateProgress = '/library/anime-entry/update-progress';
  static const String animeUpdateRepeat = '/library/anime-entry/update-repeat';
  static const String animeCollection = '/anime/collection';
  static const String anilistListEntry = '/anilist/list-entry';

  // Playback & Torrent
  static const String torrentstreamStart = '/torrentstream/start';
  static const String torrentstreamStop = '/torrentstream/stop';
  static const String torrentstreamFilePreviews = '/torrentstream/torrent-file-previews';
  static const String torrentSearch = '/torrent/search';
  static const String mediastream = '/mediastream';

  // Extensions
  static const String extensionsAll = '/extensions/all';
  static const String extensionPayload = '/extensions/payload';
  static const String listOnlinestreamProviders = '/extensions/list/onlinestream-provider';
  static const String listAnimeTorrentProviders = '/extensions/list/anime-torrent-provider';
  static const String listMangaProviders = '/extensions/list/manga-provider';

  // Online Streaming
  static const String onlinestreamEpisodeList = '/onlinestream/episode-list';
  static const String onlinestreamEpisodeSource = '/onlinestream/episode-source';
  static const String onlinestreamCache = '/onlinestream/cache';
  static const String onlinestreamSearch = '/onlinestream/search';
  static const String onlinestreamManualMapping = '/onlinestream/manual-mapping';
  static const String onlinestreamGetMapping = '/onlinestream/get-mapping';
  static const String onlinestreamRemoveMapping = '/onlinestream/remove-mapping';

  // Discover & Search
  static const String discover = '/discover';
  static const String missedSequels = '/anilist/list-missed-sequels';

  // Continuity (Watch History)
  static const String continuityHistory = '/continuity/history';
  static const String continuityItem = '/continuity/item';

  // Manga
  static const String mangaCollection = '/manga/collection';
  static const String mangaAnilistCollection = '/manga/anilist/collection';
  static const String mangaEntry = '/manga/entry';
  static const String mangaChapters = '/manga/chapters';
  static const String mangaPages = '/manga/pages';
  static const String mangaUpdateProgress = '/manga/update-progress';
  static const String mangaAnilistList = '/manga/anilist/list';
  static const String mangaCache = '/manga/entry/cache';

  // Manga Downloads
  static const String mangaDownloadChapters = '/manga/download-chapters';
  static const String mangaDownloadData = '/manga/download-data';
  static const String mangaDownloadQueue = '/manga/download-queue';
  static const String mangaDownloadQueueStart = '/manga/download-queue/start';
  static const String mangaDownloadQueueStop = '/manga/download-queue/stop';
  static const String mangaDownloadChapterDelete = '/manga/download-chapter';
  static const String mangaDownloadsList = '/manga/downloads';
  static const String mangaDownloadedChapters = '/manga/downloaded-chapters';
}
