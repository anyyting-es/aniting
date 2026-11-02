import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/i18n/i18n_provider.dart';
import '../../../core/media_servers/models/media_server_config.dart';
import '../../../core/media_servers/models/media_server_item.dart';
import '../../../core/media_servers/models/media_server_type.dart';
import '../../../core/media_servers/providers/media_server_content_provider.dart';
import '../../../core/media_servers/providers/media_servers_provider.dart';
import '../../../core/media_servers/services/media_server_player_helper.dart';
import '../../../core/theme/custom_route_transitions.dart';
import 'media_server_show_detail_screen.dart';

class MediaServerBrowserScreen extends ConsumerStatefulWidget {
  const MediaServerBrowserScreen({super.key});

  @override
  ConsumerState<MediaServerBrowserScreen> createState() =>
      _MediaServerBrowserScreenState();
}

class _MediaServerBrowserScreenState
    extends ConsumerState<MediaServerBrowserScreen> {
  String? _selectedLibraryId;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeServer = ref.watch(activeMediaServerProvider);

    if (activeServer == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mediaServersTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.serverOff, size: 48, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(l10n.noMediaServersConnected),
            ],
          ),
        ),
      );
    }

    final isPlex = activeServer.type == MediaServerType.plex;
    final brandColor = isPlex ? const Color(0xFFE5A00D) : const Color(0xFF00A4DC);
    final librariesAsync = ref.watch(mediaServerLibrariesProvider);
    final continueWatchingAsync = ref.watch(mediaServerContinueWatchingProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPlex ? LucideIcons.tv : LucideIcons.film, color: brandColor, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                activeServer.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: () {
              ref.invalidate(mediaServerLibrariesProvider);
              ref.invalidate(mediaServerContinueWatchingProvider);
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Continuar viendo (On Deck)
          continueWatchingAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            ),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (items) {
              if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        l10n.mediaServerContinueWatching,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ContinueWatchingCard(
                            item: item,
                            server: activeServer,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),

          // Pestañas de bibliotecas
          librariesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: LinearProgressIndicator(),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $err'),
              ),
            ),
            data: (libraries) {
              if (libraries.isEmpty) {
                return SliverFillRemaining(
                  child: Center(child: Text(l10n.mediaServerNoItems)),
                );
              }

              if (_selectedLibraryId == null ||
                  !libraries.any((lib) => lib.id == _selectedLibraryId)) {
                _selectedLibraryId = libraries.first.id;
              }

              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: libraries.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final lib = libraries[index];
                          final isSelected = lib.id == _selectedLibraryId;
                          return ChoiceChip(
                            label: Text(lib.title),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedLibraryId = lib.id),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  _LibraryItemsGrid(
                    libraryId: _selectedLibraryId!,
                    server: activeServer,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final MediaServerItem item;
  final MediaServerConfig server;

  const _ContinueWatchingCard({required this.item, required this.server});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(14),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => MediaServerPlayerHelper.playDirect(
          context: context,
          item: item,
          server: server,
        ),
        child: SizedBox(
          width: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.backdropUrl != null || item.thumbUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: item.backdropUrl ?? item.thumbUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox(),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.play, color: Colors.white, size: 20),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.parentTitle ?? item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.type == MediaServerItemType.episode)
                      Text(
                        item.displayEpisodeLabel,
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (item.progress > 0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryItemsGrid extends ConsumerWidget {
  final String libraryId;
  final MediaServerConfig server;

  const _LibraryItemsGrid({required this.libraryId, required this.server});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(mediaServerLibraryItemsProvider(libraryId));

    return itemsAsync.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (err, _) => SliverFillRemaining(
        child: Center(child: Text(err.toString())),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text('Biblioteca vacía')),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return _PosterCard(
                  item: item,
                  server: server,
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}

class _PosterCard extends StatelessWidget {
  final MediaServerItem item;
  final MediaServerConfig server;

  const _PosterCard({required this.item, required this.server});

  @override
  Widget build(BuildContext context) {
    final isShow = item.type == MediaServerItemType.show;

    return GlassCard(
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isShow) {
            Navigator.of(context).push(
              SmoothPageRoute(
                child: MediaServerShowDetailScreen(
                  show: item,
                  server: server,
                ),
              ),
            );
          } else {
            MediaServerPlayerHelper.playDirect(
              context: context,
              item: item,
              server: server,
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: item.thumbUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.thumbUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const Center(
                          child: Icon(LucideIcons.film, size: 28),
                        ),
                      )
                    : const Center(child: Icon(LucideIcons.film, size: 28)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
