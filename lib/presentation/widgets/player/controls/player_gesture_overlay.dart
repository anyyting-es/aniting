import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Gesture overlay for the video player.
/// Handles:
/// - Tap to toggle controls (or play/pause on desktop)
/// - Double-tap seek backward/forward (or fullscreen on desktop)
/// - Vertical swipe on left/right edges for brightness & volume with sleek, non-Material floating pill
/// - Horizontal swipe anywhere for smooth seeking with a subtle center indicator displaying target time & delta
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

  // Horizontal seek gesture support
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration>? onSeek;

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
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.onSeek,
  });

  @override
  ConsumerState<PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _PlayerGestureOverlayState extends ConsumerState<PlayerGestureOverlay> {
  bool get _isDesktop =>
      widget.isDesktopOverride ?? (!Platform.isAndroid && !Platform.isIOS);

  // Vertical drag state
  _DragZone? _activeDragZone;
  double _dragStartValue = 0.0;
  double _dragStartY = 0.0;

  // Horizontal seek drag state
  bool _isHorizontalSeeking = false;
  double _horizontalStartX = 0.0;
  Duration _seekStartPosition = Duration.zero;
  Duration _currentSeekPosition = Duration.zero;

  // Overlay indicators
  _OverlayIndicator? _sideIndicator;
  Timer? _sideIndicatorHideTimer;

  @override
  void dispose() {
    _sideIndicatorHideTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Handle horizontal drag start
  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isDesktop || !widget.gesturesEnabled || widget.duration <= Duration.zero) return;
    _isHorizontalSeeking = true;
    _horizontalStartX = details.globalPosition.dx;
    _seekStartPosition = widget.position;
    _currentSeekPosition = widget.position;
    HapticFeedback.selectionClick();
    setState(() {});
  }

  // Handle horizontal drag update
  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isHorizontalSeeking || widget.duration <= Duration.zero) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final deltaX = details.globalPosition.dx - _horizontalStartX;

    // Responsive seek scaling: dragging across 70% of screen seeks ~90s or up to 20% duration
    final maxSeekWindowSeconds = (widget.duration.inSeconds * 0.25).clamp(60.0, 300.0);
    final seekOffsetSeconds = (deltaX / (screenWidth * 0.75)) * maxSeekWindowSeconds;

    final targetMs = (_seekStartPosition.inMilliseconds + (seekOffsetSeconds * 1000).toInt())
        .clamp(0, widget.duration.inMilliseconds);

    setState(() {
      _currentSeekPosition = Duration(milliseconds: targetMs);
    });
  }

  // Handle horizontal drag end
  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isHorizontalSeeking) return;
    final finalTarget = _currentSeekPosition;
    _isHorizontalSeeking = false;
    HapticFeedback.lightImpact();
    setState(() {});
    widget.onSeek?.call(finalTarget);
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
                onDoubleTap: widget.gesturesEnabled ? widget.onSeekBackward : null,
                onVerticalDragStart: (!_isDesktop && widget.gesturesEnabled)
                    ? (d) => _onVerticalDragStart(d, _DragZone.brightness)
                    : null,
                onVerticalDragUpdate: (!_isDesktop && widget.gesturesEnabled)
                    ? _onVerticalDragUpdate
                    : null,
                onVerticalDragEnd: (!_isDesktop && widget.gesturesEnabled)
                    ? _onVerticalDragEnd
                    : null,
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: const SizedBox.expand(),
              ),
            ),
            // Center zone (36%) - play/pause on tap (desktop) or double-tap (mobile), horizontal seek
            Expanded(
              flex: 36,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isDesktop ? widget.onDoubleTapPlayPause : widget.onToggleControls,
                onDoubleTap: _isDesktop
                    ? (widget.onToggleFullscreen ?? widget.onDoubleTapPlayPause)
                    : (widget.gesturesEnabled ? widget.onDoubleTapPlayPause : null),
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: const SizedBox.expand(),
              ),
            ),
            // Right zone (32%) - volume on vertical drag (mobile), seek forward on double tap
            Expanded(
              flex: 32,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isDesktop ? widget.onDoubleTapPlayPause : widget.onToggleControls,
                onDoubleTap: widget.gesturesEnabled ? widget.onSeekForward : null,
                onVerticalDragStart: (!_isDesktop && widget.gesturesEnabled)
                    ? (d) => _onVerticalDragStart(d, _DragZone.volume)
                    : null,
                onVerticalDragUpdate: (!_isDesktop && widget.gesturesEnabled)
                    ? _onVerticalDragUpdate
                    : null,
                onVerticalDragEnd: (!_isDesktop && widget.gesturesEnabled)
                    ? _onVerticalDragEnd
                    : null,
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),

        // Sleek, minimal side indicator for volume / brightness
        if (_sideIndicator != null)
          Positioned(
            left: _sideIndicator!.zone == _DragZone.brightness ? 32 : null,
            right: _sideIndicator!.zone == _DragZone.volume ? 32 : null,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildSideIndicator(_sideIndicator!),
            ),
          ),

        // Subtle center horizontal seek indicator
        if (_isHorizontalSeeking)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: _buildCenterSeekIndicator(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Minimal, non-Material sleek vertical bar & icon without heavy boxed background
  Widget _buildSideIndicator(_OverlayIndicator indicator) {
    final isBoosted = indicator.isBoosted;
    final progressVal = indicator.zone == _DragZone.volume
        ? (indicator.value > 1.0 ? 1.0 : indicator.value)
        : indicator.value;
    final theme = Theme.of(context);
    final accentColor = isBoosted ? Colors.amber : theme.colorScheme.primary;

    return Container(
      width: 32,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0x33000000), // very subtle translucent darkening
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Percentage text
          Text(
            '${(indicator.value * 100).round()}%',
            style: TextStyle(
              color: isBoosted ? Colors.amber : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Clean, sleek vertical bar without bulky slider container
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: progressVal.clamp(0.0, 1.0),
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isBoosted ? Colors.amber : Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: (isBoosted ? Colors.amber : accentColor).withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Simple clean icon
          Icon(
            indicator.icon,
            color: isBoosted ? Colors.amber : Colors.white,
            size: 16,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ],
      ),
    );
  }

  /// Subtle center floating pill displaying the target seek time and delta (+/- Xs)
  Widget _buildCenterSeekIndicator() {
    final diffMs = _currentSeekPosition.inMilliseconds - _seekStartPosition.inMilliseconds;
    final diffSec = (diffMs / 1000).round();
    final isForward = diffSec >= 0;
    final diffStr = '${isForward ? "+" : ""}${diffSec}s';
    final pack = ref.read(iconPackProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC16171E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isForward ? AppIcons.fastForward(pack) : AppIcons.fastRewind(pack),
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_currentSeekPosition),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            ' / ${_formatDuration(widget.duration)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (diffSec != 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isForward
                    ? Colors.greenAccent.withValues(alpha: 0.2)
                    : Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                diffStr,
                style: TextStyle(
                  color: isForward ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onVerticalDragStart(DragStartDetails details, _DragZone zone) {
    _activeDragZone = zone;
    _dragStartY = details.globalPosition.dy;
    if (zone == _DragZone.volume) {
      _dragStartValue = widget.volume / 100.0;
    } else {
      _dragStartValue = widget.brightness;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_activeDragZone == null) return;
    _sideIndicatorHideTimer?.cancel();

    final screenHeight = MediaQuery.of(context).size.height;
    final sensitivity = (screenHeight * 0.45).clamp(120.0, 300.0);
    final delta = (_dragStartY - details.globalPosition.dy) / sensitivity;

    final pack = ref.read(iconPackProvider);

    if (_activeDragZone == _DragZone.volume) {
      final maxVal = widget.volumeBoostEnabled ? 2.0 : 1.0;
      final newValue = (_dragStartValue + delta).clamp(0.0, maxVal);
      widget.onVolumeChanged(newValue * 100.0);
      setState(() {
        _sideIndicator = _OverlayIndicator(
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
        _sideIndicator = _OverlayIndicator(
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

  void _onVerticalDragEnd(DragEndDetails details) {
    _activeDragZone = null;
    _sideIndicatorHideTimer?.cancel();
    _sideIndicatorHideTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _sideIndicator = null);
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
