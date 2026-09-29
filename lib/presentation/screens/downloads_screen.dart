import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/download_preferences_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const DownloadsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.downloads),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Icon(AppIcons.movie(iconPack), size: 20),
                text: l10n.anime,
              ),
              Tab(
                icon: Icon(AppIcons.manga(iconPack), size: 20),
                text: l10n.manga,
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAnimeDownloadsTab(context, l10n, theme, isDark, iconPack),
            _buildMangaDownloadsTab(context, l10n, theme, isDark, iconPack),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeDownloadsTab(BuildContext context, dynamic l10n, ThemeData theme, bool isDark, AppIconPack iconPack) {
    final serverState = ref.watch(serverNotifierProvider);
    if (!serverState.isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                child: Icon(
                  AppIcons.wifiOff(iconPack),
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
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

    final animeListAsync = ref.watch(animeCollectionProvider);

    return animeListAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (animeList) {
        final localAnimeList = animeList;

        if (localAnimeList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    child: Icon(
                      AppIcons.downloadOffline(iconPack),
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No hay anime descargado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los episodios descargados en tu biblioteca local aparecerán aquí para ver sin conexión.',
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

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(animeCollectionProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
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
                            size: 22,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${localAnimeList.length} ${localAnimeList.length == 1 ? 'anime' : 'animes'} descargados en biblioteca local',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refrescar',
                          icon: Icon(AppIcons.refresh(iconPack), size: 20),
                          onPressed: () => ref.invalidate(animeCollectionProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.54,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = localAnimeList[index];
                      return AnimeCard(
                        entry: item,
                        onTap: () {
                          AnimeDetailScreen.navigate(
                            context,
                            mediaId: item.mediaId,
                            initialEntry: item,
                            initialLocalMode: true,
                          );
                        },
                      );
                    },
                    childCount: localAnimeList.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMangaDownloadsTab(BuildContext context, dynamic l10n, ThemeData theme, bool isDark, AppIconPack iconPack) {
    final downloadsAsync = ref.watch(downloadedMangaListProvider);
    final offlineService = ref.watch(mangaOfflineServiceProvider);
    final downloadPrefs = ref.watch(downloadPreferencesProvider);

    return downloadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error(iconPack), size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text('Error al cargar descargas: $err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(downloadedMangaListProvider),
                icon: Icon(AppIcons.refresh(iconPack)),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (mangaList) {
        if (mangaList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    child: Icon(
                      AppIcons.manga(iconPack),
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No hay manga descargado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los capítulos descargados para leer en el lector offline se guardarán automáticamente en Aniting/Downloads/Manga y aparecerán aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(AppIcons.explore(iconPack), size: 18),
                    label: const Text('Explorar Manga'),
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

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(downloadedMangaListProvider);
              },
              child: CustomScrollView(
                slivers: [
                  // 1. Header de almacenamiento e información
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
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
                                size: 22,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${mangaList.length} ${mangaList.length == 1 ? 'manga' : 'mangas'} • $totalChapters caps',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Espacio ocupado: $sizeFormatted',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refrescar descargas',
                              icon: Icon(AppIcons.refresh(iconPack), size: 20),
                              onPressed: () => ref.invalidate(downloadedMangaListProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Cuadrícula de mangas descargados
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.54,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = mangaList[index];
                          return MangaCard(
                            entry: item,
                            onTap: () {
                              MangaDetailScreen.navigate(
                                context,
                                mediaId: item.mediaId,
                                initialEntry: item,
                                fromDownloads: true,
                              );
                            },
                          );
                        },
                        childCount: mangaList.length,
                      ),
                    ),
                  ),
                ],
              ),
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
