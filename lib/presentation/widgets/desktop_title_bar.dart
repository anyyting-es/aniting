import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global notifier to hide/show the desktop titlebar (e.g. during video fullscreen)
class DesktopTitleBarVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setVisible(bool visible) {
    if (state != visible) {
      state = visible;
    }
  }
}

final desktopTitleBarVisibleProvider =
    NotifierProvider<DesktopTitleBarVisibleNotifier, bool>(DesktopTitleBarVisibleNotifier.new);

/// Global notifier to override caption button brightness (e.g. forced white icons over video player)
class DesktopTitleBarBrightnessNotifier extends Notifier<Brightness?> {
  @override
  Brightness? build() => null;

  void setBrightness(Brightness? brightness) {
    if (state != brightness) {
      state = brightness;
    }
  }
}

final desktopTitleBarBrightnessOverrideProvider =
    NotifierProvider<DesktopTitleBarBrightnessNotifier, Brightness?>(
        DesktopTitleBarBrightnessNotifier.new);

class DesktopTitleBarWidgetNotifier extends Notifier<Widget?> {
  @override
  Widget? build() => null;

  void setWidget(Widget? widget) {
    if (state != widget) {
      state = widget;
    }
  }
}

final desktopTitleBarLeadingProvider =
    NotifierProvider<DesktopTitleBarWidgetNotifier, Widget?>(
        DesktopTitleBarWidgetNotifier.new);

final desktopTitleBarTrailingProvider =
    NotifierProvider<DesktopTitleBarWidgetNotifier, Widget?>(
        DesktopTitleBarWidgetNotifier.new);

/// Pass-through placeholder for DesktopTitleBar (native system titlebar is used).
class DesktopTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const DesktopTitleBar({super.key});

  static const double height = 0.0;

  @override
  Size get preferredSize => Size.zero;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Clean interactive button for custom elements (pass-through when native title bar is used)
class DesktopTitleBarAction extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double width;

  const DesktopTitleBarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.width = 40,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Wrapper that simply passes through [child] since native system title bar is used.
class DesktopWindowFrame extends StatelessWidget {
  final Widget child;
  const DesktopWindowFrame({super.key, required this.child});

  static bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context) => child;
}

/// Preferred size pass-through wrapper for app bars.
class DesktopSafeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;
  final Color? backgroundColor;

  const DesktopSafeAppBar({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) => child;
}
