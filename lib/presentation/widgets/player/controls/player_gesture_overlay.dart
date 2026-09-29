import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/m3_expressive_slider.dart';

/// Gesture overlay for the video player.
/// Handles: tap to toggle controls, double-tap seek, vertical swipe for volume/brightness.
class PlayerGestureOverlay extends ConsumerStatefulWidget {
  final bool gesturesEnabled;
  final VoidCallback onToggleControls;
  final VoidCallback onDoubleTapPlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback? onToggleFullscreen;
  final double volume; // 0.0 to 100.0 (or up to 200.0 if boosted)
  final ValueChanged<double> onVolumeChanged;
  final double brightness; // 0.0 to 1.0
  final ValueChanged<double> onBrightnessChanged;
  final bool volumeBoostEnabled;
  final bool? isDesktopOverride;

  const PlayerGestureOverlay({
    super.key,
    required this.gesturesEnabled,
    required this.onToggleControls,
    required this.onDoubleTapPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    this.onToggleFullscreen,
    required this.volume,
    required this.onVolumeChanged,
    required this.brightness,
    required this.onBrightnessChanged,
    this.volumeBoostEnabled = false,
    this.isDesktopOverride,
  });

  @override
  ConsumerState<PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _PlayerGestureOverlayState extends ConsumerState<PlayerGestureOverlay> {
  bool get _isDesktop =>
      widget.isDesktopOverride ?? (!Platform.isAndroid && !Platform.isIOS);
  // Which zone is being vertically dragged
  _DragZone? _activeDragZone;
  double _dragStartValue = 0.0;
  double _dragStartY = 0.0;

  // Overlay indicator
  _OverlayIndicator? _indicator;
  Timer? _indicatorHideTimer;

  @override
  void dispose() {
    _indicatorHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gesture detection area split into 3 zones
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left zone (32%) - brightness on vertical drag (mobile), seek back on double tap
            Expanded(
              flex: 32,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isDesktop ? widget.onDoubleTapPlayPause : widget.onToggleControls,
                onDoubleTap: widget.gesturesEnabled
                    ? widget.onSeekBackward
                    : null,
                onVerticalDragStart: (!_isDesktop && widget.gesturesEnabled)
                    ? (d) => _onDragStart(d, _DragZone.brightness)
                    : null,
                onVerticalDragUpdate: (!_isDesktop && widget.gesturesEnabled)
                    ? _onDragUpdate
                    : null,
                onVerticalDragEnd: (!_isDesktop && widget.gesturesEnabled) ? _onDragEnd : null,
                child: const SizedBox.expand(),
              ),
            ),
            // Center zone (36%) - play/pause on tap (desktop) or double-tap (mobile), fullscreen on double-click (desktop)
            Expanded(
              flex: 36,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isDesktop ? widget.onDoubleTapPlayPause : widget.onToggleControls,
                onDoubleTap: _isDesktop
                    ? (widget.onToggleFullscreen ?? widget.onDoubleTapPlayPause)
                    : (widget.gesturesEnabled ? widget.onDoubleTapPlayPause : null),
                child: const SizedBox.expand(),
              ),
            ),
            // Right zone (32%) - volume on vertical drag (mobile), seek forward on double tap
            Expanded(
              flex: 32,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isDesktop ? widget.onDoubleTapPlayPause : widget.onToggleControls,
                onDoubleTap: widget.gesturesEnabled
                    ? widget.onSeekForward
                    : null,
                onVerticalDragStart: (!_isDesktop && widget.gesturesEnabled)
                    ? (d) => _onDragStart(d, _DragZone.volume)
                    : null,
                onVerticalDragUpdate: (!_isDesktop && widget.gesturesEnabled)
                    ? _onDragUpdate
                    : null,
                onVerticalDragEnd: (!_isDesktop && widget.gesturesEnabled) ? _onDragEnd : null,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),

        // Overlay indicator for volume/brightness on their respective screen side
        if (_indicator != null)
          Positioned(
            left: _indicator!.zone == _DragZone.brightness ? 36 : null,
            right: _indicator!.zone == _DragZone.volume ? 36 : null,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildSideIndicator(_indicator!),
            ),
          ),
      ],
    );
  }

  Widget _buildSideIndicator(_OverlayIndicator indicator) {
    final isBoosted = indicator.isBoosted;
    final progressVal = indicator.zone == _DragZone.volume
        ? (indicator.value > 1.0 ? 1.0 : indicator.value)
        : indicator.value;
    final theme = Theme.of(context);
    final accentColor = isBoosted ? Colors.amber : theme.colorScheme.primary;

    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xF216151E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isBoosted
              ? Colors.amber.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.16),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(indicator.value * 100).round()}%',
            style: TextStyle(
              color: isBoosted ? Colors.amber : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          M3ExpressiveVerticalSlider(
            value: progressVal,
            height: 100,
            trackWidth: 18,
            thumbWidth: 26,
            thumbHeight: 3.5,
            gap: 2.5,
            activeColor: accentColor,
            inactiveColor: Colors.white.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 8),
          Icon(
            indicator.icon,
            color: isBoosted ? Colors.amber : Colors.white,
            size: 18,
          ),
        ],
      ),
    );
  }

  void _onDragStart(DragStartDetails details, _DragZone zone) {
    _activeDragZone = zone;
    _dragStartY = details.globalPosition.dy;
    if (zone == _DragZone.volume) {
      _dragStartValue = widget.volume / 100.0; // normalize to 0..1 (or 0..2)
    } else {
      _dragStartValue = widget.brightness;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_activeDragZone == null) return;
    _indicatorHideTimer?.cancel();

    final screenHeight = MediaQuery.of(context).size.height;
    // Responsive drag sensitivity in landscape
    final sensitivity = (screenHeight * 0.45).clamp(120.0, 300.0);
    final delta = (_dragStartY - details.globalPosition.dy) / sensitivity;

    final pack = ref.read(iconPackProvider);

    if (_activeDragZone == _DragZone.volume) {
      final maxVal = widget.volumeBoostEnabled ? 2.0 : 1.0;
      final newValue = (_dragStartValue + delta).clamp(0.0, maxVal);
      widget.onVolumeChanged(newValue * 100.0);
      setState(() {
        _indicator = _OverlayIndicator(
          icon: newValue > 0.5
              ? AppIcons.volume(pack)
              : newValue > 0
              ? AppIcons.volumeDown(pack)
              : AppIcons.volumeMute(pack),
          value: newValue,
          zone: _DragZone.volume,
          isBoosted: newValue > 1.0,
        );
      });
    } else {
      final newValue = (_dragStartValue + delta).clamp(0.0, 1.0);
      widget.onBrightnessChanged(newValue);
      setState(() {
        _indicator = _OverlayIndicator(
          icon: newValue > 0.5
              ? AppIcons.brightnessHigh(pack)
              : AppIcons.brightnessLow(pack),
          value: newValue,
          zone: _DragZone.brightness,
          isBoosted: false,
        );
      });
    }
  }

  void _onDragEnd(DragEndDetails details) {
    _activeDragZone = null;
    _indicatorHideTimer?.cancel();
    _indicatorHideTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _indicator = null);
    });
  }
}

enum _DragZone { volume, brightness }

class _OverlayIndicator {
  final IconData icon;
  final double value;
  final _DragZone zone;
  final bool isBoosted;

  const _OverlayIndicator({
    required this.icon,
    required this.value,
    required this.zone,
    this.isBoosted = false,
  });
}
