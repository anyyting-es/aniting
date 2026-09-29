import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/episode_view_mode_provider.dart';
import 'package:seanime_app/core/preferences/streaming_preferences_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/anizip_episode_list.dart';
import 'package:seanime_app/presentation/widgets/local_library_view.dart';
import 'package:seanime_app/presentation/widgets/online_stream_view.dart';

enum AnimeDetailTab { online, torrent }

class AnimeDetailMobileLayout extends ConsumerWidget {
  final int mediaId;
  final AnimeEntry? initialEntry;
  final AnimeDetails? details;
  final AniZipData? aniZipData;
  final bool isLoading;
  final bool isLoadingAniZip;
  final bool isLocalMode;
  final bool hasLocalFiles;
  final AnimeDetailTab currentTab;
  final ScrollController scrollController;
  final AnimationController bannerAnimController;
  final Animation<double> bannerScaleAnimation;
  final Animation<double> bannerTranslateAnimation;

  final VoidCallback onToggleLocalMode;
  final ValueChanged<AnimeDetailTab> onTabChanged;
  final void Function(String title) onOpenEditEntryModal;
  final Future<void> Function() onRetryAniZip;
  final Future<void> Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  }) onOpenTorrentSelector;
  final VoidCallback onOpenDetailsModal;

  const AnimeDetailMobileLayout({
    super.key,
    required this.mediaId,
    this.initialEntry,
    required this.details,
    required this.aniZipData,
    required this.isLoading,
    required this.isLoadingAniZip,
    required this.isLocalMode,
    required this.hasLocalFiles,
    required this.currentTab,
    required this.scrollController,
    required this.bannerAnimController,
    required this.bannerScaleAnimation,
    required this.bannerTranslateAnimation,
    required this.onToggleLocalMode,
    required this.onTabChanged,
    required this.onOpenEditEntryModal,
    required this.onRetryAniZip,
    required this.onOpenTorrentSelector,
    required this.onOpenDetailsModal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.themeColors;
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    final titleLang = ref.watch(titleLanguageProvider);
    final streamingPrefs = ref.watch(streamingPreferencesProvider);
    final torrentEnabled = streamingPrefs.torrentStreamingEnabled;
    final onlineEnabled = streamingPrefs.onlineStreamingEnabled;

    final effectiveTab = (currentTab == AnimeDetailTab.online &&
            !onlineEnabled &&
            torrentEnabled)
        ? AnimeDetailTab.torrent
        : (currentTab == AnimeDetailTab.torrent &&
                !torrentEnabled &&
                onlineEnabled)
            ? AnimeDetailTab.online
            : currentTab;

    final title = details?.displayTitle(titleLang) ??
        initialEntry?.displayTitle(titleLang) ??
        (details?.title.isNotEmpty == true && details?.title != l10n.noTitle
            ? details!.title
            : null) ??
        initialEntry?.title ??
        l10n.loading;

    final coverUrl = details?.coverImage ?? initialEntry?.coverImage;
    final bannerUrl =
        details?.bannerImage ?? initialEntry?.bannerImage ?? coverUrl;
    final score = details?.score ?? initialEntry?.score;
    final format = details?.format ?? initialEntry?.format ?? 'TV';
    final episodes = details?.totalEpisodes ?? initialEntry?.totalEpisodes;
    final status = details?.status ?? initialEntry?.status;

    final displayScore = score != null && score > 0
        ? (score > 10
            ? (score / 10).toStringAsFixed(1)
            : score.toStringAsFixed(1))
        : '8.0';

    final year = details?.seasonYear ?? details?.rawMedia?['startDate']?['year'];
    final season = details?.season;
    final dateParts = <String>[];
    if (year != null && season != null) {
      dateParts.add('${l10n.formatSeason(season)} $year');
    } else if (year != null) {
      dateParts.add('$year');
    } else if (season != null) {
      dateParts.add(l10n.formatSeason(season));
    }
    final formattedStatus = l10n.formatStatus(status ?? details?.status);
    if (formattedStatus.isNotEmpty) {
      dateParts.add(formattedStatus);
    }
    final dateSeasonStatus = dateParts.join(' • ');

    final genresList = details?.genres ?? [];
    final genresString = genresList.take(3).join('  ');

    final liveCollectionEntry = ref.watch(animeCollectionProvider).whenOrNull(
          data: (entries) =>
              entries.where((e) => e.mediaId == mediaId).firstOrNull,
        );
    final progress = liveCollectionEntry?.progress ??
        details?.progress ??
        initialEntry?.progress ??
        0;
    final totalEps = episodes ?? details?.totalEpisodes;
    final progressText = progress > 0
        ? '$progress/${totalEps ?? "?"}'
        : (totalEps != null ? '$totalEps eps' : format);
    final userWatchStatus = liveCollectionEntry?.status ??
        details?.userStatus ??
        initialEntry?.status;
    final watchStatusText =
        l10n.formatWatchStatus(userWatchStatus, progress, totalEps, format);

    return Stack(
      children: [
        // Fixed background banner with ambient breathing motion and parallax
        Positioned(
          top: -16,
          left: 0,
          right: 0,
          height: 345,
          child: ClipRect(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [bannerAnimController, scrollController]),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bannerUrl != null)
                      CachedNetworkImage(
                        imageUrl: bannerUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        memCacheWidth: 1080,
                        errorWidget: (context, url, error) =>
                            Container(color: theme.colorScheme.surfaceContainer),
                      )
                    else
                      Container(color: theme.colorScheme.surfaceContainer),

                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [
                                  Colors.black.withValues(alpha: 0.65),
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.45),
                                  Colors.black.withValues(alpha: 0.85),
                                  theme.scaffoldBackgroundColor
                                      .withValues(alpha: 0.96),
                                  theme.scaffoldBackgroundColor,
                                ]
                              : [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.white.withValues(alpha: 0.50),
                                  Colors.white.withValues(alpha: 0.88),
                                  theme.scaffoldBackgroundColor
                                      .withValues(alpha: 0.96),
                                  theme.scaffoldBackgroundColor,
                                ],
                          stops: const [0.0, 0.20, 0.45, 0.70, 0.90, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
                builder: (context, child) {
                  final scrollOffset = scrollController.hasClients
                      ? scrollController.offset.clamp(0.0, double.infinity)
                      : 0.0;
                  final ambientScale =
                      1.0 + (bannerScaleAnimation.value * 0.05);
                  final ambientTranslateY = bannerTranslateAnimation.value;
                  final parallaxTranslateY =
                      scrollOffset > 0 ? -scrollOffset * 0.35 : 0.0;
                  final totalTranslateY =
                      ambientTranslateY + parallaxTranslateY;

                  return Transform.translate(
                    offset: Offset(0, totalTranslateY),
                    child: Transform.scale(
                      scale: ambientScale,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Foreground scrollable content
        Builder(
          builder: (context) {
            final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
            return CustomScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  tooltip:
                      isLocalMode ? l10n.exitLocalMode : l10n.enterLocalMode,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isLocalMode
                              ? theme.colorScheme.primaryContainer
                              : Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: isLocalMode
                              ? Border.all(
                                  color: theme.colorScheme.primary, width: 1.5)
                              : null,
                        ),
                        child: Icon(
                          isLocalMode
                              ? Icons.folder_rounded
                              : Icons.folder_outlined,
                          color: isLocalMode
                              ? theme.colorScheme.primary
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                      if (hasLocalFiles && !isLocalMode)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: onToggleLocalMode,
                ),
                IconButton(
                  tooltip: l10n.animeDetails,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: onOpenDetailsModal,
                ),
                const SizedBox(width: 8),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 26, 16, bottomPadding + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (coverUrl != null)
                          Container(
                            width: 125,
                            height: 185,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(colors.borderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 300,
                              memCacheHeight: 440,
                            ),
                          ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: SizedBox(
                            height: 185,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 19,
                                    color: titleColor,
                                    height: 1.2,
                                    shadows: isDark
                                        ? [
                                            Shadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.8),
                                              offset: const Offset(0, 1),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),

                                if (dateSeasonStatus.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_month_rounded,
                                        size: 14,
                                        color: subtitleColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          dateSeasonStatus,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                ],

                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite_rounded,
                                      size: 14,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      displayScore,
                                      style: TextStyle(
                                        color: titleColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (genresString.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          genresString,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 7),

                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => onOpenEditEntryModal(title),
                                      borderRadius: BorderRadius.circular(
                                          (colors.borderRadius * 0.5)
                                              .clamp(0.0, 8.0)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.1)
                                              : theme
                                                  .colorScheme.primaryContainer
                                                  .withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(
                                              (colors.borderRadius * 0.5)
                                                  .clamp(0.0, 8.0)),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.2)
                                                : theme.colorScheme
                                                    .outlineVariant
                                                    .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.edit_note_rounded,
                                          size: 15,
                                          color: isDark
                                              ? Colors.white
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => onOpenEditEntryModal(title),
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            progressText,
                                            style: TextStyle(
                                              color: titleColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            watchStatusText,
                                            style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (!isLocalMode && onlineEnabled && torrentEnabled) ...[
                      _buildTabBar(context, theme, colors),
                      const SizedBox(height: 12),
                    ],

                    if (isLocalMode)
                      LocalLibraryView(
                        mediaId: mediaId,
                        animeDetails: details,
                        progress: progress,
                        onSwitchToTorrent: () {
                          onToggleLocalMode();
                          onTabChanged(AnimeDetailTab.torrent);
                        },
                        onSwitchToOnline: () {
                          onToggleLocalMode();
                          onTabChanged(AnimeDetailTab.online);
                        },
                      )
                    else if (onlineEnabled &&
                        effectiveTab == AnimeDetailTab.online)
                      OnlineStreamView(
                        mediaId: mediaId,
                        animeDetails: details,
                        progress: progress,
                      )
                    else if (torrentEnabled &&
                        effectiveTab == AnimeDetailTab.torrent)
                      AniZipEpisodeListView(
                        aniZipData: aniZipData ?? details?.aniZipData,
                        fallbackEpisodes: details?.episodes ?? const [],
                        animeDetails: details,
                        isLoading: isLoading || isLoadingAniZip,
                        progress: progress,
                        onRetry: onRetryAniZip,
                        viewMode: ref.watch(episodeViewModeProvider),
                        onToggleViewMode: () => ref
                            .read(episodeViewModeProvider.notifier)
                            .toggleMode(),
                        onPlayEpisode: (ep) {
                          onOpenTorrentSelector(
                            episodeNumber: ep.episodeNumber,
                            episodeTitle: ep.displayTitle,
                            aniDBEpisode: ep.episode,
                          );
                        },
                        onTapEpisode: (ep) {
                          onOpenTorrentSelector(
                            episodeNumber: ep.episodeNumber,
                            episodeTitle: ep.displayTitle,
                            aniDBEpisode: ep.episode,
                          );
                        },
                        onPlayFallbackEpisode: (ep) {
                          onOpenTorrentSelector(
                            episodeNumber: ep.episodeNumber,
                            episodeTitle: ep.title,
                          );
                        },
                      )
                    else if (onlineEnabled)
                      OnlineStreamView(
                        mediaId: mediaId,
                        animeDetails: details,
                        progress: progress,
                      )
                    else if (torrentEnabled)
                      AniZipEpisodeListView(
                        aniZipData: aniZipData ?? details?.aniZipData,
                        fallbackEpisodes: details?.episodes ?? const [],
                        animeDetails: details,
                        isLoading: isLoading || isLoadingAniZip,
                        progress: progress,
                        onRetry: onRetryAniZip,
                        viewMode: ref.watch(episodeViewModeProvider),
                        onToggleViewMode: () => ref
                            .read(episodeViewModeProvider.notifier)
                            .toggleMode(),
                        onPlayEpisode: (ep) {
                          onOpenTorrentSelector(
                            episodeNumber: ep.episodeNumber,
                            episodeTitle: ep.displayTitle,
                            aniDBEpisode: ep.episode,
                          );
                        },
                        onTapEpisode: (ep) {
                          onOpenTorrentSelector(
                            episodeNumber: ep.episodeNumber,
                            episodeTitle: ep.displayTitle,
                            aniDBEpisode: ep.episode,
                          );
                        },
                        onPlayFallbackEpisode: (ep) {
                          onOpenTorrentSelector(
                            episodeNumber: ep.episodeNumber,
                            episodeTitle: ep.title,
                          );
                        },
                      )
                    else
                      const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        );
          },
        ),
      ],
    );
  }

  Widget _buildTabBar(
      BuildContext context, ThemeData theme, AppThemeColors colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(colors.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(
            theme: theme,
            colors: colors,
            tab: AnimeDetailTab.online,
            icon: Icons.public_rounded,
            label: 'Online',
          ),
          const SizedBox(width: 4),
          _buildTabButton(
            theme: theme,
            colors: colors,
            tab: AnimeDetailTab.torrent,
            icon: Icons.cloud_download_outlined,
            label: 'Torrent',
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required ThemeData theme,
    required AppThemeColors colors,
    required AnimeDetailTab tab,
    required IconData icon,
    required String label,
  }) {
    final isSelected = !isLocalMode && currentTab == tab;
    final innerRadius = (colors.borderRadius * 0.75).clamp(0.0, 16.0);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(innerRadius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(innerRadius),
            onTap: () => onTabChanged(tab),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
