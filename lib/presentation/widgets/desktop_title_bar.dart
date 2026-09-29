import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// Global notifier to hide/show the desktop titlebar (e.g. during video fullscreen)
class DesktopTitleBarVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setVisible(bool visible) => state = visible;
}

final desktopTitleBarVisibleProvider =
    NotifierProvider<DesktopTitleBarVisibleNotifier, bool>(DesktopTitleBarVisibleNotifier.new);

/// Modern, sleek Windows/Desktop title bar embedded directly inside the Flutter app.
class DesktopTitleBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const DesktopTitleBar({super.key});

  static const double height = 34.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  ConsumerState<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends ConsumerState<DesktopTitleBar> with WindowListener {
  bool _isMaximized = false;
  bool _isFullScreen = false;

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
    final max = await windowManager.isMaximized();
    final fs = await windowManager.isFullScreen();
    if (mounted) {
      setState(() {
        _isMaximized = max;
        _isFullScreen = fs;
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
    if (mounted) setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullScreen = false);
  }

  void _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExplicitlyVisible = ref.watch(desktopTitleBarVisibleProvider);
    if (!isExplicitlyVisible || _isFullScreen) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.85);

    return Container(
      height: DesktopTitleBar.height,
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          // Entire left & center area is a draggable space (double click maximizes/restores)
          Expanded(
            child: DragToMoveArea(
              child: Container(
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
          ),

          // Windows Caption Buttons (Minimize, Maximize/Restore, Close)
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

/// Caption button with hover state conforming to Windows 11 styling.
class _WindowCaptionButton extends StatefulWidget {
  final Widget icon;
  final Color hoverColor;
  final Color? hoverIconColor;
  final VoidCallback onPressed;

  const _WindowCaptionButton({
    required this.icon,
    required this.hoverColor,
    this.hoverIconColor,
    required this.onPressed,
  });

  @override
  State<_WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<_WindowCaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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

// ─── WINDOWS 11 VECTOR ICON PAINTERS ──────────────────────────────────────────

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
  bool shouldRepaint(covariant _MinimizeIconPainter oldDelegate) => oldDelegate.color != color;
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
    canvas.drawRect(Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0), paint);
  }

  @override
  bool shouldRepaint(covariant _MaximizeIconPainter oldDelegate) => oldDelegate.color != color;
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
    canvas.drawRect(Rect.fromLTWH(0.5, 2.5, size.width - 3.0, size.height - 3.0), paint);
  }

  @override
  bool shouldRepaint(covariant _RestoreIconPainter oldDelegate) => oldDelegate.color != color;
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
    canvas.drawLine(const Offset(0.5, 0.5), Offset(size.width - 0.5, size.height - 0.5), paint);
    canvas.drawLine(Offset(size.width - 0.5, 0.5), Offset(0.5, size.height - 0.5), paint);
  }

  @override
  bool shouldRepaint(covariant _CloseIconPainter oldDelegate) => oldDelegate.color != color;
}

/// Helper wrapper that conditionally renders [DesktopTitleBar] above the application on desktop platforms.
class DesktopWindowFrame extends StatelessWidget {
  final Widget child;
  const DesktopWindowFrame({super.key, required this.child});

  static bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) {
      return child;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const DesktopTitleBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
