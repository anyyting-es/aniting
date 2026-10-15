import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/episode_item.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/models/show_local_file_item.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';

extension _IterableFirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

enum EpisodeFilterType {
  all,
  localOnly,
  unwatched,
}

class EpisodesArgs {
  final int mediaId;
  final bool isTmdb;

  const EpisodesArgs({required this.mediaId, required this.isTmdb});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodesArgs &&
          runtimeType == other.runtimeType &&
          mediaId == other.mediaId &&
          isTmdb == other.isTmdb;

  @override
  int get hashCode => mediaId.hashCode ^ isTmdb.hashCode;
}

class EpisodesState {
  final int mediaId;
  final bool isTmdb;
  final String title;
  final List<EpisodeItem> allEpisodes;
  final List<int> seasons;
  final int? selectedSeason;
  final bool isLoading;
  final String? errorMessage;
  final bool isGridView;
  final bool isSortAscending;
  final int currentPage;
  final int episodesPerPage;
  final EpisodeFilterType filter;

  // Source & capabilities
  final List<OnlinestreamProvider> compatibleProviders;
  final OnlinestreamProvider? selectedProvider;
  final bool isDubbed;
  final bool canStreamOnline;
  final bool canSearchTorrents;
  final bool hasLocalFiles;

  const EpisodesState({
    required this.mediaId,
    required this.isTmdb,
    required this.title,
    this.allEpisodes = const [],
    this.seasons = const [],
    this.selectedSeason,
    this.isLoading = false,
    this.errorMessage,
    this.isGridView = true,
    this.isSortAscending = true,
    this.currentPage = 0,
    this.episodesPerPage = 30,
    this.filter = EpisodeFilterType.all,
    this.compatibleProviders = const [],
    this.selectedProvider,
    this.isDubbed = false,
    this.canStreamOnline = false,
    this.canSearchTorrents = true,
    this.hasLocalFiles = false,
  });

  /// Returns episodes after applying season, filter, and sorting
  List<EpisodeItem> get visibleEpisodes {
    var list = List<EpisodeItem>.from(allEpisodes);

    // Filter by season if multiple seasons exist
    if (selectedSeason != null) {
      list = list.where((e) => e.seasonNumber == selectedSeason).toList();
    }

    // Filter type
    switch (filter) {
      case EpisodeFilterType.localOnly:
        list = list.where((e) => e.isDownloaded).toList();
        break;
      case EpisodeFilterType.unwatched:
        list = list.where((e) => !e.isWatched).toList();
        break;
      case EpisodeFilterType.all:
        break;
    }

    // Sort
    list.sort((a, b) => isSortAscending
        ? a.number.compareTo(b.number)
        : b.number.compareTo(a.number));

    return list;
  }

  /// Paginated slice of visible episodes
  List<EpisodeItem> get pagedEpisodes {
    final list = visibleEpisodes;
    if (list.length <= episodesPerPage) return list;
    final startIndex = currentPage * episodesPerPage;
    if (startIndex >= list.length) return [];
    final endIndex = (startIndex + episodesPerPage).clamp(0, list.length);
    return list.sublist(startIndex, endIndex);
  }

  int get totalPages => (visibleEpisodes.length / episodesPerPage).ceil().clamp(1, 9999);

  EpisodesState copyWith({
    int? mediaId,
    bool? isTmdb,
    String? title,
    List<EpisodeItem>? allEpisodes,
    List<int>? seasons,
    int? selectedSeason,
    bool? isLoading,
    String? errorMessage,
    bool? isGridView,
    bool? isSortAscending,
    int? currentPage,
    int? episodesPerPage,
    EpisodeFilterType? filter,
    List<OnlinestreamProvider>? compatibleProviders,
    OnlinestreamProvider? selectedProvider,
    bool? isDubbed,
    bool? canStreamOnline,
    bool? canSearchTorrents,
    bool? hasLocalFiles,
  }) {
    return EpisodesState(
      mediaId: mediaId ?? this.mediaId,
      isTmdb: isTmdb ?? this.isTmdb,
      title: title ?? this.title,
      allEpisodes: allEpisodes ?? this.allEpisodes,
      seasons: seasons ?? this.seasons,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isGridView: isGridView ?? this.isGridView,
      isSortAscending: isSortAscending ?? this.isSortAscending,
      currentPage: currentPage ?? this.currentPage,
      episodesPerPage: episodesPerPage ?? this.episodesPerPage,
      filter: filter ?? this.filter,
      compatibleProviders: compatibleProviders ?? this.compatibleProviders,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      isDubbed: isDubbed ?? this.isDubbed,
      canStreamOnline: canStreamOnline ?? this.canStreamOnline,
      canSearchTorrents: canSearchTorrents ?? this.canSearchTorrents,
      hasLocalFiles: hasLocalFiles ?? this.hasLocalFiles,
    );
  }
}

class EpisodesNotifier extends Notifier<EpisodesState> {
  final EpisodesArgs args;

  EpisodesNotifier(this.args);

  @override
  EpisodesState build() {
    return EpisodesState(
      mediaId: args.mediaId,
      isTmdb: args.isTmdb,
      title: '',
      isLoading: true,
    );
  }

  TmdbShowDetails? _cachedTmdbDetails;
  AnimeDetails? _cachedAnimeDetails;
  AniZipData? _cachedAniZipData;

  void toggleLayout() => state = state.copyWith(isGridView: !state.isGridView);
  void toggleSort() => state = state.copyWith(isSortAscending: !state.isSortAscending, currentPage: 0);
  void setFilter(EpisodeFilterType filter) => state = state.copyWith(filter: filter, currentPage: 0);
  void setPage(int page) => state = state.copyWith(currentPage: page);

  Future<void> selectSeason(int season) async {
    state = state.copyWith(selectedSeason: season, currentPage: 0);
    if (state.isTmdb) {
      await _loadTmdbEpisodes(_cachedTmdbDetails);
    }
  }

  void selectProvider(OnlinestreamProvider? provider) {
    state = state.copyWith(selectedProvider: provider);
  }

  void toggleDubbed() {
    state = state.copyWith(isDubbed: !state.isDubbed);
  }

  /// Loads episodes universally based on media type (Anime vs TMDB Show)
  Future<void> load({
    AnimeDetails? animeDetails,
    AniZipData? aniZipData,
    TmdbShowDetails? tmdbDetails,
  }) async {
    if (animeDetails != null) _cachedAnimeDetails = animeDetails;
    if (aniZipData != null) _cachedAniZipData = aniZipData;
    if (tmdbDetails != null) _cachedTmdbDetails = tmdbDetails;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (state.isTmdb) {
        await _loadTmdbEpisodes(_cachedTmdbDetails);
      } else {
        await _loadAnimeEpisodes(_cachedAnimeDetails, _cachedAniZipData);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _loadTmdbEpisodes(TmdbShowDetails? details) async {
    final tmdbService = ref.read(tmdbServiceProvider);
    final isSpanish = ref.read(appLanguageProvider) == AppLanguage.es;
    final lang = isSpanish ? 'es-ES' : 'en-US';

    final resolvedDetails = details ??
        await tmdbService.getShowDetails(state.mediaId, language: lang);

    if (resolvedDetails == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'No details found');
      return;
    }
    _cachedTmdbDetails = resolvedDetails;

    // Check local shows library files
    final showsCollection = ref.read(showsCollectionProvider).asData?.value;
    final showEntry = showsCollection?.shows.firstWhereOrNull((s) => s.tmdbId == state.mediaId);
    final hasLocal = showEntry != null && (showEntry.files.isNotEmpty || showEntry.seasons.isNotEmpty);

    if (resolvedDetails.isMovie) {
      final localMovie = showEntry?.files.firstOrNull;
      final ep = EpisodeItem(
        id: 'tmdb_movie_${resolvedDetails.id}',
        number: 1,
        seasonNumber: 1,
        title: resolvedDetails.name,
        synopsis: resolvedDetails.overview,
        image: resolvedDetails.backdropPath ?? resolvedDetails.posterPath,
        airDate: resolvedDetails.firstAirDate,
        durationMinutes: resolvedDetails.runtime,
        rating: resolvedDetails.voteAverage,
        isDownloaded: localMovie != null,
        localFilePath: localMovie?.path,
      );
      state = state.copyWith(
        title: resolvedDetails.name,
        allEpisodes: [ep],
        seasons: const [],
        isLoading: false,
        canStreamOnline: false,
        canSearchTorrents: true,
        hasLocalFiles: hasLocal,
      );
      return;
    }

    // TV Series: Extract seasons
    final seasonsList = resolvedDetails.seasons
        .where((s) => s.seasonNumber > 0)
        .map((s) => s.seasonNumber)
        .toList();

    final currentSeason = state.selectedSeason ?? (seasonsList.isNotEmpty ? seasonsList.first : 1);

    final episodesList = await tmdbService.getSeasonEpisodes(
      state.mediaId,
      currentSeason,
      language: lang,
    );

    final seasonFiles = showEntry?.seasons[currentSeason] ?? const <ShowLocalFileItem>[];

    final items = <EpisodeItem>[];
    for (final tmdbEp in episodesList) {
      final localMatch = seasonFiles.firstWhereOrNull((f) => f.episode == tmdbEp.episodeNumber);

      items.add(EpisodeItem.fromTmdb(
        tmdbEp,
        isDownloaded: localMatch != null,
        localFilePath: localMatch?.path,
      ));
    }

    state = state.copyWith(
      title: resolvedDetails.name,
      allEpisodes: items,
      seasons: seasonsList,
      selectedSeason: currentSeason,
      isLoading: false,
      canStreamOnline: false,
      canSearchTorrents: true,
      hasLocalFiles: hasLocal,
    );
  }

  Future<void> _loadAnimeEpisodes(AnimeDetails? details, AniZipData? aniZipData) async {
    final repo = ref.read(repositoryProvider);
    final titleLang = ref.read(titleLanguageProvider);
    final animeTitle = details?.displayTitle(titleLang) ?? '';

    // Load local library entry for this anime
    LibraryEntryDetails? libraryEntry;
    try {
      libraryEntry = await repo.getAnimeLibraryEntry(state.mediaId);
    } catch (_) {}

    final hasLocal = libraryEntry?.episodes.any((e) => e.isDownloaded) ?? false;
    final totalEpisodes = details?.totalEpisodes ?? details?.episodes.length ?? aniZipData?.episodeCount ?? (libraryEntry?.episodes.length ?? 0);
    final maxEp = totalEpisodes > 0 ? totalEpisodes : 24;

    final items = <EpisodeItem>[];
    final watchedProgress = libraryEntry?.progress ?? 0;

    for (int epNum = 1; epNum <= maxEp; epNum++) {
      final zipEp = aniZipData?.episodes.firstWhereOrNull((e) => e.episodeNumber == epNum);
      final localMatch = libraryEntry?.episodes.firstWhereOrNull((e) => e.episodeNumber == epNum);
      final isWatched = watchedProgress >= epNum;

      items.add(EpisodeItem.fromAniZip(
        epNum,
        zipEp,
        fallbackTitle: localMatch?.displayTitle,
        fallbackImage: details?.coverImage,
        isWatched: isWatched,
        isDownloaded: localMatch?.isDownloaded ?? false,
        localFilePath: localMatch?.localFilePath,
      ));
    }

    // Load compatible anime onlinestream extensions
    List<OnlinestreamProvider> providers = [];
    try {
      providers = await repo.getOnlinestreamProviders();
    } catch (_) {}

    state = state.copyWith(
      title: animeTitle,
      allEpisodes: items,
      isLoading: false,
      compatibleProviders: providers,
      selectedProvider: providers.isNotEmpty ? (state.selectedProvider ?? providers.first) : null,
      canStreamOnline: providers.isNotEmpty,
      canSearchTorrents: true,
      hasLocalFiles: hasLocal,
    );
  }

  /// Launch universal playback
  Future<void> playEpisode(BuildContext context, EpisodeItem episode) async {
    final serverManager = ref.read(serverManagerProvider);
    final title = state.title.isNotEmpty ? state.title : 'Media';
    final episodeTitle = 'EP ${episode.number}. ${episode.title}';

    if (episode.isDownloaded && episode.localFilePath != null) {
      final streamUrl = 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(episode.localFilePath!)}';
      final fileName = episode.localFilePath!.split(RegExp(r'[/\\]')).last;

      Navigator.of(context, rootNavigator: true).push(
        VideoPlayerScreen.route(
          mediaId: state.mediaId,
          videoUrl: streamUrl,
          title: title,
          episodeTitle: episodeTitle,
          episodeNumber: episode.number,
          videoSource: 'Local • $fileName',
          isLocalFile: true,
        ),
      );
      return;
    }

    // Otherwise online stream for anime
    if (state.canStreamOnline) {
      Navigator.of(context, rootNavigator: true).push(
        VideoPlayerScreen.route(
          mediaId: state.mediaId,
          videoUrl: '',
          title: title,
          episodeTitle: episodeTitle,
          episodeNumber: episode.number,
          videoSource: state.selectedProvider?.name ?? 'Online',
          onlineStreamProvider: state.selectedProvider?.id,
          onlineStreamDubbed: state.isDubbed,
          onlineStreamServer: null,
        ),
      );
    }
  }
}

final episodesControllerProvider =
    NotifierProvider.autoDispose.family<EpisodesNotifier, EpisodesState, EpisodesArgs>(
  (args) => EpisodesNotifier(args),
);
