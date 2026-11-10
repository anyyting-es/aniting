import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the Android ExoPlayer native `SurfaceView` is currently the video
/// output. That surface lives **behind** the Flutter window, so the app must
/// not paint an opaque root background while it is active: doing so covers the
/// video completely. The player's own chrome paints its opaque regions on top.
class NativeVideoSurfaceActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool active) {
    if (state != active) state = active;
  }
}

final nativeVideoSurfaceActiveProvider =
    NotifierProvider<NativeVideoSurfaceActiveNotifier, bool>(
      NativeVideoSurfaceActiveNotifier.new,
    );
