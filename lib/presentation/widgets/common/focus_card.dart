import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';

/// Modern Web & Media Center Focusable Card.
/// Provides smooth 1.04x scaling, border accent illumination, and DPAD focus traversal.
class FocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool enableScale;
  final FocusNode? focusNode;
  final bool autoFocus;

  const FocusCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.enableScale = true,
    this.focusNode,
    this.autoFocus = false,
  });

  @override
  State<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<FocusCard> {
  bool _isHovered = false;
  bool _isFocused = false;
  late final FocusNode _internalFocusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _internalFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final bg = widget.backgroundColor ?? colors.surface;
    final inactiveBorder = colors.border;

    return Focus(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autoFocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: _isHovered ? (Color.lerp(bg, Colors.white, 0.04) ?? bg) : bg,
              borderRadius: BorderRadius.circular(widget.borderRadius ?? colors.borderRadius),
              border: Border.all(
                color: _isFocused ? Colors.white : inactiveBorder,
                width: _isFocused ? 2.0 : 1.0,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
