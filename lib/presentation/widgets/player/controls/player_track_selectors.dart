import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Formats a track's display title and language nicely.
String formatTrackLabel(UiTrack t) {
  final parts = <String>[];
  if (t.title.trim().isNotEmpty) parts.add(t.title.trim());
  final lang = t.language.trim();
  if (lang.isNotEmpty && lang.toLowerCase() != 'und') parts.add(lang);
  return parts.isEmpty ? '${t.index + 1}' : parts.join(' • ');
}

/// In-popover panel displaying available tracks (audio or subtitles).
/// Designed to render inside g1455's GlassPopoverAnchor with scroll isolation.
class PlayerInVideoTrackPanel extends StatefulWidget {
  final String title;
  final IconData titleIcon;
  final VoidCallback onClose;
  final List<UiTrack> tracks;
  final String? selectedTrackId;
  final ValueChanged<UiTrack?> onTrackSelected;
  final bool showDisableOption;
  final String disableOptionLabel;
  final AppIconPack iconPack;
  final VoidCallback? onDismissed;

  const PlayerInVideoTrackPanel({
    super.key,
    required this.title,
    required this.titleIcon,
    required this.onClose,
    required this.tracks,
    required this.selectedTrackId,
    required this.onTrackSelected,
    this.showDisableOption = false,
    this.disableOptionLabel = '',
    required this.iconPack,
    this.onDismissed,
  });

  @override
  State<PlayerInVideoTrackPanel> createState() => _PlayerInVideoTrackPanelState();
}

class _PlayerInVideoTrackPanelState extends State<PlayerInVideoTrackPanel> {
  @override
  void dispose() {
    widget.onDismissed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final isNoneSelected = widget.selectedTrackId == null ||
        widget.selectedTrackId == 'no' ||
        widget.selectedTrackId == 'none';

    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            // Absorb pointer scroll events when scrolling reaches boundaries,
            // preventing mouse wheel events from bubbling up to the outer watch page.
            GestureBinding.instance.pointerSignalResolver.register(
              pointerSignal,
              (_) {},
            );
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 280,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar with title and close icon
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(widget.titleIcon, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(4),
                        hoverColor: Colors.white12,
                      ),
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // Scrollable tracks list with strict clamping and scroll isolation
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showDisableOption) ...[
                        _TrackItemRow(
                          icon: isNoneSelected ? AppIcons.check(widget.iconPack) : Icons.block,
                          iconColor: isNoneSelected ? primaryColor : Colors.white60,
                          label: widget.disableOptionLabel,
                          isSelected: isNoneSelected,
                          primaryColor: primaryColor,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onTrackSelected(null);
                          },
                        ),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 8,
                        ),
                      ],
                      for (final track in widget.tracks)
                        _TrackItemRow(
                          icon: track.id == widget.selectedTrackId
                              ? AppIcons.check(widget.iconPack)
                              : widget.titleIcon,
                          iconColor: track.id == widget.selectedTrackId
                              ? primaryColor
                              : Colors.white60,
                          label: formatTrackLabel(track),
                          isSelected: track.id == widget.selectedTrackId,
                          primaryColor: primaryColor,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onTrackSelected(track);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackItemRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _TrackItemRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_TrackItemRow> createState() => _TrackItemRowState();
}

class _TrackItemRowState extends State<_TrackItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.primaryColor.withValues(alpha: 0.20)
                : (_isHovered
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: widget.iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isSelected ? widget.primaryColor : Colors.white,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtitle tracks trigger button with Liquid Glass Popover (g1455 GlassPopoverAnchor).
class PlayerSubtitleMenuButton extends StatelessWidget {
  final GlassMenuController? controller;
  final VoidCallback? onTap;
  final bool isOpen;
  final bool isSubDisabled;
  final double iconSize;
  final ButtonStyle buttonStyle;
  final AppIconPack iconPack;
  final String tooltip;
  final List<UiTrack> tracks;
  final String? selectedTrackId;
  final ValueChanged<UiTrack?>? onTrackSelected;
  final String disableOptionLabel;
  final String title;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  const PlayerSubtitleMenuButton({
    super.key,
    this.controller,
    this.onTap,
    this.isOpen = false,
    this.isSubDisabled = false,
    this.iconSize = 22,
    required this.buttonStyle,
    required this.iconPack,
    required this.tooltip,
    this.tracks = const [],
    this.selectedTrackId,
    this.onTrackSelected,
    this.disableOptionLabel = '',
    this.title = '',
    this.onOpen,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return IconButton(
        style: buttonStyle,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          isSubDisabled
              ? AppIcons.subtitlesOff(iconPack)
              : AppIcons.subtitles(iconPack),
          color: isSubDisabled
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white,
          size: iconSize,
        ),
        tooltip: tooltip,
        onPressed: onTap,
      );
    }

    return GlassPopoverAnchor(
      controller: controller,
      width: 290,
      radius: 16,
      finish: GlassFinish.regularDark,
      builder: (context, ctrl) => IconButton(
        style: buttonStyle.copyWith(
          backgroundColor: (ctrl.isOpen || isOpen)
              ? WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.22))
              : null,
        ),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          isSubDisabled
              ? AppIcons.subtitlesOff(iconPack)
              : AppIcons.subtitles(iconPack),
          color: isSubDisabled
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white,
          size: iconSize,
        ),
        tooltip: tooltip,
        onPressed: () {
          if (ctrl.isOpen) {
            ctrl.close();
            onClose?.call();
          } else {
            onOpen?.call();
            ctrl.open();
          }
          onTap?.call();
        },
      ),
      popoverBuilder: (context) => PlayerInVideoTrackPanel(
        title: title.isNotEmpty ? title : tooltip,
        titleIcon: AppIcons.subtitles(iconPack),
        tracks: tracks,
        selectedTrackId: selectedTrackId,
        showDisableOption: true,
        disableOptionLabel: disableOptionLabel,
        iconPack: iconPack,
        onClose: () {
          controller?.close();
          onClose?.call();
        },
        onDismissed: onClose,
        onTrackSelected: (t) {
          onTrackSelected?.call(t);
          controller?.close();
          onClose?.call();
        },
      ),
    );
  }
}

/// Audio tracks trigger button with Liquid Glass Popover (g1455 GlassPopoverAnchor).
class PlayerAudioMenuButton extends StatelessWidget {
  final GlassMenuController? controller;
  final VoidCallback? onTap;
  final bool isOpen;
  final double iconSize;
  final ButtonStyle buttonStyle;
  final AppIconPack iconPack;
  final String tooltip;
  final List<UiTrack> tracks;
  final String? selectedTrackId;
  final ValueChanged<UiTrack>? onTrackSelected;
  final String title;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  const PlayerAudioMenuButton({
    super.key,
    this.controller,
    this.onTap,
    this.isOpen = false,
    this.iconSize = 22,
    required this.buttonStyle,
    required this.iconPack,
    required this.tooltip,
    this.tracks = const [],
    this.selectedTrackId,
    this.onTrackSelected,
    this.title = '',
    this.onOpen,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return IconButton(
        style: buttonStyle,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          AppIcons.audio(iconPack),
          color: Colors.white,
          size: iconSize,
        ),
        tooltip: tooltip,
        onPressed: onTap,
      );
    }

    return GlassPopoverAnchor(
      controller: controller,
      width: 290,
      radius: 16,
      finish: GlassFinish.regularDark,
      builder: (context, ctrl) => IconButton(
        style: buttonStyle.copyWith(
          backgroundColor: (ctrl.isOpen || isOpen)
              ? WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.22))
              : null,
        ),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          AppIcons.audio(iconPack),
          color: Colors.white,
          size: iconSize,
        ),
        tooltip: tooltip,
        onPressed: () {
          if (ctrl.isOpen) {
            ctrl.close();
            onClose?.call();
          } else {
            onOpen?.call();
            ctrl.open();
          }
          onTap?.call();
        },
      ),
      popoverBuilder: (context) => PlayerInVideoTrackPanel(
        title: title.isNotEmpty ? title : tooltip,
        titleIcon: AppIcons.audio(iconPack),
        tracks: tracks,
        selectedTrackId: selectedTrackId,
        showDisableOption: false,
        iconPack: iconPack,
        onClose: () {
          controller?.close();
          onClose?.call();
        },
        onDismissed: onClose,
        onTrackSelected: (t) {
          if (t != null) onTrackSelected?.call(t);
          controller?.close();
          onClose?.call();
        },
      ),
    );
  }
}
