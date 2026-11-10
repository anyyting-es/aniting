import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aniting/core/theme/theme_provider.dart';
import 'package:aniting/presentation/widgets/desktop_title_bar.dart';
import 'package:aniting/presentation/widgets/player/services/player_playback_coordinator.dart';

typedef PlayerWindowInit = ({int initialTop, int initialHeight, bool initialFullscreen});

/// Service responsible for managing window states, fullscreen transitions,
/// orientation changes (mobile landscape immersive vs portrait), desktop native fullscreen,
/// and Android ExoPlayer native surface bounds synchronization.
class PlayerWindowManager {
  final bool isTv;
  final WidgetRef ref;
  final PlayerPlaybackCoordinator coordinator;

  bool isFullscreen = false;
  bool isTransitioningOrientation = false;
  bool isExiting = false;

  int? _lastExoTop;
  int? _lastExoHeight;

  bool get isDesktop => !Platform.isAndroid && !Platform.isIOS;
  bool _wasMaximized = false;

  PlayerWindowManager({
    required this.isTv,
    required this.ref,
    required this.coordinator,
  });

  Future<void> defaultEnterNativeFullscreen() async {
    _setNativeFullscreenState(true);
    if (Platform.isWindows) {
      await windowManager.setFullScreen(true);
    } else if (isDesktop) {
      _wasMaximized = await windowManager.isMaximized();
      if (_wasMaximized) {
        await windowManager.unmaximize();
      }
      await windowManager.setFullScreen(true);
    }
  }

  Future<void> defaultExitNativeFullscreen() async {
    _setNativeFullscreenState(false);
    if (Platform.isWindows) {
      await windowManager.setFullScreen(false);
    } else if (isDesktop) {
      await windowManager.setFullScreen(false);
      if (_wasMaximized) {
        await windowManager.maximize();
        _wasMaximized = false;
      }
    }
  }

  /// Keeps the UI in sync with the real native fullscreen state.
  ///
  /// On Windows the window_manager plugin can swallow the `leave-full-screen`
  /// event when the window was maximized before entering fullscreen, leaving
  /// listeners (titlebar caption buttons, window frame) stuck in fullscreen
  /// forever. Updating the provider here makes the player state authoritative.
  void _setNativeFullscreenState(bool fullscreen) {
    try {
      ref
          .read(desktopNativeFullscreenProvider.notifier)
          .setFullscreen(fullscreen);
    } catch (_) {}
  }

  /// Calculates initial window state, orientations, and initial surface dimensions.
  ({int initialTop, int initialHeight, bool initialFullscreen}) initWindow() {
    int initialTop = 0;
    int initialHeight = -1;

    if (isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(desktopTitleBarBrightnessOverrideProvider.notifier).setBrightness(Brightness.dark);
      });
    }

    if (isTv) {
      isFullscreen = true;
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      isFullscreen = false;
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        try {
          final themeSettings = ref.read(themeProvider);
          final isDark = themeSettings.themeMode == AppThemeMode.dark ||
              (themeSettings.themeMode == AppThemeMode.system &&
                  WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarDividerColor: Colors.transparent,
            ),
          );
        } catch (_) {}
      }
      if (Platform.isAndroid) {
        try {
          final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
          if (view != null) {
            final physicalWidth = view.physicalSize.width;
            final physicalHeight = view.physicalSize.height;
            if (physicalHeight > physicalWidth && physicalWidth > 0) {
              initialTop = view.padding.top.round();
              initialHeight = (physicalWidth / (16 / 9)).round();
            }
          }
        } catch (_) {}
      }
    }

    return (
      initialTop: initialTop,
      initialHeight: initialHeight,
      initialFullscreen: isFullscreen,
    );
  }

  /// Synchronizes Android ExoPlayer surface layout with Flutter's container bounds.
  void updateExoSurfaceBounds(BuildContext context, {required bool effectiveFullscreen}) {
    if (!Platform.isAndroid || !coordinator.isUsingExoPlayer) return;

    final mq = MediaQuery.of(context);

    if (effectiveFullscreen) {
      if (_lastExoTop != 0 || _lastExoHeight != -1) {
        _lastExoTop = 0;
        _lastExoHeight = -1;
        coordinator.setSurfaceBounds(top: 0, height: -1);
      }
    } else {
      final density = mq.devicePixelRatio;
      final top = (mq.padding.top * density).round();
      final width = mq.size.width;
      final height = ((width / (16 / 9)) * density).round();
      if (_lastExoTop != top || _lastExoHeight != height) {
        _lastExoTop = top;
        _lastExoHeight = height;
        coordinator.setSurfaceBounds(top: top, height: height);
      }
    }
  }

  /// Toggles between fullscreen and normal window/embedded mode.
  void toggleFullscreen({
    required VoidCallback onUpdateUi,
    VoidCallback? onOrientationTransitionStarted,
  }) {
    if (isDesktop) {
      isFullscreen = !isFullscreen;
      onUpdateUi();
      if (isFullscreen) {
        try {
          ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(false);
        } catch (_) {}
        defaultEnterNativeFullscreen();
      } else {
        try {
          ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(true);
        } catch (_) {}
        defaultExitNativeFullscreen();
      }
    } else {
      final willBeFullscreen = !isFullscreen;
      isFullscreen = willBeFullscreen;
      isTransitioningOrientation = true;
      onOrientationTransitionStarted?.call();
      onUpdateUi();

      if (willBeFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        try {
          final themeSettings = ref.read(themeProvider);
          final isDark = themeSettings.themeMode == AppThemeMode.dark ||
              (themeSettings.themeMode == AppThemeMode.system &&
                  WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarDividerColor: Colors.transparent,
            ),
          );
        } catch (_) {}
      }

      Future.delayed(const Duration(milliseconds: 380), () {
        isTransitioningOrientation = false;
        onUpdateUi();
      });
    }
  }

  /// Handles clean player exit with black curtain and restored orientations.
  Future<void> handleExit({
    required BuildContext context,
    required Future<void> Function() onSaveProgress,
    required VoidCallback onUpdateUi,
  }) async {
    if (!isDesktop && isFullscreen && !isTv) {
      toggleFullscreen(onUpdateUi: onUpdateUi);
      return;
    }

    if (isExiting) return;

    isExiting = true;
    // On desktop the route fades out using the current frame (snapshot), so
    // rebuilding the whole player into a black curtain right before popping
    // only adds a heavy frame to the exit path.
    if (!isDesktop) {
      onUpdateUi();
    }

    if (isFullscreen && isDesktop) {
      try {
        ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(true);
        defaultExitNativeFullscreen();
      } catch (_) {}
    }

    // Freeze the video before starting the route's reverse transition. Closing
    // over a still-playing video makes the fade compete with decoding and GPU
    // texture updates; pausing first makes the exit feel as smooth as closing a
    // paused player. The timeout keeps the back action responsive even if the
    // native pause takes a moment.
    try {
      await coordinator
          .pauseAsync()
          .timeout(const Duration(milliseconds: 70));
    } catch (_) {}

    // Instantly close the player route so the UI never stutters or waits for network/I/O
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Perform session progress recording and orientation restore asynchronously.
    // The progress write updates providers watched by the feed/cards, so it is
    // delayed until the reverse transition has fully finished.
    Future.microtask(() async {
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } catch (_) {}
      }
    });

    Future.delayed(const Duration(milliseconds: 200), () async {
      try {
        await onSaveProgress();
      } catch (_) {}
    });
  }

  /// Restores native window and orientation defaults on dispose.
  void dispose({VoidCallback? onCustomDispose}) {

    if (Platform.isAndroid) {
      try {
        const MethodChannel('com.anyyting.aniting/exo_player')
            .invokeMethod('setBrightness', {'brightness': -1.0});
      } catch (_) {}
    }

    if (isFullscreen && isDesktop) {
      defaultExitNativeFullscreen();
    }
    try {
      ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(true);
      ref.read(desktopTitleBarBrightnessOverrideProvider.notifier).setBrightness(null);
    } catch (_) {}

    onCustomDispose?.call();

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      try {
        final themeSettings = ref.read(themeProvider);
        final isDark = themeSettings.themeMode == AppThemeMode.dark ||
            (themeSettings.themeMode == AppThemeMode.system &&
                WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        );
      } catch (_) {}
    }
  }
}
