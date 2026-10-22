import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tv_audio_feedback.dart';

/// A clean, minimalist 10-foot console-style focusable tile for TV.
/// No heavy glowing layers, no fluorescent colors, just pure responsive feedback.
class WelcomeTvFocusTile extends StatefulWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isSelected;
  final bool autoFocus;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const WelcomeTvFocusTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.isSelected = false,
    this.autoFocus = false,
    this.focusNode,
    this.padding,
    this.borderRadius = 14.0,
  });

  @override
  State<WelcomeTvFocusTile> createState() => _WelcomeTvFocusTileState();
}

class _WelcomeTvFocusTileState extends State<WelcomeTvFocusTile> {
  late FocusNode _focusNode;
  bool _isInternalFocusNode = false;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    }
  }

  @override
  void dispose() {
    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    if (_isFocused != hasFocus) {
      setState(() => _isFocused = hasFocus);
      if (hasFocus) {
        TvAudioFeedback.playMove();
      }
    }
  }

  void _handleTap() {
    TvAudioFeedback.playSelect();
    widget.onTap();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.space) {
        _handleTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _isFocused || _isHovered;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autoFocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedScale(
            scale: isActive ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                color: isActive
                    ? Colors.white.withValues(alpha: 0.12)
                    : widget.isSelected
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white.withValues(alpha: 0.03),
                border: Border.all(
                  color: isActive
                      ? Colors.white
                      : widget.isSelected
                          ? Colors.white38
                          : Colors.white.withValues(alpha: 0.08),
                  width: isActive ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle(
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: isActive || widget.isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 16,
                            color: isActive
                                ? Colors.white
                                : (widget.isSelected
                                    ? Colors.white
                                    : Colors.white70),
                          ),
                          child: widget.title,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 3),
                          DefaultTextStyle(
                            style: theme.textTheme.bodyMedium!.copyWith(
                              fontSize: 12.5,
                              color: isActive
                                  ? Colors.white70
                                  : Colors.white38,
                            ),
                            child: widget.subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 12),
                    widget.trailing!,
                  ] else if (widget.isSelected) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
