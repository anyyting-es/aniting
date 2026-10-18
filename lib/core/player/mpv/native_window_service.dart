import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Windows-only native window wrapper for behavior that lives in the Win32
/// runner (windows/runner/flutter_window.cpp): a monitor-aware fullscreen
/// implementation that works around window_manager's multi-monitor fullscreen bug.
class NativeWindowService {
  static const _channel = MethodChannel('plezy/window');
  static bool _initialized = false;
  static final List<void Function(bool isFullscreen)> _listeners = [];

  /// Hook the native -> Dart callback that keeps fullscreen state in sync.
  static void initialize() {
    if (!Platform.isWindows || _initialized) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
  }

  static void addListener(void Function(bool isFullscreen) listener) {
    _listeners.add(listener);
    initialize();
  }

  static void removeListener(void Function(bool isFullscreen) listener) {
    _listeners.remove(listener);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onFullScreenChanged') {
      final value = call.arguments;
      if (value is bool) {
        for (final listener in List.of(_listeners)) {
          listener(value);
        }
      }
    }
  }

  /// Enter or exit native fullscreen on the current monitor.
  static Future<void> setFullScreen(bool isFullScreen) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod('setFullScreen', {'isFullScreen': isFullScreen});
  }

  /// Query the native fullscreen state. Returns false off-Windows.
  static Future<bool> isFullScreen() async {
    if (!Platform.isWindows) return false;
    return await _channel.invokeMethod<bool>('isFullScreen') ?? false;
  }
}
