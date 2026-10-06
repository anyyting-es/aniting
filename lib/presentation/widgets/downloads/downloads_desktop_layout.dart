import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/storage/app_storage_paths.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/download_manager_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';
import 'package:seanime_app/presentation/widgets/media_type_toggle.dart';

/// Modern Seanime-style desktop layout for offline downloads (Anime & Manga).
///
/// Features:
/// - Safe 42dp desktop top clearance below the custom titlebar.
/// - Prominent header with back navigation, screen title, and download manager access.
/// - Segmented pill switcher for Anime vs Manga downloads with live counts.
/// - Wide, multi-column card grid (200px max cross-axis extent, 0.53 aspect ratio).
/// - Quick scan and open downloads directory buttons.
class DownloadsDesktopLayout extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final Future<void> Function(dynamic item) onDeleteAnime;
  final Future<void> Function(dynamic item) onDeleteManga;

  const DownloadsDesktopLayout({
    super.key,
    this.initialTabIndex = 0,
    required this.onDeleteAnime,
    required this.onDeleteManga,
  });

  @override
  ConsumerState<DownloadsDesktopLayout> createState() => _DownloadsDesktopLayoutState();
}

class _DownloadsDesktopLayoutState extends ConsumerState<DownloadsDesktopLayout> {
  late String _selectedMediaType;
  final ScrollController _scrollController = SmoothTrackingScrollController();

  @override
  void initState() {
    super.initState();
    _selectedMediaType = widget.initialTabIndex == 1 ? 'MANGA' : 'ANIME';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final canPop = Navigator.canPop(context);

    final streamStatus = ref.watch(torrentStreamStatusProvider);
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final downloadedAnimeAsync = ref.watch(downloadedAnimeProvider);
    final downloadedMangaAsync = ref.watch(downloadedMangaListProvider);

    final activeCount = (streamStatus != null && streamStatus.downloadProgress > 0 ? 1 : 0) +
        activeDownloads.activeTorrents.length +
        activeDownloads.mangaQueue.length;

    final isAnime = _selectedMediaType == 'ANIME';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ─── 1. DESKTOP HEADER BAR ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(36, 42, 36, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompactHeader = constraints.maxWidth < 950;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (canPop) ...[
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        padding: const EdgeInsets.all(8),
                                        hoverColor: isDark
                                            ? Colors.white.withValues(alpha: 0.12)
                                            : theme.colorScheme.surfaceContainerHighest,
                                        highlightColor: isDark
                                            ? Colors.white.withValues(alpha: 0.18)
                                            : theme.colorScheme.surfaceContainerHigh,
                                      ),
                                      icon: Icon(
                                        AppIcons.arrowLeft(iconPack),
                                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                        size: 22,
                                      ),
                                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    const SizedBox(width: 12),
                                  ],

                                  Text(
                                    l10n.downloads,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 20),

                                  // Media Type Switcher (Anime / Manga pills)
                                  MediaTypeToggle(
                                    selected: _selectedMediaType,
                                    onSelected: (val) => setState(() => _selectedMediaType = val),
                                  ),

                                  if (!isCompactHeader) ...[
                                    const Spacer(),
                                    _buildHeaderActions(context, l10n, theme, iconPack, activeCount, isDark),
                                  ],
                                ],
                              ),
                              if (isCompactHeader) ...[
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: _buildHeaderActions(context, l10n, theme, iconPack, activeCount, isDark),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),


              // ─── 2. RESPONSIVE GRID CONTENT ───
              if (isAnime)
                ..._buildAnimeDownloadsGrid(
                  context: context,
                  asyncVal: downloadedAnimeAsync,
                  l10n: l10n,
                  theme: theme,
                  iconPack: iconPack,
                )
              else
                ..._buildMangaDownloadsGrid(
                  context: context,
                  asyncVal: downloadedMangaAsync,
                  l10n: l10n,
                  theme: theme,
                  iconPack: iconPack,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnimeDownloadsGrid({
    required BuildContext context,
    required AsyncValue<List<AnimeEntry>> asyncVal,
    required dynamic l10n,
    required ThemeData theme,
    required dynamic iconPack,
  }) {
    return asyncVal.when(
      data: (animeList) {
        if (animeList.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                icon: AppIcons.downloadOffline(iconPack),
                title: l10n.noDownloadedAnimeTitle,
                subtitle: l10n.noDownloadedAnimeDesc,
                theme: theme,
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(36, 12, 36, 48),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.53,
                crossAxisSpacing: 16,
                mainAxisSpacing: 22,
              ),
              itemCount: animeList.length,
              itemBuilder: (context, index) {
                final item = animeList[index];
                return Stack(
                  children: [
                    AnimeCard(
                      entry: item,
                      onTap: () {
                        AnimeDetailScreen.navigate(
                          context,
                          mediaId: item.mediaId,
                          initialEntry: item,
                          initialLocalMode: true,
                        );
                      },
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                          tooltip: l10n.deleteDownload,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          onPressed: () => widget.onDeleteAnime(item),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ];
      },
      loading: () => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (err, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('${l10n.error}: $err')),
        ),
      ],
    );
  }

  List<Widget> _buildMangaDownloadsGrid({
    required BuildContext context,
    required AsyncValue<List<MangaEntry>> asyncVal,
    required dynamic l10n,
    required ThemeData theme,
    required dynamic iconPack,
  }) {
    return asyncVal.when(
      data: (mangaList) {
        if (mangaList.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                icon: AppIcons.downloadOffline(iconPack),
                title: l10n.noDownloadedMangaTitle,
                subtitle: l10n.noDownloadedMangaDesc,
                theme: theme,
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(36, 12, 36, 48),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.53,
                crossAxisSpacing: 16,
                mainAxisSpacing: 22,
              ),
              itemCount: mangaList.length,
              itemBuilder: (context, index) {
                final item = mangaList[index];
                return Stack(
                  children: [
                    MangaCard(
                      entry: item,
                      onTap: () {
                        MangaDetailScreen.navigate(
                          context,
                          mediaId: item.mediaId,
                          initialEntry: item,
                        );
                      },
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                          tooltip: l10n.deleteDownload,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          onPressed: () => widget.onDeleteManga(item),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ];
      },
      loading: () => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (err, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('${l10n.error}: $err')),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(
    BuildContext context,
    dynamic l10n,
    ThemeData theme,
    dynamic iconPack,
    int activeCount,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick Access: Gestor de descargas
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.push(
              context,
              SlideRightToLeftPageRoute(
                child: const DownloadManagerScreen(),
              ),
            );
          },
          icon: Icon(
            activeCount > 0
                ? AppIcons.downloading(iconPack)
                : AppIcons.manageHistory(iconPack),
            size: 18,
            color: activeCount > 0 ? theme.colorScheme.primary : null,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.downloadManager),
              if (activeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Scan Local Folder Button
        OutlinedButton.icon(
          onPressed: () async {
            final repo = ref.read(repositoryProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.scanStarted),
                behavior: SnackBarBehavior.floating,
              ),
            );
            await repo.scanLibrary();
            ref.invalidate(downloadedAnimeProvider);
            ref.invalidate(downloadedMangaListProvider);
            ref.invalidate(animeCollectionProvider);
          },
          icon: Icon(AppIcons.sync(iconPack), size: 16),
          label: Text(l10n.scanLocalFolder),
        ),
        const SizedBox(width: 8),

        // Open Directory Button
        IconButton(
          icon: Icon(AppIcons.folderOpen(iconPack), size: 20),
          tooltip: l10n.openDownloadsFolder,
          style: IconButton.styleFrom(
            hoverColor: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest,
          ),
          onPressed: () async {
            final animeDir = await AppStoragePaths.getAnimeDownloadsDirectory();
            await AppStoragePaths.openDirectoryInFileManager(animeDir.path);
          },
        ),
      ],
    );
  }
}

