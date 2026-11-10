import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:window_manager/window_manager.dart';

/// Global notifier to hide/show the desktop titlebar (e.g. during video fullscreen).
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
    NotifierProvider<DesktopTitleBarVisibleNotifier, bool>(
  DesktopTitleBarVisibleNotifier.new,
);

/// Global notifier tracking the real native fullscreen state.
///
/// The window_manager plugin can drop its `leave-full-screen` event on Windows
/// when the window was maximized before entering fullscreen (it restores with
/// `SC_MAXIMIZE` instead of `SIZE_RESTORED`, so the internal state machine
/// stays stuck in `FULLSCREEN_ENTERED`). The player therefore updates this
/// provider directly so the titlebar and window frame never depend on a
/// missing native event.
class DesktopNativeFullscreenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setFullscreen(bool fullscreen) {
    if (state != fullscreen) {
      state = fullscreen;
    }
  }
}

final desktopNativeFullscreenProvider =
    NotifierProvider<DesktopNativeFullscreenNotifier, bool>(
  DesktopNativeFullscreenNotifier.new,
);

/// Global notifier to override caption button brightness (e.g. forced white icons over video player).
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
  DesktopTitleBarBrightnessNotifier.new,
);

class DesktopTitleBarWidgetNotifier extends Notifier<Widget?> {
  @override
  Widget? build() => null;

  void setWidget(Widget? widget) {
    if (state != widget) {
      state = widget;
    }
  }
}

class DesktopTitleBarClearanceNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  void setClearance(double? clearance) {
    if (state != clearance) {
      state = clearance;
    }
  }
}

final desktopTitleBarLeadingClearanceProvider =
    NotifierProvider<DesktopTitleBarClearanceNotifier, double?>(
  DesktopTitleBarClearanceNotifier.new,
);

final desktopTitleBarLeadingProvider =
    NotifierProvider<DesktopTitleBarWidgetNotifier, Widget?>(
  DesktopTitleBarWidgetNotifier.new,
);

final desktopTitleBarTrailingProvider =
    NotifierProvider<DesktopTitleBarWidgetNotifier, Widget?>(
  DesktopTitleBarWidgetNotifier.new,
);

/// Native-feeling in-app desktop title bar.
class DesktopTitleBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const DesktopTitleBar({super.key});

  static const double height = 34.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  ConsumerState<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends ConsumerState<DesktopTitleBar>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initWindowState() async {
    try {
      final max = await windowManager.isMaximized();
      final fs = await windowManager.isFullScreen();
      if (mounted && _isMaximized != max) {
        setState(() => _isMaximized = max);
      }
      ref.read(desktopNativeFullscreenProvider.notifier).setFullscreen(fs);
    } catch (_) {}
  }

  /// Re-reads the native window state a couple of times, because on Windows
  /// `window_manager` posts `SC_MAXIMIZE`/`SC_RESTORE` asynchronously and may
  /// swallow the matching event when the window was maximized before entering
  /// fullscreen. Without this the maximize/restore button gets stuck.
  void _scheduleWindowStateSync() {
    _initWindowState();
    for (final delay in const [220, 480]) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _initWindowState();
      });
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    ref.read(desktopNativeFullscreenProvider.notifier).setFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    ref.read(desktopNativeFullscreenProvider.notifier).setFullscreen(false);
  }

  void _toggleMaximize() async {
    // Never trust the cached flag here: after leaving native fullscreen the
    // plugin can report a stale `_isMaximized == false` while the window is
    // actually maximized, which made the button a no-op (it kept sending
    // "maximize" instead of "restore to floating").
    bool isMaximized = _isMaximized;
    try {
      isMaximized = await windowManager.isMaximized();
    } catch (_) {}
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    _scheduleWindowStateSync();
  }

  @override
  Widget build(BuildContext context) {
    // The native maximize event can also be swallowed after leaving fullscreen,
    // so refresh the maximized/restore icon whenever the player gives the
    // titlebar back.
    ref.listen<bool>(desktopTitleBarVisibleProvider, (previous, next) {
      if (next && previous == false) {
        _scheduleWindowStateSync();
      }
    });

    final isExplicitlyVisible = ref.watch(desktopTitleBarVisibleProvider);
    final isNativeFullscreen = ref.watch(desktopNativeFullscreenProvider);
    final isVideoPlayerActive = ref.watch(isVideoPlayerActiveProvider);

    if (!isExplicitlyVisible || isNativeFullscreen) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final brightnessOverride =
        ref.watch(desktopTitleBarBrightnessOverrideProvider);
    final effectiveBrightness = brightnessOverride ?? theme.brightness;
    final isDark = effectiveBrightness == Brightness.dark;
    final fgColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.85);

    final leadingWidget = ref.watch(desktopTitleBarLeadingProvider);
    final trailingWidget = ref.watch(desktopTitleBarTrailingProvider);
    final clearanceOverride =
        ref.watch(desktopTitleBarLeadingClearanceProvider);
    final double leftClearance = clearanceOverride ??
        (isVideoPlayerActive ? 360.0 : 80.0);

    return SizedBox(
      height: DesktopTitleBar.height,
      child: Row(
        children: [
          // Custom leading widget or a click-through gap (IgnorePointer) that leaves
          // a dead space in the titlebar so underlying page controls (e.g. back button)
          // can be clicked and hovered without interference from any angle.
          if (leadingWidget != null)
            leadingWidget
          else
            IgnorePointer(
              child: SizedBox(
                width: leftClearance,
                height: DesktopTitleBar.height,
              ),
            ),

          // Entire center area is a draggable space (double-click maximizes/restores)
          Expanded(
            child: DragToMoveArea(
              child: Container(
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
          ),

          // Optional trailing screen actions
          ?trailingWidget,

          // Window caption buttons (Minimize, Maximize/Restore, Close)
          _WindowCaptionButton(
            icon: CustomPaint(
              size: const Size(10, 10),
              painter: _MinimizeIconPainter(fgColor),
            ),
            hoverColor: fgColor.withValues(alpha: 0.1),
            onPressed: () => windowManager.minimize(),
          ),
          _WindowCaptionButton(
            icon: CustomPaint(
              size: const Size(10, 10),
              painter: _isMaximized
                  ? _RestoreIconPainter(fgColor)
                  : _MaximizeIconPainter(fgColor),
            ),
            hoverColor: fgColor.withValues(alpha: 0.1),
            onPressed: _toggleMaximize,
          ),
          _WindowCaptionButton(
            icon: CustomPaint(
              size: const Size(10, 10),
              painter: _CloseIconPainter(fgColor),
            ),
            hoverColor: const Color(0xFFE81123),
            hoverIconColor: Colors.white,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

/// Interactive button for desktop caption controls with smooth hover and click feedback.
class _WindowCaptionButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? hoverIconColor;

  const _WindowCaptionButton({
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<_WindowCaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: DesktopTitleBar.height,
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          alignment: Alignment.center,
          child: (_isHovered && widget.hoverIconColor != null)
              ? IconTheme(
                  data: IconThemeData(color: widget.hoverIconColor),
                  child: CustomPaint(
                    size: const Size(10, 10),
                    painter: _CloseIconPainter(widget.hoverIconColor!),
                  ),
                )
              : widget.icon,
        ),
      ),
    );
  }
}

// ─── DESKTOP CAPTION VECTOR ICON PAINTERS ────────────────────────────────────

class _MinimizeIconPainter extends CustomPainter {
  final Color color;
  _MinimizeIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MinimizeIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MaximizeIconPainter extends CustomPainter {
  final Color color;
  _MaximizeIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MaximizeIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RestoreIconPainter extends CustomPainter {
  final Color color;
  _RestoreIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Back square
    canvas.drawPath(
      Path()
        ..moveTo(2.5, 0.5)
        ..lineTo(size.width - 0.5, 0.5)
        ..lineTo(size.width - 0.5, size.height - 2.5)
        ..lineTo(size.width - 2.5, size.height - 2.5)
        ..lineTo(size.width - 2.5, 2.5)
        ..lineTo(2.5, 2.5)
        ..close(),
      paint,
    );

    // Front square
    canvas.drawRect(
      Rect.fromLTWH(0.5, 2.5, size.width - 3.0, size.height - 3.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RestoreIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CloseIconPainter extends CustomPainter {
  final Color color;
  _CloseIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      const Offset(0.5, 0.5),
      Offset(size.width - 0.5, size.height - 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 0.5, 0.5),
      Offset(0.5, size.height - 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CloseIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Helper wrapper that renders [DesktopTitleBar] above the application on desktop platforms,
/// applies rounded window corners with a subtle native contour, and enables border resizing on Linux.
class DesktopWindowFrame extends ConsumerStatefulWidget {
  final Widget child;
  const DesktopWindowFrame({super.key, required this.child});

  static bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  ConsumerState<DesktopWindowFrame> createState() => _DesktopWindowFrameState();
}

class _DesktopWindowFrameState extends ConsumerState<DesktopWindowFrame>
    with WindowListener {
  bool _isMaximized = false;
  bool _isFocused = true;

  @override
  void initState() {
    super.initState();
    if (DesktopWindowFrame.isDesktopPlatform) {
      windowManager.addListener(this);
      _checkWindowState();
    }
  }

  @override
  void dispose() {
    if (DesktopWindowFrame.isDesktopPlatform) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkWindowState() async {
    try {
      final max = await windowManager.isMaximized();
      final fs = await windowManager.isFullScreen();
      final focused = await windowManager.isFocused();
      if (mounted) {
        setState(() {
          _isMaximized = max;
          _isFocused = focused;
        });
      }
      ref.read(desktopNativeFullscreenProvider.notifier).setFullscreen(fs);
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    ref.read(desktopNativeFullscreenProvider.notifier).setFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    ref.read(desktopNativeFullscreenProvider.notifier).setFullscreen(false);
  }

  @override
  void onWindowFocus() {
    if (mounted) setState(() => _isFocused = true);
  }

  @override
  void onWindowBlur() {
    if (mounted) setState(() => _isFocused = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopWindowFrame.isDesktopPlatform) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFullScreen = ref.watch(desktopNativeFullscreenProvider);
    final isClamped = _isMaximized || isFullScreen;
    final double radius = isClamped ? 0.0 : 10.0;

    Widget windowContent = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: isClamped
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: _isFocused ? 0.14 : 0.07)
                      : Colors.black.withValues(alpha: _isFocused ? 0.14 : 0.07),
                  width: 1.0,
                ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DesktopTitleBar(),
            ),
          ],
        ),
      ),
    );

    if (Platform.isLinux) {
      return DragToResizeArea(
        resizeEdgeSize: 6,
        enableResizeEdges: isClamped ? [] : null,
        child: windowContent,
      );
    }

    return windowContent;
  }
}

/// A preferred-size wrapper that adds top padding equivalent to [DesktopTitleBar.height]
/// on desktop platforms (Windows, Linux, macOS) so that standard [AppBar] content
/// (such as back buttons, titles, and actions) is not obstructed by the custom titlebar.
class DesktopSafeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;
  final Color? backgroundColor;

  const DesktopSafeAppBar({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Size get preferredSize {
    final extra =
        DesktopWindowFrame.isDesktopPlatform ? DesktopTitleBar.height : 0.0;
    return Size.fromHeight(child.preferredSize.height + extra);
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopWindowFrame.isDesktopPlatform) {
      return child;
    }
    final theme = Theme.of(context);
    final bgColor = backgroundColor ??
        theme.appBarTheme.backgroundColor ??
        theme.scaffoldBackgroundColor;
    return Container(
      color: bgColor,
      padding: const EdgeInsets.only(top: DesktopTitleBar.height),
      child: child,
    );
  }
}
