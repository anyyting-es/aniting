import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Volume control widget.
///
/// On mobile it renders a compact mute/unmute button. On desktop it renders the
/// volume icon in the controls row (below the timeline) whose horizontal slider
/// smoothly expands to its right on hover, with mouse-wheel support.
class VolumeSlider extends ConsumerStatefulWidget {
  final double volume; // 0.0 to 100.0
  final ValueChanged<double> onVolumeChanged;
  final bool? isDesktopOverride;
  final ValueChanged<bool>? onHoverChanged;
  final double? iconSize;

  const VolumeSlider({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    this.isDesktopOverride,
    this.onHoverChanged,
    this.iconSize,
  });

  @override
  ConsumerState<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends ConsumerState<VolumeSlider> {
  Timer? _hideTimer;
  bool _isHovering = false;
  bool _isDragging = false;

  bool get _isDesktop =>
      widget.isDesktopOverride ?? (!Platform.isAndroid && !Platform.isIOS);

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHover() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_isHovering) {
      setState(() => _isHovering = true);
      widget.onHoverChanged?.call(true);
    }
  }

  void _scheduleHide() {
    if (_isDragging) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _isDragging) return;
      setState(() => _isHovering = false);
      widget.onHoverChanged?.call(false);
    });
  }

  void _handleScroll(PointerScrollEvent event) {
    _startHover();
    final delta = event.scrollDelta.dy;
    // Scroll up is negative delta (increase volume), scroll down is positive (decrease volume)
    final change = delta < 0 ? 5.0 : -5.0;
    widget.onVolumeChanged((widget.volume + change).clamp(0.0, 100.0));
  }

  void _toggleMute() {
    if (widget.volume > 0) {
      widget.onVolumeChanged(0.0);
    } else {
      widget.onVolumeChanged(100.0);
    }
  }

  IconData _getVolumeIcon([AppIconPack? pack]) {
    if (widget.volume <= 0) return AppIcons.volumeMute(pack);
    if (widget.volume < 35) return AppIcons.volumeLow(pack);
    if (widget.volume < 70) return AppIcons.volumeDown(pack);
    return AppIcons.volume(pack);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isMaterial = iconPack == AppIconPack.material;
    final double volumeIconSize = widget.iconSize ??
        (_isDesktop
            ? (isMaterial ? 28.0 : 23.0)
            : (isMaterial ? 24.0 : 21.0));

    if (!_isDesktop) {
      // Mobile compact mode: Mute / Unmute toggle button
      return IconButton(
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.all(2),
        ),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(_getVolumeIcon(iconPack), color: Colors.white, size: volumeIconSize),
        tooltip: widget.volume > 0 ? l10n.mute : l10n.unmute,
        onPressed: _toggleMute,
      );
    }

    final normalizedVolume = (widget.volume / 100.0).clamp(0.0, 1.0);

    // Desktop: icon + inline horizontal slider that expands to the right.
    return MouseRegion(
      opaque: true,
      onEnter: (_) => _startHover(),
      onHover: (_) => _startHover(),
      onExit: (_) => _scheduleHide(),
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _handleScroll(event);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _startHover();
                _toggleMute();
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: Center(
                  child: Icon(
                    _getVolumeIcon(iconPack),
                    color: Colors.white,
                    size: volumeIconSize,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: _isHovering ? 104 : 0,
              height: 36,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 104,
                  maxWidth: 104,
                  child: SizedBox(
                    width: 104,
                    height: 32,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: primaryColor,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.20),
                        thumbColor: primaryColor,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: normalizedVolume,
                        onChangeStart: (_) {
                          _isDragging = true;
                          _startHover();
                        },
                        onChanged: (newVal) =>
                            widget.onVolumeChanged(newVal * 100.0),
                        onChangeEnd: (_) {
                          _isDragging = false;
                          _startHover();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
