import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/utils/synopsis_utils.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/core/preferences/streaming_preferences_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/media_servers/models/media_server_config.dart';
import 'package:seanime_app/core/media_servers/models/media_server_item.dart';
import 'package:seanime_app/core/media_servers/models/media_server_type.dart';
import 'package:seanime_app/core/media_servers/services/media_server_player_helper.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';
import 'package:seanime_app/presentation/providers/episodes_provider.dart';

import 'package:seanime_app/presentation/widgets/trailer_player_dialog.dart';

import 'desktop/desktop_action_bar.dart';
import 'desktop/desktop_cast_row.dart';
import 'desktop/desktop_episode_source_dialog.dart';
import 'desktop/desktop_episodes_tab.dart';
import 'desktop/desktop_header.dart';
import 'desktop/desktop_hero_banner.dart';
import 'desktop/desktop_season_switcher.dart';
import 'desktop/desktop_trailers_section.dart';

import 'package:seanime_app/presentation/widgets/episodes/episode_batch_action_bar.dart';

class AnimeDetailDesktopLayout extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeEntry? initialEntry;
  final AnimeDetails? details;
  final AniZipData? aniZipData;

  /// Pre-resolved logo URL (TMDB logo preferred, fallback to AniZip clearlogo).
  /// Set once by the parent before the first render – never changes.
  final String? resolvedLogoUrl;

  /// Pre-resolved banner/backdrop URL (TMDB backdrop preferred, fallback chain).
  /// Set once by the parent before the first render – never changes.
  final String? resolvedBannerUrl;

  /// True while the parent is still resolving a logo for this entry. The
  /// header reserves the logo slot during this time, avoiding layout jumps.
  final bool isLogoPending;
  final bool isLoading;
  final bool isLoadingAniZip;
  final bool isLocalMode;
  final bool hasLocalFiles;
  final AnimeDetailTab currentTab;
  final Object? heroTag;

  /// Optional media server source. When set the same detail layout renders
  /// Plex/Jellyfin metadata and plays episodes from the server instead of
  /// AniList/TMDB sources.
  final MediaServerItem? mediaServerShow;
  final MediaServerConfig? mediaServerServer;
  final List<MediaServerItem>? mediaServerEpisodes;

  final VoidCallback onToggleLocalMode;
  final ValueChanged<AnimeDetailTab> onTabChanged;
  final void Function(String mode)? onModeChanged;
  final void Function(String title) onOpenEditEntryModal;
  final Future<void> Function() onRetryAniZip;
  final Future<void> Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
    bool isDownloadMode,
    List<int>? initialSelectedEpisodes,
  })
  onOpenTorrentSelector;
  final VoidCallback onOpenDetailsModal;

  const AnimeDetailDesktopLayout({
    super.key,
    required this.mediaId,
    this.initialEntry,
    this.heroTag,
    required this.details,
    required this.aniZipData,
    this.resolvedLogoUrl,
    this.resolvedBannerUrl,
    this.isLogoPending = false,
    required this.isLoading,
    required this.isLoadingAniZip,
    required this.isLocalMode,
    required this.hasLocalFiles,
    required this.currentTab,
    required this.onToggleLocalMode,
    required this.onTabChanged,
    this.onModeChanged,
    required this.onOpenEditEntryModal,
    required this.onRetryAniZip,
    required this.onOpenTorrentSelector,
    required this.onOpenDetailsModal,
    this.mediaServerShow,
    this.mediaServerServer,
    this.mediaServerEpisodes,
  });

  bool get isMediaServerMode => mediaServerShow != null;

  @override
  ConsumerState<AnimeDetailDesktopLayout> createState() =>
      _AnimeDetailDesktopLayoutState();
}

class _AnimeDetailDesktopLayoutState
    extends ConsumerState<AnimeDetailDesktopLayout> {
  static const String _prefLastProviderKey = 'last_selected_online_provider';
  final ScrollController _scrollController = SmoothScrollController();
  final ValueNotifier<double> _scrollProgressNotifier = ValueNotifier<double>(
    0.0,
  );
  late final FocusNode _playFocusNode;

  List<OnlinestreamProvider> _providers = [];
  OnlinestreamProvider? _selectedProvider;
  bool _isDubbed = false;
  List<OnlinestreamEpisode> _onlineEpisodes = [];
  bool _isLoadingOnlineEpisodes = false;
  final int? _loadingEpisodeNumber = null;
  bool _isSynopsisExpanded = false;

  /// Currently selected season when the detail is backed by a media server.
  /// `null` means "use the first available season".
  int? _mediaServerSeason;

  String? _lastSynopsisText;
  double? _cachedExtraSynopsisHeight;

  bool get _isTmdb =>
      widget.details?.isTmdb ?? widget.initialEntry?.isTmdb ?? false;

  bool _tmdbLoadScheduled = false;

  EpisodesArgs get _tmdbArgs => EpisodesArgs(
        mediaId: widget.mediaId,
        isTmdb: true,
        mediaType:
            (widget.details?.format ?? widget.initialEntry?.format ?? '')
                        .toUpperCase() ==
                    'MOVIE'
                ? 'movie'
                : 'tv',
      );

  void _playTmdbEpisode(EpisodesState state, int number) {
    for (final ep in state.allEpisodes) {
      if (ep.number == number) {
        ref
            .read(episodesControllerProvider(_tmdbArgs).notifier)
            .playEpisode(context, ep);
        return;
      }
    }
  }

  double _calculateExtraSynopsisHeight(String text, double maxWidth) {
    if (text.isEmpty) return 0.0;
    if (_lastSynopsisText == text && _cachedExtraSynopsisHeight != null) {
      return _cachedExtraSynopsisHeight!;
    }
    const style = TextStyle(fontSize: 14.5, height: 1.40);
    final collapsedPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: maxWidth);

    final expandedPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final diff = expandedPainter.height - collapsedPainter.height;
    _lastSynopsisText = text;
    _cachedExtraSynopsisHeight = diff > 0 ? diff : 0.0;
    return _cachedExtraSynopsisHeight!;
  }

  @override
  void initState() {
    super.initState();
    _playFocusNode = FocusNode(debugLabel: 'desktop_play_button');
    _scrollController.addListener(_onScroll);

    final isTmdb =
        widget.details?.isTmdb ?? widget.initialEntry?.isTmdb ?? false;
    if (widget.isMediaServerMode) {
      final seasons = _mediaServerSeasons;
      _mediaServerSeason = seasons.isNotEmpty ? seasons.first : null;
    }
    if (!widget.isMediaServerMode && !isTmdb) {
      final repo = ref.read(repositoryProvider);
      final cachedProviders = repo
          .getCachedOnlinestreamProviders()
          ?.where((p) => p.supportsAnime)
          .toList();
      if (cachedProviders != null && cachedProviders.isNotEmpty) {
        _providers = cachedProviders;
        _selectedProvider = cachedProviders.first;
        final cachedEps = repo.getCachedOnlinestreamEpisodes(
          mediaId: widget.mediaId,
          provider: _selectedProvider!.id,
          dubbed: _isDubbed,
        );
        if (cachedEps != null && cachedEps.isNotEmpty) {
          _onlineEpisodes = cachedEps;
          _isLoadingOnlineEpisodes = false;
        }
      }
      _loadOnlineProviders();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final progress = (offset / 320.0).clamp(0.0, 1.0);
    if ((progress - _scrollProgressNotifier.value).abs() > 0.02 ||
        (offset <= 0 && _scrollProgressNotifier.value > 0) ||
        (offset >= 320 && _scrollProgressNotifier.value < 1.0)) {
      _scrollProgressNotifier.value = progress;
    }
  }

  @override
  void didUpdateWidget(covariant AnimeDetailDesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaServerShow?.id != oldWidget.mediaServerShow?.id) {
      final seasons = _mediaServerSeasons;
      _mediaServerSeason = seasons.isNotEmpty ? seasons.first : null;
    }
    if (!widget.isMediaServerMode &&
        widget.currentTab != oldWidget.currentTab &&
        widget.currentTab == AnimeDetailTab.online &&
        _onlineEpisodes.isEmpty &&
        !_isLoadingOnlineEpisodes) {
      _loadOnlineEpisodes();
    }
  }

  @override
  void dispose() {
    _playFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollProgressNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadOnlineProviders() async {
    final repo = ref.read(repositoryProvider);
    try {
      final list = (await repo.getOnlinestreamProviders())
          .where((p) => p.supportsAnime)
          .toList();
      OnlinestreamProvider? initialProvider;
      if (list.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedId = prefs.getString(_prefLastProviderKey);
          if (savedId != null && list.any((p) => p.id == savedId)) {
            initialProvider = list.firstWhere((p) => p.id == savedId);
          }
        } catch (_) {}
        initialProvider ??= list.first;
      }
      if (mounted) {
        setState(() {
          _providers = list;
          _selectedProvider = initialProvider;
        });
        if (_selectedProvider != null) {
          _loadOnlineEpisodes();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadOnlineEpisodes() async {
    if (_selectedProvider == null) return;
    final repo = ref.read(repositoryProvider);
    final cached = repo.getCachedOnlinestreamEpisodes(
      mediaId: widget.mediaId,
      provider: _selectedProvider!.id,
      dubbed: _isDubbed,
    );
    if (cached != null && cached.isNotEmpty && _onlineEpisodes.isEmpty) {
      setState(() {
        _onlineEpisodes = cached;
        _isLoadingOnlineEpisodes = false;
      });
    } else if (_onlineEpisodes.isEmpty) {
      setState(() {
        _isLoadingOnlineEpisodes = true;
      });
    }
    try {
      final list = await repo.getOnlinestreamEpisodes(
        mediaId: widget.mediaId,
        provider: _selectedProvider!.id,
        dubbed: _isDubbed,
      );
      if (mounted) {
        setState(() {
          _onlineEpisodes = list;
          _isLoadingOnlineEpisodes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading online episodes: $e');
      if (mounted) {
        setState(() {
          _isLoadingOnlineEpisodes = false;
        });
      }
    }
  }

  void _playOnlineEpisode(int epNum, String epTitle) {
    if (_selectedProvider == null) return;
    final titleLang = ref.read(titleLanguageProvider);
    final mediaTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
    final providerName = _selectedProvider?.name ?? 'Online';

    final savedProgress = ref
        .read(playbackProgressPreferencesProvider.notifier)
        .getProgress(widget.mediaId, epNum);
    Duration? startPos;
    if (savedProgress != null && savedProgress.positionMs > 0) {
      final fraction = savedProgress.durationMs > 0
          ? savedProgress.positionMs / savedProgress.durationMs
          : 0.0;
      if (fraction < 0.95) {
        startPos = Duration(milliseconds: savedProgress.positionMs);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        VideoPlayerScreen.route(
          mediaId: widget.mediaId,
          videoUrl: '',
          title: mediaTitle,
          episodeTitle: epTitle,
          episodeNumber: epNum,
          videoSource: providerName,
          startPosition: startPos,
          onlineStreamProvider: _selectedProvider?.id,
          onlineStreamDubbed: _isDubbed,
          onlineStreamServer: null,
          animeDetails: widget.details,
          aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
          resolvedLoadingLogoUrl: widget.resolvedLogoUrl,
          resolvedLoadingBannerUrl: widget.resolvedBannerUrl,
        ),
      );
    });
  }

  void _playLocalEpisode(DesktopEpisodeItemData ep, {String? filePath}) {
    final serverManager = ref.read(serverManagerProvider);
    final l10n = ref.read(translationsProvider);
    final titleLang = ref.read(titleLanguageProvider);
    final animeTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
    final targetPath = filePath ?? ep.localFilePath;
    final streamUrl = targetPath != null && targetPath.isNotEmpty
        ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(targetPath)}'
        : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${widget.mediaId}&episodeNumber=${ep.number}';
    final fileName = targetPath != null && targetPath.isNotEmpty
        ? targetPath.split(RegExp(r'[/\\]')).last
        : null;
    final sourceDesc = fileName != null
        ? 'Local • $fileName'
        : l10n.localLibrary;

    final savedProgress = ref
        .read(playbackProgressPreferencesProvider.notifier)
        .getProgress(widget.mediaId, ep.number);
    Duration? startPos;
    if (savedProgress != null && savedProgress.positionMs > 0) {
      final fraction = savedProgress.durationMs > 0
          ? savedProgress.positionMs / savedProgress.durationMs
          : 0.0;
      if (fraction < 0.95) {
        startPos = Duration(milliseconds: savedProgress.positionMs);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        VideoPlayerScreen.route(
          mediaId: widget.mediaId,
          videoUrl: streamUrl,
          title: animeTitle,
          episodeTitle: ep.title,
          episodeNumber: ep.number,
          videoSource: sourceDesc,
          startPosition: startPos,
          isLocalFile: true,
          animeDetails: widget.details,
          aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
        ),
      );
    });
  }

  // ─── Media server data helpers ─────────────────────────────────────────────

  /// Episodes that belong to the regular season list. Season 0 (specials) is
  /// hidden when the server also exposes regular seasons, matching how the
  /// anime detail groups specials apart from the main episodes.
  List<MediaServerItem> get _mediaServerEpisodePool {
    final episodes = widget.mediaServerEpisodes ?? const <MediaServerItem>[];
    final hasRegularSeason = episodes.any((ep) => (ep.seasonNumber ?? 1) > 0);
    if (!hasRegularSeason) return episodes.toList();
    return episodes.where((ep) => (ep.seasonNumber ?? 1) > 0).toList();
  }

  List<int> get _mediaServerSeasons {
    final episodes = _mediaServerEpisodePool;
    final seasons = <int>{for (final ep in episodes) ep.seasonNumber ?? 1};
    final sorted = seasons.toList()..sort();
    return sorted;
  }

  int get _activeMediaServerSeason {
    final seasons = _mediaServerSeasons;
    if (seasons.isEmpty) return 1;
    final selected = _mediaServerSeason;
    if (selected != null && seasons.contains(selected)) return selected;
    return seasons.first;
  }

  List<MediaServerItem> get _visibleMediaServerEpisodes {
    final episodes = _mediaServerEpisodePool;
    final seasons = _mediaServerSeasons;
    final filtered = seasons.length <= 1
        ? episodes.toList()
        : episodes
              .where((ep) => (ep.seasonNumber ?? 1) == _activeMediaServerSeason)
              .toList();
    filtered.sort((a, b) {
      final seasonCompare = (a.seasonNumber ?? 1).compareTo(
        b.seasonNumber ?? 1,
      );
      if (seasonCompare != 0) return seasonCompare;
      return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
    });
    return filtered;
  }

  /// Builds an [AniZipData] view over the episodes of the selected season so
  /// the shared episode row can render media-server content with the exact
  /// same layout as an anime entry.
  AniZipData _mediaServerAniZip(List<MediaServerItem> episodes) {
    final show = widget.mediaServerShow;
    return AniZipData(
      titles: {if (show != null) 'en': show.title},
      episodeCount: episodes.length,
      episodes: [
        for (var i = 0; i < episodes.length; i++)
          AniZipEpisode(
            episode: '${i + 1}',
            episodeNumber: i + 1,
            seasonNumber: episodes[i].seasonNumber,
            titleMap: {
              if (episodes[i].title.isNotEmpty) 'en': episodes[i].title,
            },
            image: episodes[i].thumbUrl ?? show?.thumbUrl,
            runtime: episodes[i].durationMs != null
                ? (episodes[i].durationMs! / 60000).round()
                : null,
            overview: episodes[i].overview,
            isSpecial: false,
          ),
      ],
    );
  }

  String? get _mediaServerShareUrl {
    final show = widget.mediaServerShow;
    final server = widget.mediaServerServer;
    if (show == null || server == null) return null;
    final rawBase = server.url;
    final base = rawBase.endsWith('/')
        ? rawBase.substring(0, rawBase.length - 1)
        : rawBase;
    if (server.type == MediaServerType.plex) {
      return '$base/web/index.html#!/server/${server.name}/details'
          '?key=${Uri.encodeComponent('/library/metadata/${show.id}')}';
    }
    return '$base/web/index.html#!/details?id=${show.id}';
  }

  void _playMediaServerItem(MediaServerItem item) {
    final server = widget.mediaServerServer;
    if (server == null) return;
    MediaServerPlayerHelper.playDirect(
      context: context,
      item: item,
      server: server,
      show: widget.mediaServerShow,
      showEpisodes: widget.mediaServerEpisodes,
    );
  }

  void _playNextMediaServerEpisode() {
    final episodes = _visibleMediaServerEpisodes;
    if (episodes.isEmpty) {
      final show = widget.mediaServerShow;
      if (show != null) _playMediaServerItem(show);
      return;
    }
    MediaServerItem? target;
    for (final ep in episodes) {
      if (ep.progress > 0.02 && ep.progress < 0.95) {
        target = ep;
        break;
      }
    }
    target ??= episodes.where((ep) => !ep.isWatched).firstOrNull;
    target ??= episodes.first;
    _playMediaServerItem(target);
  }

  void _onEpisodeClicked(DesktopEpisodeItemData ep) {
    if (widget.isMediaServerMode) {
      final episodes = _visibleMediaServerEpisodes;
      final index = ep.number - 1;
      if (index >= 0 && index < episodes.length) {
        _playMediaServerItem(episodes[index]);
      }
      return;
    }

    final titleLang = ref.read(titleLanguageProvider);
    final animeTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';

    final repo = ref.read(repositoryProvider);
    final cachedEntry = repo.getCachedAnimeLibraryEntry(widget.mediaId);
    final localEp = cachedEntry?.episodes.cast<LibraryEpisode?>().firstWhere(
      (e) => e?.episodeNumber == ep.number,
      orElse: () => null,
    );
    final localPath = ep.localFilePath ?? localEp?.localFilePath;
    final hasLocal =
        ep.isDownloaded || (localPath != null && localPath.isNotEmpty);

    showDesktopEpisodeSourceDialog(
      context,
      episode: localPath != null
          ? ep.copyWith(localFilePath: localPath, isDownloaded: true)
          : ep,
      animeTitle: animeTitle,
      providers: _providers,
      selectedProvider: _selectedProvider,
      isDubbed: _isDubbed,
      onProviderChanged: (p) {
        if (p != null) {
          setState(() => _selectedProvider = p);
          SharedPreferences.getInstance().then(
            (prefs) => prefs.setString(_prefLastProviderKey, p.id),
          );
          _loadOnlineEpisodes();
        }
      },
      onToggleDubbed: () {
        setState(() => _isDubbed = !_isDubbed);
        _loadOnlineEpisodes();
      },
      onPlayOnline: () => _playOnlineEpisode(ep.number, ep.title),
      onPlayTorrent: () => widget.onOpenTorrentSelector(
        episodeNumber: ep.number,
        episodeTitle: ep.title,
        aniDBEpisode: ep.aniDBEpisode,
      ),
      onPlayLocal: hasLocal
          ? () => _playLocalEpisode(ep, filePath: localPath)
          : null,
    );
  }

  /// Reuses the TMDB episodes controller so the hero play button picks the
  /// same provider, season and metadata as the episode cards.
  Future<void> _playTmdbNext(int progress) async {
    final isMovie =
        (widget.details?.format ?? widget.initialEntry?.format ?? '')
            .toUpperCase() ==
        'MOVIE';
    final args = EpisodesArgs(
      mediaId: widget.mediaId,
      isTmdb: true,
      mediaType: isMovie ? 'movie' : 'tv',
    );
    final provider = episodesControllerProvider(args);
    // Keep the auto-dispose controller alive while episodes/providers load.
    final link = ref.listenManual(provider, (_, _) {});
    try {
      var state = ref.read(provider);
      if (state.allEpisodes.isEmpty) {
        await ref.read(provider.notifier).load(animeDetails: widget.details);
        state = ref.read(provider);
      }
      if (!mounted || state.allEpisodes.isEmpty) return;

      final localProgress =
          OfflineLibraryService.instance
              .getAnimeEntry(widget.mediaId)
              ?.progress ??
          0;
      final startFrom = progress > 0 ? progress : localProgress;
      final target = startFrom > 0 ? startFrom + 1 : 1;

      var episode = state.allEpisodes.first;
      for (final ep in state.allEpisodes) {
        if (ep.number == target) {
          episode = ep;
          break;
        }
      }

      await ref.read(provider.notifier).playEpisode(context, episode);
    } finally {
      link.close();
    }
  }

  Future<void> _handlePlayNext(int progress) async {
    if (widget.isMediaServerMode) {
      _playNextMediaServerEpisode();
      return;
    }

    if (_isTmdb) {
      await _playTmdbNext(progress);
      return;
    }

    final nextEp = progress > 0 ? progress + 1 : 1;
    final l10n = ref.read(translationsProvider);

    // 1. FAST-PATH: If file exists on PC in local library, stream directly from disk (0ms)
    try {
      final repo = ref.read(repositoryProvider);
      final entry = await repo.getAnimeLibraryEntry(widget.mediaId);
      final localEp = entry?.episodes.cast<LibraryEpisode?>().firstWhere(
        (e) => e?.episodeNumber == nextEp,
        orElse: () => null,
      );
      if (localEp != null && mounted) {
        final serverManager = ref.read(serverManagerProvider);
        final titleLang = ref.read(titleLanguageProvider);
        final animeTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
        final streamUrl =
            localEp.localFilePath != null && localEp.localFilePath!.isNotEmpty
            ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(localEp.localFilePath!)}'
            : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${widget.mediaId}&episodeNumber=${localEp.episodeNumber}';
        final fileName = localEp.localFilePath?.split(RegExp(r'[/\\]')).last;

        final savedProgress = ref
            .read(playbackProgressPreferencesProvider.notifier)
            .getProgress(widget.mediaId, nextEp);
        Duration? startPos;
        if (savedProgress != null && savedProgress.positionMs > 0) {
          final fraction = savedProgress.durationMs > 0
              ? savedProgress.positionMs / savedProgress.durationMs
              : 0.0;
          if (fraction < 0.95) {
            startPos = Duration(milliseconds: savedProgress.positionMs);
          }
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).push(
            VideoPlayerScreen.route(
              mediaId: widget.mediaId,
              videoUrl: streamUrl,
              title: animeTitle,
              episodeTitle: localEp.displayTitle.isNotEmpty
                  ? localEp.displayTitle
                  : l10n.episodeNumber(nextEp),
              episodeNumber: nextEp,
              videoSource: fileName != null
                  ? 'Local • $fileName'
                  : l10n.localLibrary,
              startPosition: startPos,
              isLocalFile: true,
              animeDetails: widget.details,
              aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
            ),
          );
        });
        return;
      }
    } catch (_) {}

    if (widget.currentTab == AnimeDetailTab.torrent) {
      widget.onOpenTorrentSelector(
        episodeNumber: nextEp,
        episodeTitle: l10n.episodeNumber(nextEp),
      );
    } else {
      _playOnlineEpisode(nextEp, l10n.episodeNumber(nextEp));
    }
  }

  String _cleanHtml(String? html) {
    return cleanSynopsis(html);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final torrentEnabled = ref.watch(
      streamingPreferencesProvider.select((s) => s.torrentStreamingEnabled),
    );
    final onlineEnabled = ref.watch(
      streamingPreferencesProvider.select((s) => s.onlineStreamingEnabled),
    );
    final isTmdb =
        widget.details?.isTmdb ?? widget.initialEntry?.isTmdb ?? false;

    final title =
        widget.details?.displayTitle(titleLang) ??
        widget.initialEntry?.displayTitle(titleLang) ??
        (widget.details?.title.isNotEmpty == true &&
                widget.details?.title != l10n.noTitle
            ? widget.details!.title
            : null) ??
        widget.initialEntry?.title ??
        l10n.loading;

    final coverUrl =
        widget.initialEntry?.coverImage ?? widget.details?.coverImage;

    // ─── Assets resolved ONCE by the parent – never change after first frame ───
    // Logo: TMDB logo (preferred) or AniZip clearlogo
    final clearLogo = widget.resolvedLogoUrl;
    // Banner: TMDB backdrop (preferred) or AniZip fanart/banner or AniList banner or cover
    final bannerUrl = widget.resolvedBannerUrl ?? coverUrl;
    final isBlurredCover = bannerUrl == coverUrl && coverUrl != null;

    final score = widget.details?.score ?? widget.initialEntry?.score;
    final format =
        widget.details?.format ?? widget.initialEntry?.format ?? 'TV';
    final isMovie = format.toUpperCase() == 'MOVIE';

    final tmdbState = isTmdb && !isMovie
        ? ref.watch(episodesControllerProvider(_tmdbArgs))
        : null;
    if (isTmdb && !isMovie && !_tmdbLoadScheduled) {
      _tmdbLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(episodesControllerProvider(_tmdbArgs).notifier)
            .load(animeDetails: widget.details);
      });
    }
    final status = widget.details?.status ?? widget.initialEntry?.status;

    final year =
        widget.details?.seasonYear ??
        widget.details?.rawMedia?['startDate']?['year'] ??
        widget.initialEntry?.year;
    final season = widget.details?.season ?? widget.initialEntry?.season;
    final seasonYearStr = (season != null && year != null)
        ? '${l10n.formatSeason(season)} $year'.toUpperCase()
        : (year != null ? '$year' : '');

    final raw = widget.details?.rawMedia ?? {};
    final startDateMap = raw['startDate'] as Map?;
    final startMonth = startDateMap?['month'] as int?;
    final startYear = (startDateMap?['year'] as int?) ?? year;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthName =
        (startMonth != null && startMonth >= 1 && startMonth <= 12)
        ? months[startMonth - 1]
        : null;
    final dateStr = (monthName != null && startYear != null)
        ? '$monthName $startYear'
        : (startYear != null ? '$startYear' : '');
    final seasonStr = season != null ? l10n.formatSeason(season) : null;
    final dateSeasonStr = (dateStr.isNotEmpty && seasonStr != null)
        ? '$dateStr - $seasonStr'
        : (dateStr.isNotEmpty ? dateStr : seasonYearStr);

    final romaji =
        widget.details?.romajiTitle ?? widget.initialEntry?.romajiTitle;
    final english =
        widget.details?.englishTitle ?? widget.initialEntry?.englishTitle;
    final native =
        widget.details?.nativeTitle ?? widget.initialEntry?.nativeTitle;
    final subtitle = (romaji != null && romaji.isNotEmpty && romaji != title)
        ? romaji
        : ((english != null && english.isNotEmpty && english != title)
              ? english
              : ((native != null && native.isNotEmpty && native != title)
                    ? native
                    : null));

    final liveCollectionEntry = ref.watch(
      animeCollectionProvider.select(
        (asyncVal) => asyncVal.whenOrNull(
          data: (entries) =>
              entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        ),
      ),
    );

    final userStatus =
        liveCollectionEntry?.status ?? widget.details?.userStatus;

    final trailer = raw['trailer'] as Map<String, dynamic>?;
    final trailerId = trailer?['id'] as String?;
    final trailerSite = trailer?['site'] as String?;
    final hasTrailer = trailerId != null && trailerId.isNotEmpty;
    final idMal = raw['idMal'] as int?;

    final duration = raw['duration'] as int?;
    final rawTotalEpisodes =
        widget.details?.totalEpisodes ?? widget.initialEntry?.totalEpisodes;
    final studio = widget.details?.studio ?? '';

    final rawProgress =
        liveCollectionEntry?.progress ??
        widget.details?.progress ??
        widget.initialEntry?.progress ??
        0;

    // Media server sources expose their own seasons/episodes/progress.
    final mediaServerEpisodes = _visibleMediaServerEpisodes;
    final mediaServerSeasons = _mediaServerSeasons;
    final isMediaServer = widget.isMediaServerMode;
    // For media servers, the show-level count comes from the server metadata
    // so the header never flashes/changes while episodes are loading.
    final totalEpisodes = isMediaServer
        ? (widget.details?.totalEpisodes ?? mediaServerEpisodes.length)
        : rawTotalEpisodes;
    final progress = isMediaServer
        ? mediaServerEpisodes.where((ep) => ep.isWatched).length
        : rawProgress;
    final mediaServerAniZip = isMediaServer
        ? _mediaServerAniZip(mediaServerEpisodes)
        : null;

    final description = _cleanHtml(
      widget.details?.description ?? widget.initialEntry?.description,
    );

    final libraryEntryAsync = widget.isMediaServerMode
        ? const AsyncValue<LibraryEntryDetails?>.data(null)
        : ref.watch(animeLibraryEntryProvider(widget.mediaId));
    final hasLibFiles =
        libraryEntryAsync.asData?.value != null &&
        (libraryEntryAsync.asData!.value!.hasLibraryData ||
            libraryEntryAsync.asData!.value!.episodes.any(
              (e) => e.isDownloaded,
            ));
    final effectiveHasLocal = widget.hasLocalFiles || hasLibFiles;
    final downloadedMap = {
      for (final ep
          in (libraryEntryAsync.asData?.value?.episodes ?? <LibraryEpisode>[]))
        if (ep.isDownloaded) ep.episodeNumber: ep.localFilePath,
    };
    final allEpNumbers =
        (mediaServerAniZip != null && mediaServerAniZip.episodes.isNotEmpty)
        ? mediaServerAniZip.episodes.map((e) => e.episodeNumber).toList()
        : ((widget.aniZipData != null && widget.aniZipData!.episodes.isNotEmpty)
              ? widget.aniZipData!.episodes.map((e) => e.episodeNumber).toList()
              : List.generate(totalEpisodes ?? 0, (i) => i + 1));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ─── 1. Full-Page Cinematic Backdrop ───
          DesktopHeroBanner(
            bannerUrl: bannerUrl,
            isBlurredCover: isBlurredCover,
            scrollProgressListenable: _scrollProgressNotifier,
            scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
            isFullPage: true,
          ),

          // ─── 2. Main Scrollable Container (Full width, pushed down to showcase fanart) ───
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Precision calculation:
                // Aligns the bottom edge of the Episode cards row directly with
                // the bottom line of the app window on the initial fold, giving the top
                // fanart breathing room and keeping Cast strictly off-screen until scrolled.
                final baseTopSpacing = (constraints.maxHeight - 610.0).clamp(
                  40.0,
                  380.0,
                );
                final extraHeight = _isSynopsisExpanded
                    ? _calculateExtraSynopsisHeight(description, 740.0)
                    : 0.0;
                final effectiveTopSpacing = math.max(
                  16.0,
                  baseTopSpacing - extraHeight,
                );

                return SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Navigation Bar (Back button)
                        Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 12),
                          child: M3EIconButton(
                            decoration: M3EIconButtonDecoration(
                              backgroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.white.withValues(alpha: 0.24);
                                }
                                if (states.contains(WidgetState.hovered) ||
                                    states.contains(WidgetState.focused)) {
                                  return Colors.white.withValues(alpha: 0.18);
                                }
                                return Colors.white.withValues(alpha: 0.10);
                              }),
                              foregroundColor: WidgetStateProperty.all(
                                Colors.white,
                              ),
                              side: WidgetStateProperty.all(
                                BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 1.0,
                                ),
                              ),
                            ),
                            size: M3EIconButtonSize.sm,
                            icon: Icon(
                              AppIcons.arrowLeft(iconPack),
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),

                        // Breathing space pushing hero header, actions, and episode row down
                        // Smoothly decreases when synopsis expands so that header flows upwards instead of pushing actions down
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          height: effectiveTopSpacing,
                        ),

                        // ─── Top Hero Section (Logo, Badges, Genres, Synopsis) ───
                        DesktopHeader(
                          key: const ValueKey('desktop_header_ready'),
                          clearlogoUrl: clearLogo,
                          isLogoPending: widget.isLogoPending,
                          isTmdb: isTmdb,
                          seasonYearStr: seasonYearStr,
                          dateSeasonStr: dateSeasonStr,
                          title: title,
                          subtitle: subtitle,
                          genres:
                              widget.details?.genres ??
                              widget.initialEntry?.genres ??
                              [],
                          description: description,
                          isSynopsisExpanded: _isSynopsisExpanded,
                          onToggleSynopsisExpanded: (val) =>
                              setState(() => _isSynopsisExpanded = val),
                          format: format,
                          status: status,
                          userStatus: userStatus,
                          progress: progress,
                          score: score,
                          studio: studio,
                          totalEpisodes: totalEpisodes,
                          duration: duration,
                          onEditStatus: () =>
                              widget.onOpenEditEntryModal(title),
                        ),

                        const SizedBox(height: 14),

                        // ─── Action Bar (Play, Edit, Share, Trailer, Links & Online/Torrent Toggle) ───
                        DesktopActionBar(
                          playFocusNode: _playFocusNode,
                          mediaId: widget.mediaId,
                          title: title,
                          progress: progress,
                          idMal: idMal,
                          trailerId: trailerId,
                          trailerSite: trailerSite,
                          hasTrailer: hasTrailer,
                          currentTab: widget.currentTab,
                          onlineEnabled: isMediaServer ? false : onlineEnabled,
                          torrentEnabled: isMediaServer
                              ? false
                              : torrentEnabled,
                          isTmdb: isMediaServer ? false : isTmdb,
                          isMovie: isMovie,
                          userStatus: userStatus,
                          totalEpisodes: totalEpisodes,
                          shareUrl: isMediaServer ? _mediaServerShareUrl : null,
                          showTracking: !isMediaServer,
                          onPlayNext: () => _handlePlayNext(progress),
                          onOpenEditEntryModal: widget.onOpenEditEntryModal,
                          onTabChanged: widget.onTabChanged,
                          isLocalMode: widget.isLocalMode,
                          hasLocalFiles: effectiveHasLocal,
                          onToggleLocalMode: widget.onToggleLocalMode,
                          onModeChanged: widget.onModeChanged,
                          onPlayFocused: () {
                            if (_scrollController.hasClients &&
                                _scrollController.offset > 0) {
                              _scrollController.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          onDownload: isMediaServer
                              ? null
                              : () {
                                  final totalEps =
                                      widget.details?.totalEpisodes ??
                                      widget.initialEntry?.totalEpisodes;
                                  final nextEp = (progress + 1).clamp(
                                    1,
                                    totalEps ?? (progress + 1),
                                  );
                                  final defaultEpTitle = l10n.episodeNumber(
                                    nextEp,
                                  );
                                  widget.onOpenTorrentSelector(
                                    episodeNumber: nextEp,
                                    episodeTitle: defaultEpTitle,
                                    isDownloadMode: true,
                                  );
                                },
                        ),

                        // ─── Episodes Section (Single horizontal row directly underneath actions, skipped for movies) ───
                        if (!isMovie) ...[
                          const SizedBox(height: 16),
                          if (isMediaServer) ...[
                            // Keep the season row height stable while episodes
                            // are still loading so the section does not jump
                            // when the chips appear.
                            if (mediaServerSeasons.isNotEmpty)
                              DesktopSeasonSwitcher(
                                seasons: mediaServerSeasons,
                                selectedSeason: _activeMediaServerSeason,
                                onSeasonChanged: (season) =>
                                    setState(() => _mediaServerSeason = season),
                              )
                            else
                              const SizedBox(height: 40),
                            const SizedBox(height: 14),
                          ],
                          if (isTmdb) ...[
                            if (tmdbState != null) ...[
                              AnimatedSize(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topLeft,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (tmdbState.seasons.length > 1) ...[
                                      DesktopSeasonSwitcher(
                                        seasons: tmdbState.seasons,
                                        selectedSeason:
                                            tmdbState.selectedSeason ?? 1,
                                        onSeasonChanged: (season) => ref
                                            .read(
                                              episodesControllerProvider(
                                                _tmdbArgs,
                                              ).notifier,
                                            )
                                            .selectSeason(season),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  ],
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 320),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0.03, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  );
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    'tmdb_episodes_${tmdbState.selectedSeason}_${tmdbState.isLoading}',
                                  ),
                                  child: DesktopEpisodesTab(
                                mediaId: widget.mediaId,
                                details: widget.details,
                                aniZipData: null,
                                isLoadingAniZip: tmdbState.isLoading,
                                progress: OfflineLibraryService
                                        .instance
                                        .getAnimeEntry(widget.mediaId)
                                        ?.progress ??
                                    0,
                                isLocalMode: false,
                                currentTab: AnimeDetailTab.online,
                                providers: tmdbState.compatibleProviders,
                                selectedProvider: tmdbState.selectedProvider,
                                isDubbed: tmdbState.isDubbed,
                                onlineEpisodes:
                                    const <OnlinestreamEpisode>[],
                                loadingEpisodeNumber: null,
                                fallbackCoverImage: coverUrl,
                                onProviderChanged: (provider) => ref
                                    .read(
                                      episodesControllerProvider(_tmdbArgs)
                                          .notifier,
                                    )
                                    .selectProvider(provider),
                                onToggleDubbed: () => ref
                                    .read(
                                      episodesControllerProvider(_tmdbArgs)
                                          .notifier,
                                    )
                                    .toggleDubbed(),
                                onEpisodeClicked: (ep) =>
                                    _playTmdbEpisode(tmdbState, ep.number),
                                onToggleLocalMode: () {},
                                onTabChanged: (_) {},
                                onOpenTorrentSelector:
                                    widget.onOpenTorrentSelector,
                                isTmdb: true,
                                tmdbEpisodes: tmdbState.visibleEpisodes,
                              ),
                                ),
                              ),
                            ],
                          ] else
                            DesktopEpisodesTab(
                              mediaId: widget.mediaId,
                              details: widget.details,
                              aniZipData:
                                  mediaServerAniZip ?? widget.aniZipData,
                              isLoadingAniZip: widget.isLoadingAniZip,
                              progress: progress,
                              isLocalMode: isMediaServer
                                  ? false
                                  : widget.isLocalMode,
                              currentTab: isMediaServer
                                  ? AnimeDetailTab.online
                                  : widget.currentTab,
                              providers: _providers,
                              selectedProvider: _selectedProvider,
                              isDubbed: _isDubbed,
                              onlineEpisodes: _onlineEpisodes,
                              isLoadingOnlineEpisodes: _isLoadingOnlineEpisodes,
                              loadingEpisodeNumber: _loadingEpisodeNumber,
                              fallbackCoverImage: coverUrl,
                              onProviderChanged: (p) {
                                if (p != null) {
                                  setState(() => _selectedProvider = p);
                                  SharedPreferences.getInstance().then(
                                    (prefs) => prefs.setString(
                                      _prefLastProviderKey,
                                      p.id,
                                    ),
                                  );
                                  _loadOnlineEpisodes();
                                }
                              },
                              onToggleDubbed: () {
                                setState(() => _isDubbed = !_isDubbed);
                                _loadOnlineEpisodes();
                              },
                              onEpisodeClicked: _onEpisodeClicked,
                              onToggleLocalMode: widget.onToggleLocalMode,
                              onTabChanged: widget.onTabChanged,
                              isExternalSource: isMediaServer,
                              onMoveUpToPlay: () =>
                                  _playFocusNode.requestFocus(),
                              onOpenTorrentSelector:
                                  widget.onOpenTorrentSelector,
                            ),
                        ],

                        // ─── Cast / Characters Section (Directly underneath episodes) ───
                        () {
                          final anilistCharacters =
                              widget.details?.characters ?? const [];
                          final charList = anilistCharacters.isNotEmpty
                              ? anilistCharacters
                              : ((widget.details?.rawMedia?['credits']?['cast']
                                      as List<dynamic>?) ??
                                  const []);
                          if (charList.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: DesktopCastRow(
                              characters: charList,
                              isTmdb: isTmdb,
                              mediaId: widget.mediaId,
                              bannerUrl: bannerUrl,
                            ),
                          );
                        }(),

                        // ─── Trailers & Videos Section (Directly underneath cast) ───
                        if (hasTrailer)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: DesktopTrailersSection(
                              trailerId: trailerId,
                              trailerSite: trailerSite,
                              onTap: () => TrailerPlayerDialog.show(
                                context,
                                trailerId: trailerId,
                                trailerSite: trailerSite,
                                title: title,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // ─── 4. Floating Batch Action Bar ───
          if (!isTmdb)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: EpisodeBatchActionBar(
                  mediaId: widget.mediaId,
                  details: widget.details,
                  allEpisodeNumbers: allEpNumbers,
                  downloadedMap: downloadedMap,
                  isOnlineMode: widget.currentTab == AnimeDetailTab.online,
                  onlineProvider: _selectedProvider,
                  isDubbed: _isDubbed,
                  onDownloadTorrents: (toDownload) {
                    final firstEp = toDownload.first;
                    widget.onOpenTorrentSelector(
                      episodeNumber: firstEp,
                      episodeTitle: 'Ep. $firstEp',
                      isDownloadMode: true,
                      initialSelectedEpisodes: toDownload,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
