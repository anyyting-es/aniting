import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/episode_view_mode_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import 'package:seanime_app/presentation/widgets/episode_item_widget.dart';

class LocalLibraryView extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeDetails? animeDetails;
  final int progress;
  final VoidCallback onSwitchToTorrent;
  final VoidCallback onSwitchToOnline;

  const LocalLibraryView({
    super.key,
    required this.mediaId,
    this.animeDetails,
    this.progress = 0,
    required this.onSwitchToTorrent,
    required this.onSwitchToOnline,
  });

  @override
  ConsumerState<LocalLibraryView> createState() => _LocalLibraryViewState();
}

class _LocalLibraryViewState extends ConsumerState<LocalLibraryView> {
  LibraryEntryDetails? _libraryEntry;
  bool _isLoading = true;
  static const int _listPageSize = 24;
  int _currentListPage = 0;

  @override
  void initState() {
    super.initState();
    _loadLibraryEntry();
  }

  Future<void> _loadLibraryEntry() async {
    setState(() => _isLoading = true);
    final repo = ref.read(repositoryProvider);
    try {
      final entry = await repo.getAnimeLibraryEntry(widget.mediaId);
      if (mounted) {
        setState(() {
          _libraryEntry = entry;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _playLocalEpisode(LibraryEpisode ep) {
    final serverManager = ref.read(serverManagerProvider);
    final l10n = ref.read(translationsProvider);
    final animeTitle = widget.animeDetails?.title ?? 'Anime';
    final streamUrl = ep.localFilePath != null && ep.localFilePath!.isNotEmpty
        ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(ep.localFilePath!)}'
        : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${widget.mediaId}&episodeNumber=${ep.episodeNumber}';
    final fileName = ep.localFilePath != null && ep.localFilePath!.isNotEmpty
        ? ep.localFilePath!.split(RegExp(r'[/\\]')).last
        : null;
    final sourceDesc = fileName != null ? 'Local • $fileName' : l10n.localLibrary;

    Navigator.of(context).push(
      VideoPlayerScreen.route(
        mediaId: widget.mediaId,
        videoUrl: streamUrl,
        title: animeTitle,
        episodeTitle: ep.displayTitle,
        episodeNumber: ep.episodeNumber,
        videoSource: sourceDesc,
        animeDetails: widget.animeDetails,
        aniZipData: widget.animeDetails?.aniZipData,
        isLocalFile: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.checkingLocalFiles, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final downloadedEpisodes = _libraryEntry?.episodes
            .where((e) => e.isDownloaded)
            .toList() ??
        [];

    // Case 1: Anime is in library with downloaded files!
    if (downloadedEpisodes.isNotEmpty) {
      final fallbackImage =
          widget.animeDetails?.bannerImage ?? widget.animeDetails?.coverImage;
      final effectiveProgress = (_libraryEntry?.progress != null && _libraryEntry!.progress > 0)
          ? _libraryEntry!.progress
          : widget.progress;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.downloadedFiles,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular((context.themeColors.borderRadius * 0.5).clamp(0.0, 8.0)),
                ),
                child: Text(
                  '${downloadedEpisodes.length} ${l10n.localEpisodes}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  ref.watch(episodeViewModeProvider) == EpisodeViewMode.grid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: ref.watch(episodeViewModeProvider) == EpisodeViewMode.grid
                    ? l10n.switchToList
                    : l10n.switchToGrid,
                onPressed: () {
                  ref.read(episodeViewModeProvider.notifier).toggleMode();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (ref.watch(episodeViewModeProvider) == EpisodeViewMode.grid)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: downloadedEpisodes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.35,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final ep = downloadedEpisodes[index];
                final aniZipEp = widget.animeDetails?.aniZipData?.episodes
                    .where((e) => e.episodeNumber == ep.episodeNumber)
                    .firstOrNull;

                final epImg = (ep.thumbnail != null && ep.thumbnail!.isNotEmpty)
                    ? ep.thumbnail
                    : aniZipEp?.image;
                final epSynopsis = aniZipEp?.synopsis;
                final appLang = ref.watch(appLanguageProvider);
                final langCode = appLang.code;
                final epTitle = (ep.episodeTitle != null && ep.episodeTitle!.isNotEmpty)
                    ? ep.episodeTitle!
                    : (aniZipEp?.displayTitleForLang(langCode) ?? ep.displayTitle);

                return EpisodeGridItem(
                  episodeNumber: ep.episodeNumber,
                  title: epTitle,
                  originalTitle: aniZipEp?.originalTitle,
                  duration: aniZipEp?.formattedDuration,
                  synopsis: epSynopsis,
                  image: epImg,
                  fallbackImage: fallbackImage,
                  airDate: aniZipEp?.formattedAirDate,
                  rating: aniZipEp?.rating,
                  badgeText: 'LOCAL',
                  isWatched: effectiveProgress >= ep.episodeNumber && ep.episodeNumber > 0,
                  onTap: () => _playLocalEpisode(ep),
                  onPlay: () => _playLocalEpisode(ep),
                );
              },
            )
          else ...[
            Builder(
              builder: (context) {
                final totalEpisodes = downloadedEpisodes.length;
                final totalPages = (totalEpisodes / _listPageSize).ceil();
                final page = _currentListPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
                final start = page * _listPageSize;
                final end = (start + _listPageSize).clamp(0, totalEpisodes);
                final pagedEpisodes = totalEpisodes > 0 ? downloadedEpisodes.sublist(start, end) : <LibraryEpisode>[];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: pagedEpisodes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ep = pagedEpisodes[index];
                        final aniZipEp = widget.animeDetails?.aniZipData?.episodes
                            .where((e) => e.episodeNumber == ep.episodeNumber)
                            .firstOrNull;

                        final epImg = (ep.thumbnail != null && ep.thumbnail!.isNotEmpty)
                            ? ep.thumbnail
                            : aniZipEp?.image;
                        final epSynopsis = aniZipEp?.synopsis;
                        final appLang = ref.watch(appLanguageProvider);
                        final langCode = appLang.code;
                        final epTitle = (ep.episodeTitle != null && ep.episodeTitle!.isNotEmpty)
                            ? ep.episodeTitle!
                            : (aniZipEp?.displayTitleForLang(langCode) ?? ep.displayTitle);

                        return EpisodeListItem(
                          episodeNumber: ep.episodeNumber,
                          title: epTitle,
                          originalTitle: aniZipEp?.originalTitle,
                          duration: aniZipEp?.formattedDuration,
                          synopsis: epSynopsis,
                          image: epImg,
                          fallbackImage: fallbackImage,
                          airDate: aniZipEp?.formattedAirDate,
                          rating: aniZipEp?.rating,
                          badgeText: 'LOCAL',
                          isWatched: effectiveProgress >= ep.episodeNumber && ep.episodeNumber > 0,
                          onTap: () => _playLocalEpisode(ep),
                          onPlay: () => _playLocalEpisode(ep),
                        );
                      },
                    ),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: page > 0
                                ? () => setState(() => _currentListPage = page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: Text(l10n.previousPage),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${page + 1} / $totalPages',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: page < totalPages - 1
                                ? () => setState(() => _currentListPage = page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            label: Text('${l10n.nextPage} ($_listPageSize ep)'),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      );
    }

    // Case 2: Not in local library
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_off_outlined,
              size: 36,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.notInLocalLibrary,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.notInLocalLibraryDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: widget.onSwitchToOnline,
                icon: const Icon(Icons.public, size: 16),
                label: Text(l10n.watchOnlineStream, style: const TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onSwitchToTorrent,
                icon: const Icon(Icons.cloud_download_rounded, size: 16),
                label: Text(l10n.searchTorrents, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
