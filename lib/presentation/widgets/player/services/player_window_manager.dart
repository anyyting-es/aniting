import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_playback_coordinator.dart';

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

  PlayerWindowManager({
    required this.isTv,
    required this.ref,
    required this.coordinator,
  });

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

    if (isDesktop) {
      isExiting = true;
      try {
        coordinator.pause();
      } catch (_) {}

      if (isFullscreen) {
        try {
          ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(true);
          defaultExitNativeFullscreen();
        } catch (_) {}
      }

      unawaited(onSaveProgress());

      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    isExiting = true;
    onUpdateUi();

    if (isFullscreen && isDesktop) {
      try {
        ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(true);
        defaultExitNativeFullscreen();
      } catch (_) {}
    }

    await onSaveProgress();

    try {
      coordinator.pause();
    } catch (_) {}

    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await Future.delayed(const Duration(milliseconds: 60));
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
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
