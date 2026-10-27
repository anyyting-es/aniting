import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'desktop_episode_models.dart';

Future<void> showDesktopEpisodeSourceDialog(
  BuildContext context, {
  required DesktopEpisodeItemData episode,
  required String animeTitle,
  required List<OnlinestreamProvider> providers,
  required OnlinestreamProvider? selectedProvider,
  required bool isDubbed,
  required ValueChanged<OnlinestreamProvider?> onProviderChanged,
  required VoidCallback onToggleDubbed,
  required VoidCallback onPlayOnline,
  required VoidCallback onPlayTorrent,
  VoidCallback? onPlayLocal,
  VoidCallback? onDownloadOnline,
  VoidCallback? onDownloadTorrent,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => DesktopEpisodeSourceDialog(
      episode: episode,
      animeTitle: animeTitle,
      providers: providers,
      selectedProvider: selectedProvider,
      isDubbed: isDubbed,
      onProviderChanged: onProviderChanged,
      onToggleDubbed: onToggleDubbed,
      onPlayOnline: onPlayOnline,
      onPlayTorrent: onPlayTorrent,
      onPlayLocal: onPlayLocal,
      onDownloadOnline: onDownloadOnline,
      onDownloadTorrent: onDownloadTorrent,
    ),
  );
}

class DesktopEpisodeSourceDialog extends ConsumerStatefulWidget {
  final DesktopEpisodeItemData episode;
  final String animeTitle;
  final List<OnlinestreamProvider> providers;
  final OnlinestreamProvider? selectedProvider;
  final bool isDubbed;
  final ValueChanged<OnlinestreamProvider?> onProviderChanged;
  final VoidCallback onToggleDubbed;
  final VoidCallback onPlayOnline;
  final VoidCallback onPlayTorrent;
  final VoidCallback? onPlayLocal;
  final VoidCallback? onDownloadOnline;
  final VoidCallback? onDownloadTorrent;

  const DesktopEpisodeSourceDialog({
    super.key,
    required this.episode,
    required this.animeTitle,
    required this.providers,
    required this.selectedProvider,
    required this.isDubbed,
    required this.onProviderChanged,
    required this.onToggleDubbed,
    required this.onPlayOnline,
    required this.onPlayTorrent,
    this.onPlayLocal,
    this.onDownloadOnline,
    this.onDownloadTorrent,
  });

  @override
  ConsumerState<DesktopEpisodeSourceDialog> createState() =>
      _DesktopEpisodeSourceDialogState();
}

class _DesktopEpisodeSourceDialogState
    extends ConsumerState<DesktopEpisodeSourceDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);

    final hasLocal = widget.onPlayLocal != null ||
        widget.episode.isDownloaded ||
        (widget.episode.localFilePath != null &&
            widget.episode.localFilePath!.isNotEmpty);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.28),
              width: 1.2,
            ),
          ),
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header: Episode preview & close button ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 16:9 Thumbnail
                    if (widget.episode.image != null &&
                        widget.episode.image!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 110,
                          height: 62,
                          child: CachedNetworkImage(
                            imageUrl: widget.episode.image!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 110,
                        height: 62,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(AppIcons.play(iconPack), size: 24, color: Colors.white54),
                        ),
                      ),
                    const SizedBox(width: 14),

                    // Titles
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.animeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.episode.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close Button
                    IconButton(
                      icon: Icon(AppIcons.close(iconPack), size: 20),
                      color: isDark ? Colors.white70 : Colors.black54,
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 14),

                Text(
                  l10n.selectSource,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.black54,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // ─── Source 1: Local File (if available) ───
                if (hasLocal) ...[
                  _SourceActionTile(
                    autofocus: true,
                    icon: AppIcons.folderFilled(iconPack),
                    title: l10n.localLibrary,
                    subtitle: widget.episode.localFilePath != null
                        ? widget.episode.localFilePath!.split(RegExp(r'[/\\]')).last
                        : l10n.localLibrary,
                    isDark: isDark,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onPlayLocal?.call();
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // ─── Source 2: Online Streaming ───
                _SourceActionTile(
                  autofocus: !hasLocal,
                  icon: AppIcons.globe(iconPack),
                  title: l10n.onlineStreaming,
                  subtitle: widget.selectedProvider?.name ?? l10n.source,
                  trailing: widget.providers.isNotEmpty
                      ? GlassMenuAnchor(
                          width: 220,
                          items: widget.providers.map((p) {
                            final isCurrent = widget.selectedProvider?.id == p.id;
                            return GlassMenuItem(
                              label: p.name,
                              icon: Icon(
                                isCurrent
                                    ? AppIcons.checkCircleFilled(iconPack)
                                    : AppIcons.globe(iconPack),
                                size: 18,
                                color: isCurrent ? Colors.white : null,
                              ),
                              onPressed: () => widget.onProviderChanged(p),
                            );
                          }).toList(),
                          builder: (ctx, controller) => IconButton(
                            icon: Icon(AppIcons.chevronDown(iconPack), size: 18),
                            color: Colors.white70,
                            tooltip: l10n.source,
                            onPressed: controller.open,
                          ),
                        )
                      : null,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onPlayOnline();
                  },
                ),
                const SizedBox(height: 10),

                // ─── Source 3: Torrent Streaming ───
                _SourceActionTile(
                  icon: AppIcons.cloudDownload(iconPack),
                  title: l10n.torrentStreaming,
                  subtitle: 'P2P • Buscar torrents',
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onPlayTorrent();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceActionTile extends ConsumerStatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool isDark;
  final VoidCallback onTap;
  final bool autofocus;

  const _SourceActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.isDark,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  ConsumerState<_SourceActionTile> createState() => _SourceActionTileState();
}

class _SourceActionTileState extends ConsumerState<_SourceActionTile> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'source_tile_${widget.title}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (val) {
        if (val) {
          AppFocusCoordinator.onNodeFocused(_focusNode);
        }
        setState(() => _isFocused = val);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ValueListenableBuilder<AppInputMode>(
        valueListenable: AppFocusCoordinator.inputMode,
        builder: (context, inputMode, _) {
          final isDpad = inputMode == AppInputMode.dpad;
          final isActive =
              (inputMode == AppInputMode.mouse && _isHovered) || (isDpad && _isFocused);

          return MouseRegion(
            cursor: SystemMouseCursors.click,
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
            child: InkWell(
              canRequestFocus: false,
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isActive
                      ? Colors.white.withValues(alpha: widget.isDark ? 0.18 : 0.15)
                      : Colors.white.withValues(alpha: widget.isDark ? 0.07 : 0.05),
                  border: Border.all(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: widget.isDark ? 0.12 : 0.15),
                    width: isActive ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: isActive ? 0.22 : 0.10),
                      ),
                      child: Icon(widget.icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                    const SizedBox(width: 4),
                    Icon(
                      AppIcons.chevronRight(ref.watch(iconPackProvider)),
                      size: 18,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
