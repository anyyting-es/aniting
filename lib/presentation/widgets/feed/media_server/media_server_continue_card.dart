import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/media_servers/models/media_server_config.dart';
import '../../../../core/media_servers/models/media_server_item.dart';
import '../../../../core/media_servers/services/media_server_player_helper.dart';
import '../../../../core/theme/app_focus_coordinator.dart';
import '../../../../core/theme/app_theme_colors.dart';

class MediaServerContinueCard extends ConsumerStatefulWidget {
  final MediaServerItem item;
  final MediaServerConfig server;
  final double width;
  final double height;

  const MediaServerContinueCard({
    super.key,
    required this.item,
    required this.server,
    this.width = 285,
    this.height = 168,
  });

  @override
  ConsumerState<MediaServerContinueCard> createState() =>
      _MediaServerContinueCardState();
}

class _MediaServerContinueCardState
    extends ConsumerState<MediaServerContinueCard> {
  late final FocusNode _focusNode = FocusNode();
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isLaunching = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    try {
      MediaServerPlayerHelper.playDirect(
        context: context,
        item: widget.item,
        server: widget.server,
      );
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _handleTap();
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

    final isEpisode = widget.item.type == MediaServerItemType.episode;
    final imageUrl = isEpisode
        ? (widget.item.thumbUrl ?? widget.item.backdropUrl)
        : (widget.item.backdropUrl ?? widget.item.thumbUrl);
    final isCompact = widget.width < 270;

    final titleLine = isEpisode ? widget.item.displayEpisodeLabel : widget.item.title;
    final subtitleLine = isEpisode ? (widget.item.parentTitle ?? widget.server.name) : widget.server.name;

    final progress = widget.item.progress;

    return RepaintBoundary(
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (val) {
          if (val) {
            AppFocusCoordinator.onNodeFocused(_focusNode);
          }
          setState(() => _isFocused = val);
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
            onTap: _handleTap,
            child: SizedBox(
              width: widget.width,
              child: ValueListenableBuilder<AppInputMode>(
                valueListenable: AppFocusCoordinator.inputMode,
                builder: (context, mode, _) {
                  final isDpad = mode == AppInputMode.dpad;
                  final isActive = (mode == AppInputMode.mouse && _isHovered) || (isDpad && _isFocused);

                  return Stack(
                    children: [
                      // Ambient color background idéntico a ContinueWatchingCard
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

                      // Contenido foreground
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Imagen de portada 16:9 idéntica
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: AnimatedScale(
                                scale: 1.0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: BorderRadius.circular(10),
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
                                      if (imageUrl != null)
                                        CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          memCacheWidth: (widget.width * 2).round(),
                                          memCacheHeight:
                                              ((widget.width * 2) / (16 / 9)).round(),
                                          filterQuality: FilterQuality.medium,
                                          placeholder: (_, _) => Container(
                                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                            child: Center(
                                              child: Icon(
                                                Icons.movie_outlined,
                                                color: theme.colorScheme.outline.withValues(alpha: 0.25),
                                                size: isCompact ? 28 : 36,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (_, _, _) => Container(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                            child: Icon(
                                              Icons.movie_rounded,
                                              color: theme.colorScheme.outline,
                                              size: isCompact ? 28 : 36,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: Icon(
                                            Icons.movie_rounded,
                                            color: theme.colorScheme.outline,
                                            size: isCompact ? 28 : 36,
                                          ),
                                        ),

                                      // Badge superior sutil indicando el servidor
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.70),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: accent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                widget.server.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Botón Play idéntico al hover de ContinueWatchingCard
                                      if (isActive && !_isLaunching)
                                        Center(
                                          child: Container(
                                            width: isCompact ? 36 : 44,
                                            height: isCompact ? 36 : 44,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.35),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: isCompact ? 22 : 28,
                                            ),
                                          ),
                                        ),

                                      // Spinner de lanzamiento si está abriendo
                                      if (_isLaunching)
                                        Container(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),

                                      // Barra de progreso inferior idéntica
                                      if (progress > 0.01 && progress < 0.98)
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.black.withValues(alpha: 0.35),
                                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                                            minHeight: isCompact ? 2.5 : 3.0,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 6 : 8),

                            // 2. Título idéntico a ContinueWatchingCard
                            Text(
                              titleLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? colors.textPrimary
                                    : const Color(0xFF111418),
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 2),

                            // 3. Subtítulo idéntico a ContinueWatchingCard
                            Text(
                              subtitleLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: isCompact ? 11.0 : 12.0,
                                fontWeight: FontWeight.w500,
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
