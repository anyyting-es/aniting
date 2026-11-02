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

enum EpisodeFilterType { all, localOnly, unwatched }

class EpisodesArgs {
  final int mediaId;
  final bool isTmdb;

  /// `'movie'` or `'tv'`. Only meaningful when [isTmdb] is true: TMDB uses
  /// different endpoints for both and the numeric ids overlap.
  final String mediaType;

  const EpisodesArgs({
    required this.mediaId,
    required this.isTmdb,
    this.mediaType = 'tv',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodesArgs &&
          runtimeType == other.runtimeType &&
          mediaId == other.mediaId &&
          isTmdb == other.isTmdb &&
          mediaType == other.mediaType;

  @override
  int get hashCode => mediaId.hashCode ^ isTmdb.hashCode ^ mediaType.hashCode;
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

  // TMDB playback context (only used when [isTmdb] is true).
  final String tmdbMediaType;
  final String? tmdbEnglishTitle;
  final int? tmdbYear;

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
    this.tmdbMediaType = 'tv',
    this.tmdbEnglishTitle,
    this.tmdbYear,
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
    list.sort(
      (a, b) => isSortAscending
          ? a.number.compareTo(b.number)
          : b.number.compareTo(a.number),
    );

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

  int get totalPages =>
      (visibleEpisodes.length / episodesPerPage).ceil().clamp(1, 9999);

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
    bool clearSelectedProvider = false,
    bool? isDubbed,
    bool? canStreamOnline,
    bool? canSearchTorrents,
    bool? hasLocalFiles,
    String? tmdbMediaType,
    String? tmdbEnglishTitle,
    int? tmdbYear,
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
      selectedProvider: clearSelectedProvider
          ? null
          : (selectedProvider ?? this.selectedProvider),
      isDubbed: isDubbed ?? this.isDubbed,
      canStreamOnline: canStreamOnline ?? this.canStreamOnline,
      canSearchTorrents: canSearchTorrents ?? this.canSearchTorrents,
      hasLocalFiles: hasLocalFiles ?? this.hasLocalFiles,
      tmdbMediaType: tmdbMediaType ?? this.tmdbMediaType,
      tmdbEnglishTitle: tmdbEnglishTitle ?? this.tmdbEnglishTitle,
      tmdbYear: tmdbYear ?? this.tmdbYear,
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
      tmdbMediaType: args.mediaType,
      title: '',
      isLoading: true,
    );
  }

  TmdbShowDetails? _cachedTmdbDetails;
  AnimeDetails? _cachedAnimeDetails;
  AniZipData? _cachedAniZipData;

  void toggleLayout() => state = state.copyWith(isGridView: !state.isGridView);
  void toggleSort() => state = state.copyWith(
    isSortAscending: !state.isSortAscending,
    currentPage: 0,
  );
  void setFilter(EpisodeFilterType filter) =>
      state = state.copyWith(filter: filter, currentPage: 0);
  void setPage(int page) => state = state.copyWith(currentPage: page);

  Future<void> selectSeason(int season) async {
    if (state.selectedSeason == season) return;
    state = state.copyWith(
      selectedSeason: season,
      currentPage: 0,
      isLoading: true,
      allEpisodes: const [],
    );
    if (!state.isTmdb) return;
    try {
      await _loadTmdbEpisodes(_cachedTmdbDetails);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
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
    if (tmdbDetails != null) {
      _cachedTmdbDetails = tmdbDetails;
      if (state.isTmdb) {
        state = state.copyWith(
          tmdbMediaType: tmdbDetails.isMovie ? 'movie' : 'tv',
        );
      }
    }

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
    final wantsMovie = state.tmdbMediaType.toLowerCase() == 'movie';

    var resolvedDetails =
        details ??
        await tmdbService.getShowDetails(
          state.mediaId,
          language: lang,
          isMovie: wantsMovie,
        );

    // A wrong media-type guess would query the other TMDB endpoint, and
    // numeric TMDB ids overlap between movies and shows. Retry once with the
    // opposite endpoint so we never show a different title.
    resolvedDetails ??= await tmdbService.getShowDetails(
      state.mediaId,
      language: lang,
      isMovie: !wantsMovie,
    );

    if (resolvedDetails == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No details found',
      );
      return;
    }
    _cachedTmdbDetails = resolvedDetails;

    final tmdbMediaType = resolvedDetails.isMovie ? 'movie' : 'tv';
    final tmdbEnglishTitle = resolvedDetails.originalName;
    int? tmdbYear;
    final airDate = resolvedDetails.firstAirDate;
    if (airDate != null && airDate.length >= 4) {
      tmdbYear = int.tryParse(airDate.substring(0, 4));
    }

    // Only providers that declare TMDB support can resolve these ids; anime
    // providers would query AniList with the TMDB id.
    List<OnlinestreamProvider> providers = [];
    try {
      providers =
          (await ref.read(repositoryProvider).getOnlinestreamProviders())
              .where((p) => p.supportsTmdb)
              .toList();
    } catch (_) {}
    final preferredProvider = state.selectedProvider;
    final selectedProvider = providers.isEmpty
        ? null
        : (preferredProvider != null &&
                  providers.any((p) => p.id == preferredProvider.id)
              ? preferredProvider
              : providers.first);

    // Check local shows library files
    final showsCollection = ref.read(showsCollectionProvider).asData?.value;
    final showEntry = showsCollection?.shows.firstWhereOrNull(
      (s) => s.tmdbId == state.mediaId,
    );
    final hasLocal =
        showEntry != null &&
        (showEntry.files.isNotEmpty || showEntry.seasons.isNotEmpty);

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
        compatibleProviders: providers,
        selectedProvider: selectedProvider,
        clearSelectedProvider: selectedProvider == null,
        canStreamOnline: providers.isNotEmpty,
        canSearchTorrents: true,
        hasLocalFiles: hasLocal,
        tmdbMediaType: tmdbMediaType,
        tmdbEnglishTitle: tmdbEnglishTitle,
        tmdbYear: tmdbYear,
      );
      return;
    }

    // TV Series: Extract and merge seasons from TMDB and local files
    final localSeasons =
        showEntry?.seasons.keys.where((s) => s >= 0).toList() ?? <int>[];
    final tmdbSeasons = resolvedDetails.seasons
        .where((s) => s.seasonNumber >= 0)
        .map((s) => s.seasonNumber)
        .toList();
    final seasonsSet = <int>{...tmdbSeasons, ...localSeasons};
    final seasonsList = seasonsSet.toList()..sort();
    if (seasonsList.isEmpty) {
      seasonsList.add(1);
    }

    // Prefer a regular season (1+) over specials (season 0) when opening a show.
    var defaultSeason = seasonsList.first;
    for (final season in seasonsList) {
      if (season >= 1) {
        defaultSeason = season;
        break;
      }
    }

    final currentSeason = state.selectedSeason ?? defaultSeason;

    final episodesList = await tmdbService.getSeasonEpisodes(
      state.mediaId,
      currentSeason,
      language: lang,
    );

    final seasonFiles =
        showEntry?.seasons[currentSeason] ?? const <ShowLocalFileItem>[];

    final items = <EpisodeItem>[];
    final matchedLocalPaths = <String>{};

    if (episodesList.isNotEmpty) {
      for (final tmdbEp in episodesList) {
        final localMatch = seasonFiles.firstWhereOrNull(
          (f) => f.episode == tmdbEp.episodeNumber,
        );
        if (localMatch != null) {
          matchedLocalPaths.add(localMatch.path);
        }

        items.add(
          EpisodeItem.fromTmdb(
            tmdbEp,
            isDownloaded: localMatch != null,
            localFilePath: localMatch?.path,
          ),
        );
      }

      // Add any local files for this season that were not matched to a TMDB episode
      for (final lf in seasonFiles) {
        if (!matchedLocalPaths.contains(lf.path)) {
          items.add(
            EpisodeItem(
              id: 'local_s_e_',
              number: lf.episode,
              seasonNumber: lf.season,
              title: lf.parsedTitle.isNotEmpty ? lf.parsedTitle : lf.name,
              synopsis: '',
              isDownloaded: true,
              localFilePath: lf.path,
            ),
          );
        }
      }
    } else {
      // TMDB has no episodes for this season (e.g. TMDB grouped 24 eps into Season 1, while user has Season 2)
      // Check if TMDB Season 1 has cumulative episodes that match this season's episodes
      List<TmdbEpisode>? tmdbS1Episodes;
      int previousEpisodesOffset = 0;
      if (currentSeason > 1 && showEntry != null) {
        for (int s = 1; s < currentSeason; s++) {
          previousEpisodesOffset += showEntry.seasons[s]?.length ?? 0;
        }
        if (previousEpisodesOffset > 0) {
          tmdbS1Episodes = await tmdbService.getSeasonEpisodes(
            state.mediaId,
            1,
            language: lang,
          );
        }
      }

      for (final lf in seasonFiles) {
        TmdbEpisode? matchedCumulative;
        if (tmdbS1Episodes != null && tmdbS1Episodes.isNotEmpty) {
          final targetCumulativeEp = previousEpisodesOffset + lf.episode;
          matchedCumulative = tmdbS1Episodes.firstWhereOrNull(
            (e) => e.episodeNumber == targetCumulativeEp,
          );
        }

        if (matchedCumulative != null) {
          items.add(
            EpisodeItem(
              id: 'tmdb_',
              number: lf.episode,
              seasonNumber: currentSeason,
              title: matchedCumulative.name,
              synopsis: matchedCumulative.overview,
              image: matchedCumulative.stillPath,
              airDate: matchedCumulative.airDate,
              durationMinutes: matchedCumulative.runtime,
              rating: matchedCumulative.voteAverage,
              isDownloaded: true,
              localFilePath: lf.path,
            ),
          );
        } else {
          items.add(
            EpisodeItem(
              id: 'local_s_e_',
              number: lf.episode,
              seasonNumber: currentSeason,
              title: lf.parsedTitle.isNotEmpty ? lf.parsedTitle : lf.name,
              synopsis: '',
              isDownloaded: true,
              localFilePath: lf.path,
            ),
          );
        }
      }
    }

    items.sort((a, b) => a.number.compareTo(b.number));

    state = state.copyWith(
      title: resolvedDetails.name,
      allEpisodes: items,
      seasons: seasonsList,
      selectedSeason: currentSeason,
      isLoading: false,
      compatibleProviders: providers,
      selectedProvider: selectedProvider,
      clearSelectedProvider: selectedProvider == null,
      canStreamOnline: providers.isNotEmpty,
      canSearchTorrents: true,
      hasLocalFiles: hasLocal,
      tmdbMediaType: tmdbMediaType,
      tmdbEnglishTitle: tmdbEnglishTitle,
      tmdbYear: tmdbYear,
    );
  }

  Future<void> _loadAnimeEpisodes(
    AnimeDetails? details,
    AniZipData? aniZipData,
  ) async {
    final repo = ref.read(repositoryProvider);
    final titleLang = ref.read(titleLanguageProvider);
    final animeTitle = details?.displayTitle(titleLang) ?? '';

    // Load local library entry for this anime
    LibraryEntryDetails? libraryEntry;
    try {
      libraryEntry = await repo.getAnimeLibraryEntry(state.mediaId);
    } catch (_) {}

    final hasLocal = libraryEntry?.episodes.any((e) => e.isDownloaded) ?? false;
    final totalEpisodes =
        details?.totalEpisodes ??
        details?.episodes.length ??
        aniZipData?.episodeCount ??
        (libraryEntry?.episodes.length ?? 0);
    final maxEp = totalEpisodes > 0 ? totalEpisodes : 24;

    final items = <EpisodeItem>[];
    final watchedProgress = libraryEntry?.progress ?? 0;

    for (int epNum = 1; epNum <= maxEp; epNum++) {
      final zipEp = aniZipData?.episodes.firstWhereOrNull(
        (e) => e.episodeNumber == epNum,
      );
      final localMatch = libraryEntry?.episodes.firstWhereOrNull(
        (e) => e.episodeNumber == epNum,
      );
      final isWatched = watchedProgress >= epNum;

      items.add(
        EpisodeItem.fromAniZip(
          epNum,
          zipEp,
          fallbackTitle: localMatch?.displayTitle,
          fallbackImage: details?.coverImage,
          isWatched: isWatched,
          isDownloaded: localMatch?.isDownloaded ?? false,
          localFilePath: localMatch?.localFilePath,
        ),
      );
    }

    // Load compatible anime onlinestream extensions
    List<OnlinestreamProvider> providers = [];
    try {
      providers = (await repo.getOnlinestreamProviders())
          .where((p) => p.supportsAnime)
          .toList();
    } catch (_) {}

    state = state.copyWith(
      title: animeTitle,
      allEpisodes: items,
      isLoading: false,
      compatibleProviders: providers,
      selectedProvider: providers.isNotEmpty
          ? (state.selectedProvider ?? providers.first)
          : null,
      canStreamOnline: providers.isNotEmpty,
      canSearchTorrents: true,
      hasLocalFiles: hasLocal,
    );
  }

  /// Launch universal playback.
  ///
  /// [provider] overrides the currently selected online provider for this
  /// playback (used by the episode source picker).
  Future<void> playEpisode(
    BuildContext context,
    EpisodeItem episode, {
    OnlinestreamProvider? provider,
  }) async {
    final serverManager = ref.read(serverManagerProvider);
    final title = state.title.isNotEmpty ? state.title : 'Media';
    final isTmdbMovie = state.isTmdb && state.tmdbMediaType == 'movie';
    final episodeTitle = isTmdbMovie
        ? (episode.title.isNotEmpty ? episode.title : title)
        : 'EP ${episode.number}. ${episode.title}';
    final onlineProvider = provider ?? state.selectedProvider;

    if (episode.isDownloaded && episode.localFilePath != null) {
      final streamUrl =
          'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(episode.localFilePath!)}';
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
          animeDetails: _cachedAnimeDetails,
          aniZipData: _cachedAniZipData,
          hideComments: state.isTmdb,
          isTmdbMedia: state.isTmdb,
          tmdbMediaType: state.tmdbMediaType,
          tmdbSeason: state.selectedSeason,
          tmdbEnglishTitle: state.tmdbEnglishTitle,
          tmdbYear: state.tmdbYear,
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
          videoSource: onlineProvider?.name ?? 'Online',
          onlineStreamProvider: onlineProvider?.id,
          onlineStreamDubbed: state.isDubbed,
          onlineStreamServer: null,
          animeDetails: _cachedAnimeDetails,
          aniZipData: _cachedAniZipData,
          hideComments: state.isTmdb,
          isTmdbMedia: state.isTmdb,
          tmdbMediaType: state.tmdbMediaType,
          tmdbSeason: state.selectedSeason,
          tmdbEnglishTitle: state.tmdbEnglishTitle,
          tmdbYear: state.tmdbYear,
        ),
      );
    }
  }
}

final episodesControllerProvider = NotifierProvider.autoDispose
    .family<EpisodesNotifier, EpisodesState, EpisodesArgs>(
      (args) => EpisodesNotifier(args),
    );
