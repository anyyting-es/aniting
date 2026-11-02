import 'dart:async';

import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:seanime_app/presentation/widgets/anime_preview/immersive_show_preview.dart';
import 'package:seanime_app/presentation/widgets/anime_preview/show_preview_data.dart';

/// Opens the immersive preview for a feed card when the user:
///
/// - right-clicks it,
/// - long-presses it (touch),
/// - lets the pointer rest on it (no movement) for [hoverDelay],
/// - keeps it focused (D-pad / keyboard) for [focusDelay].
///
/// The card must expose a matching `heroTag` on its cover for the shared
/// element flight; when it does not, the preview simply opens without a hero.
class ShowQuickViewDetector extends StatefulWidget {
  final ShowPreviewData Function() dataBuilder;
  final VoidCallback onOpenDetails;
  final Object? heroTag;
  final Widget child;

  /// How long the pointer must stay still over the card.
  final Duration hoverDelay;

  /// How long the card must keep focus.
  final Duration focusDelay;

  const ShowQuickViewDetector({
    super.key,
    required this.dataBuilder,
    required this.onOpenDetails,
    required this.child,
    this.heroTag,
    this.hoverDelay = const Duration(milliseconds: 1300),
    this.focusDelay = const Duration(milliseconds: 1800),
  });

  @override
  State<ShowQuickViewDetector> createState() => _ShowQuickViewDetectorState();
}

class _ShowQuickViewDetectorState extends State<ShowQuickViewDetector> {
  Timer? _hoverTimer;
  Timer? _focusTimer;
  Offset? _lastHoverPosition;

  /// Idle timers are disarmed after opening so closing the preview while the
  /// pointer is still over the card does not reopen it immediately.
  bool _armed = true;
  bool _isOpen = false;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _focusTimer?.cancel();
    super.dispose();
  }

  void _scheduleHover() {
    if (!_armed || _isOpen) return;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(widget.hoverDelay, _openFromIdle);
  }

  void _onHover(PointerHoverEvent event) {
    final last = _lastHoverPosition;
    if (last != null && (event.localPosition - last).distance < 2) {
      // The pointer is essentially still; leave the timer running.
      return;
    }
    _lastHoverPosition = event.localPosition;
    _scheduleHover();
  }

  void _cancelHover() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
  }

  void _onExit() {
    _cancelHover();
    _lastHoverPosition = null;
    _armed = true;
  }

  void _scheduleFocus() {
    if (!_armed || _isOpen) return;
    _focusTimer?.cancel();
    _focusTimer = Timer(widget.focusDelay, _openFromIdle);
  }

  void _cancelFocus() {
    _focusTimer?.cancel();
    _focusTimer = null;
  }

  void _openFromIdle() {
    if (!mounted || !_armed || _isOpen) return;
    _open();
  }

  Future<void> _open() async {
    if (!mounted || _isOpen) return;
    _isOpen = true;
    _armed = false;
    _cancelHover();
    _cancelFocus();

    await showImmersiveShowPreview(
      context: context,
      data: widget.dataBuilder(),
      heroTag: widget.heroTag,
      onOpenDetails: widget.onOpenDetails,
    );

    if (mounted) {
      _isOpen = false;
      // `_armed` stays false until the pointer leaves (or focus is lost), so
      // the idle timer does not reopen the preview over the same card.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _cancelHover(),
      child: MouseRegion(
        onEnter: (_) => _scheduleHover(),
        onHover: _onHover,
        onExit: (_) => _onExit(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _scheduleFocus();
            } else {
              _cancelFocus();
              _armed = true;
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (_) => _open(),
            onLongPress: _open,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
