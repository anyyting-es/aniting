import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/download_preferences_provider.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';
import 'package:seanime_app/presentation/screens/download_manager_screen.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';
import 'package:seanime_app/core/storage/app_storage_paths.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/downloads/downloads_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final bool isEmbedded;

  const DownloadsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  late int _selectedTab;
  int _previousTab = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, 1);
    _previousTab = _selectedTab;
  }

  Future<void> _showDeleteAnimeDialog(dynamic item) async {
    final l10n = ref.read(translationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDownload),
        content: Text(l10n.deleteDownloadConfirm(item.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(repositoryProvider);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final entry = await repo.getAnimeLibraryEntry(item.mediaId);
        if (entry != null && entry.episodes.isNotEmpty) {
          final paths = entry.episodes
              .map((e) => e.localFilePath)
              .whereType<String>()
              .where((p) => p.isNotEmpty)
              .toList();
          if (paths.isNotEmpty) {
            await repo.deleteLocalFiles(paths);
            for (final p in paths) {
              try {
                final f = File(p);
                if (f.existsSync()) f.deleteSync();
              } catch (_) {}
            }
          }
        }
        // Also cleanup directory from anime downloads
        final animeDir = await AppStoragePaths.getAnimeDownloadsDirectory();
        if (await animeDir.exists()) {
          for (final dir in animeDir.listSync()) {
            if (dir is Directory) {
              final seg = dir.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
              if (seg == '${item.mediaId}' || seg.startsWith('${item.mediaId}_')) {
                try {
                  await dir.delete(recursive: true);
                } catch (_) {}
              }
            }
          }
        }
        await repo.scanLibrary();
        ref.invalidate(downloadedAnimeProvider);
        ref.invalidate(animeCollectionProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.downloadDeleted),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteMangaDialog(dynamic item) async {
    final l10n = ref.read(translationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDownload),
        content: Text(l10n.deleteDownloadConfirm(item.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final offlineService = ref.read(mangaOfflineServiceProvider);
      final repo = ref.read(repositoryProvider);
      final messenger = ScaffoldMessenger.of(context);
      try {
        await offlineService.deleteEntireManga(item.mediaId);
        final serverState = ref.read(serverNotifierProvider);
        if (serverState.isOnline) {
          try {
            final serverDownloads = await repo.getMangaDownloadsList();
            for (final raw in serverDownloads) {
              if (raw is Map<String, dynamic> && raw['mediaId'] == item.mediaId) {
                final downloadData = raw['downloadData'];
                final downloadIds = <Map<String, dynamic>>[];
                if (downloadData is Map<String, dynamic>) {
                  final downloadedMap = downloadData['downloaded'];
                  if (downloadedMap is Map<String, dynamic>) {
                    for (final entry in downloadedMap.entries) {
                      final provider = entry.key;
                      final list = entry.value;
                      if (list is List) {
                        for (final ch in list) {
                          if (ch is Map<String, dynamic>) {
                            downloadIds.add({
                              'provider': provider,
                              'mediaId': item.mediaId,
                              'chapterId': ch['id'] ?? ch['chapterId'] ?? '',
                              'chapterNumber': ch['chapter'] ?? ch['chapterNumber'] ?? '',
                            });
                          }
                        }
                      }
                    }
                  }
                }
                if (downloadIds.isNotEmpty) {
                  await repo.deleteMangaDownloadedChapters(downloadIds);
                }
              }
            }
          } catch (_) {}
        }
        ref.invalidate(downloadedMangaListProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.downloadDeleted),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop && !widget.isEmbedded) {
      return DownloadsDesktopLayout(
        initialTabIndex: widget.initialTabIndex,
        onDeleteAnime: _showDeleteAnimeDialog,
        onDeleteManga: _showDeleteMangaDialog,
      );
    }

    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final streamStatus = ref.watch(torrentStreamStatusProvider);
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final downloadedAnimeAsync = ref.watch(downloadedAnimeProvider);
    final downloadedMangaAsync = ref.watch(downloadedMangaListProvider);

    final activeCount = (streamStatus != null && streamStatus.downloadProgress > 0 ? 1 : 0) +
        activeDownloads.activeTorrents.length +
        activeDownloads.mangaQueue.length;
    final animeCount = downloadedAnimeAsync.asData?.value.length ?? 0;
    final mangaCount = downloadedMangaAsync.asData?.value.length ?? 0;

    return PixelSubpageScaffold(
      title: l10n.downloads,
      isEmbedded: widget.isEmbedded,
      children: [
        // ─── 0. BANNER / ACCESO RÁPIDO AL GESTOR DE DESCARGAS ────────
        PixelCardContainer(
          child: Container(
            decoration: BoxDecoration(
              color: activeCount > 0
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activeCount > 0
                    ? theme.colorScheme.primary.withValues(alpha: 0.4)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightToLeftPageRoute(
                      child: const DownloadManagerScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: activeCount > 0
                              ? theme.colorScheme.primary.withValues(alpha: 0.16)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          activeCount > 0 ? AppIcons.downloading(iconPack) : AppIcons.manageHistory(iconPack),
                          size: 20,
                          color: activeCount > 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.downloadManager,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              activeCount > 0
                                  ? '$activeCount ${l10n.activeDownloadsCount.toLowerCase()} • ${l10n.downloadManagerDesc}'
                                  : l10n.downloadManagerDesc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: activeCount > 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (activeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 6),
                      Icon(AppIcons.chevronRight(iconPack), size: 20, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ─── 1. SELECTOR DE PESTAÑAS PÍLDORA (ANIME / MANGA) ─────────
        _buildTabSelector(
          context,
          l10n,
          iconPack,
          theme,
          animeCount,
          mangaCount,
        ),
        const SizedBox(height: 16),

        // ─── 2. CONTENIDO DE LA PESTAÑA ACTIVA CON TRANSICIÓN FLUIDA ──
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[
                  ...previousChildren,
                  ?currentChild,
                ],
              );
            },
            transitionBuilder: (Widget child, Animation<double> animation) {
              final isIncoming = (child.key as ValueKey<int>?)?.value == _selectedTab;
              final direction = _selectedTab >= _previousTab ? 1.0 : -1.0;

              // Transición secuencial: el contenido saliente se desvanece primero
              // y el entrante aparece después con un leve desplazamiento directional,
              // evitando que se interpongan o existan saltos.
              final opacity = isIncoming
                  ? CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
                    )
                  : CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
                    );

              final slideOffset = isIncoming
                  ? Tween<Offset>(
                      begin: Offset(0.04 * direction, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
                    ))
                  : Tween<Offset>(
                      begin: Offset(-0.04 * direction, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.65, 1.0, curve: Curves.easeInCubic),
                    ));

              return SlideTransition(
                position: slideOffset,
                child: FadeTransition(
                  opacity: opacity,
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_selectedTab),
              child: _buildActiveTabContent(
                context,
                l10n,
                theme,
                isDark,
                iconPack,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTabContent(
    BuildContext context,
    AppTranslations l10n,
    ThemeData theme,
    bool isDark,
    AppIconPack iconPack,
  ) {
    switch (_selectedTab) {
      case 0:
        return _buildAnimeDownloadsTab(context, l10n, theme, isDark, iconPack);
      case 1:
      default:
        return _buildMangaDownloadsTab(context, l10n, theme, isDark, iconPack);
    }
  }

  Widget _buildTabSelector(
    BuildContext context,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
    int animeCount,
    int mangaCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const padding = 4.0;
        final innerWidth = totalWidth - (padding * 2);
        final itemWidth = innerWidth / 2;

        return Container(
          height: 44,
          padding: const EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Indicador deslizante animado (Píldora activa fluida)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: _selectedTab * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Botones de las 2 pestañas por encima del indicador
              Row(
                children: [
                  _buildTabItem(
                    index: 0,
                    label: l10n.anime,
                    icon: AppIcons.movie(iconPack),
                    badgeCount: animeCount,
                    theme: theme,
                  ),
                  _buildTabItem(
                    index: 1,
                    label: l10n.manga,
                    icon: AppIcons.manga(iconPack),
                    badgeCount: mangaCount,
                    theme: theme,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required IconData icon,
    required int badgeCount,
    required ThemeData theme,
  }) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_selectedTab != index) {
              setState(() {
                _previousTab = _selectedTab;
                _selectedTab = index;
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: Text(label),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimeDownloadsTab(
    BuildContext context,
    AppTranslations l10n,
    ThemeData theme,
    bool isDark,
    AppIconPack iconPack,
  ) {
    final serverState = ref.watch(serverNotifierProvider);
    if (!serverState.isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                child: Icon(
                  AppIcons.wifiOff(iconPack),
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.serverNotConnected,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final animeListAsync = ref.watch(downloadedAnimeProvider);

    return animeListAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $err'),
        ),
      ),
      data: (animeList) {
        if (animeList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    child: Icon(
                      AppIcons.downloadOffline(iconPack),
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noDownloadedAnimeTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noDownloadedAnimeDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
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
                          ref.invalidate(animeCollectionProvider);
                        },
                        icon: Icon(AppIcons.sync(iconPack), size: 18),
                        label: Text(l10n.scanLocalFolder),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final animeDir = await AppStoragePaths.getAnimeDownloadsDirectory();
                          await AppStoragePaths.openDirectoryInFileManager(animeDir.path);
                        },
                        icon: Icon(AppIcons.folderOpen(iconPack), size: 18),
                        label: Text(l10n.openDownloadsFolder),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de cantidad y botón refrescar
            PixelCardContainer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        AppIcons.videoLibrary(iconPack),
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.downloadedAnimeCount(animeList.length),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.refreshDownloadsTooltip,
                      icon: Icon(AppIcons.refresh(iconPack), size: 20),
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
                        ref.invalidate(animeCollectionProvider);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Cuadrícula fluida adaptativa
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.54,
              ),
              itemCount: animeList.length,
              itemBuilder: (context, index) {
                final item = animeList[index];
                return Stack(
                  children: [
                    GestureDetector(
                      onLongPress: () => _showDeleteAnimeDialog(item),
                      child: AnimeCard(
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
                          onPressed: () => _showDeleteAnimeDialog(item),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMangaDownloadsTab(
    BuildContext context,
    AppTranslations l10n,
    ThemeData theme,
    bool isDark,
    AppIconPack iconPack,
  ) {
    final downloadsAsync = ref.watch(downloadedMangaListProvider);
    final offlineService = ref.watch(mangaOfflineServiceProvider);
    final downloadPrefs = ref.watch(downloadPreferencesProvider);

    return downloadsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error(iconPack), size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text('Error: $err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(downloadedMangaListProvider),
                icon: Icon(AppIcons.refresh(iconPack)),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      data: (mangaList) {
        if (mangaList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    child: Icon(
                      AppIcons.manga(iconPack),
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noDownloadedMangaTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noDownloadedMangaDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final totalChapters = mangaList.fold<int>(
          0,
          (sum, e) => sum + e.downloadedChaptersCount,
        );

        return FutureBuilder<int>(
          future: offlineService.getTotalMangaStorageBytes(customBase: downloadPrefs.customBasePath),
          builder: (context, snapshot) {
            final sizeBytes = snapshot.data ?? 0;
            final sizeFormatted = _formatBytes(sizeBytes);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen de mangas descargados y almacenamiento utilizado
                PixelCardContainer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            AppIcons.folderZip(iconPack),
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.downloadedMangaCount(mangaList.length, totalChapters),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.storageUsed(sizeFormatted),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.refreshDownloadsTooltip,
                          icon: Icon(AppIcons.refresh(iconPack), size: 20),
                          onPressed: () => ref.invalidate(downloadedMangaListProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cuadrícula fluida adaptativa de mangas
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.54,
                  ),
                  itemCount: mangaList.length,
                  itemBuilder: (context, index) {
                    final item = mangaList[index];
                    return Stack(
                      children: [
                        GestureDetector(
                          onLongPress: () => _showDeleteMangaDialog(item),
                          child: MangaCard(
                            entry: item,
                            onTap: () {
                              MangaDetailScreen.navigate(
                                context,
                                mediaId: item.mediaId,
                                initialEntry: item,
                                fromDownloads: true,
                              );
                            },
                          ),
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
                              onPressed: () => _showDeleteMangaDialog(item),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
