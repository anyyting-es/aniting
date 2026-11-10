import 'dart:async';

import 'package:flutter/material.dart';

/// Mounts [child] once the first frame is on screen, after [delay].
///
/// Used for sections that trigger their own network work the moment they are
/// built (comments threads, avatars, long lists). Building them inline makes
/// them compete with whatever the screen is actually opening — playback, for
/// instance — and the result reads as a stutter on entry.
class DeferredMount extends StatefulWidget {
  final Widget child;

  /// How long to wait after the first frame.
  final Duration delay;

  /// What to render in the meantime. Keep it a similar height so the layout
  /// does not jump when the real content appears.
  final Widget? placeholder;

  const DeferredMount({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 900),
    this.placeholder,
  });

  @override
  State<DeferredMount> createState() => _DeferredMountState();
}

class _DeferredMountState extends State<DeferredMount> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Wait for the current frame so the heavy child never lands on it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_visible) return widget.child;
    return widget.placeholder ?? const SizedBox.shrink();
  }
}
