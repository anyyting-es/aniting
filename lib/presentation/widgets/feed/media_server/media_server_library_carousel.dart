import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/media_servers/models/media_server_config.dart';
import '../../../../core/media_servers/models/media_server_item.dart';
import '../../../../core/media_servers/models/media_server_library.dart';
import '../../../../core/media_servers/providers/media_server_content_provider.dart';
import '../../../../core/media_servers/services/media_server_player_helper.dart';
import '../../../../core/theme/app_focus_coordinator.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/custom_route_transitions.dart';
import '../../../screens/media_servers/media_server_show_detail_screen.dart';
import '../../anime_preview/show_preview_data.dart';
import '../../anime_preview/show_quick_view_detector.dart';
import '../smooth_focus_carousel.dart';

class MediaServerLibraryCarousel extends ConsumerWidget {
  final MediaServerConfig server;
  final MediaServerLibrary library;
  final double cardWidth;
  final double carouselHeight;
  final double cardSpacing;
  final bool isDesktop;

  const MediaServerLibraryCarousel({
    super.key,
    required this.server,
    required this.library,
    this.cardWidth = 145,
    this.carouselHeight = 220,
    this.cardSpacing = 12,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.themeColors;
    final itemsAsync = ref.watch(mediaServerLibraryItemsProvider(library.id));

    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${library.title} • ${server.name}',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: theme.brightness == Brightness.dark
                          ? colors.textPrimary
                          : const Color(0xFF111418),
                    ),
                  ),
                ],
              ),
            ),
            SmoothFocusCarousel(
              itemCount: items.length,
              itemWidth: cardWidth,
              spacing: cardSpacing,
              height: carouselHeight,
              itemBuilder: (context, index) {
                final item = items[index];
                return _ServerAnimeCard(
                  item: item,
                  server: server,
                  width: cardWidth,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _ServerAnimeCard extends StatefulWidget {
  final MediaServerItem item;
  final MediaServerConfig server;
  final double width;

  const _ServerAnimeCard({
    required this.item,
    required this.server,
    required this.width,
  });

  @override
  State<_ServerAnimeCard> createState() => _ServerAnimeCardState();
}

class _ServerAnimeCardState extends State<_ServerAnimeCard> {
  late final FocusNode _focusNode = FocusNode();
  bool _isHovered = false;
  bool _isFocused = false;

  /// Unique per card instance, so the same item rendered in two carousels
  /// never produces duplicate Hero tags in the same subtree.
  final Object _heroTag = Object();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.item.type == MediaServerItemType.show) {
      Navigator.of(context).push(
        SmoothPageRoute(
          child: MediaServerShowDetailScreen(
            show: widget.item,
            server: widget.server,
          ),
        ),
      );
    } else {
      MediaServerPlayerHelper.playDirect(
        context: context,
        item: widget.item,
        server: widget.server,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _onTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.themeColors;
    final accent = theme.colorScheme.primary;
    final isCompact = widget.width < 155;

    return ShowQuickViewDetector(
      heroTag: _heroTag,
      dataBuilder: () => ShowPreviewData.fromMediaServer(widget.item),
      onOpenDetails: _onTap,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (focused) {
          if (focused) {
            AppFocusCoordinator.onNodeFocused(_focusNode);
          }
          setState(() => _isFocused = focused);
        },
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onEnter: (_) {
            AppFocusCoordinator.switchToMouse(_focusNode);
            setState(() => _isHovered = true);
          },
          onExit: (_) {
            if (AppFocusCoordinator.lastHoveredNode == _focusNode) {
              AppFocusCoordinator.lastHoveredNode = null;
            }
            setState(() => _isHovered = false);
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: SizedBox(
              width: widget.width,
              child: ValueListenableBuilder<AppInputMode>(
                valueListenable: AppFocusCoordinator.inputMode,
                builder: (context, mode, _) {
                  final isDpad = mode == AppInputMode.dpad;
                  final isActive = (mode == AppInputMode.mouse && _isHovered) || (isDpad && _isFocused);

                return Stack(
                  children: [
                    // Ambient color background idéntico a AnimeCard
                    Positioned.fill(
                      child: AnimatedScale(
                        scale: 1.0,
                        duration: const Duration(milliseconds: 220),
                        curve: isActive ? Curves.easeOutCubic : Curves.easeInCubic,
                        alignment: Alignment.center,
                        child: AnimatedOpacity(
                          opacity: isActive ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: accent.withValues(
                                alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Card Foreground Content idéntico a AnimeCard
                    Padding(
                      padding: EdgeInsets.all(isCompact ? 2.5 : 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Poster Art Container (Aspect ratio 0.72)
                          AspectRatio(
                            aspectRatio: 0.72,
                            child: AnimatedScale(
                              scale: 1.0,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(
                                    isCompact
                                        ? (colors.borderRadius * 0.8).clamp(0.0, 16.0)
                                        : colors.borderRadius,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: _isHovered ? 0.32 : 0.15),
                                      blurRadius: _isHovered ? 10 : 4,
                                      offset: Offset(0, _isHovered ? 3 : 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Hero(
                                      tag: _heroTag,
                                      child: widget.item.thumbUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: widget.item.thumbUrl!,
                                              fit: BoxFit.cover,
                                              memCacheWidth: (widget.width * 2).round(),
                                              memCacheHeight:
                                                  ((widget.width * 2) / 0.72).round(),
                                              filterQuality: FilterQuality.medium,
                                              placeholder: (_, _) => Container(
                                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                                child: const Center(
                                                  child: Icon(Icons.movie_outlined, size: 28),
                                                ),
                                              ),
                                              errorWidget: (_, _, _) => Container(
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                child: const Icon(Icons.movie_rounded, size: 28),
                                              ),
                                            )
                                          : Container(
                                              color: theme.colorScheme.surfaceContainerHighest,
                                              child: const Icon(Icons.movie_rounded, size: 28),
                                            ),
                                    ),

                                    // Gradiente sutil inferior
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      height: 40,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black45],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isCompact ? 6 : 8),

                          // 2. Título idéntico a AnimeCard
                          Text(
                            widget.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.brightness == Brightness.dark
                                  ? colors.textPrimary
                                  : const Color(0xFF111418),
                              fontSize: isCompact ? 13.0 : 14.5,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          ),
        ),
      ),
    );
  }
}
