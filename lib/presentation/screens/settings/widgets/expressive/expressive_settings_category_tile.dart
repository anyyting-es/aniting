import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// Navigation row for the settings sidebar.
///
/// Rows of a group join vertically: only the group's outer corners are
/// rounded, the touching ones stay nearly square. The selected row softens its
/// corners into a compact pill. Built on [M3ECard] so hover, focus, ripple and
/// the state layer come from the Material 3 Expressive tokens.
class ExpressiveSettingsCategoryTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final bool showChevron;
  final bool isDpadFocused;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const ExpressiveSettingsCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    this.showChevron = false,
    this.isDpadFocused = false,
    this.focusNode,
    required this.onTap,
  });

  static const double _selectedRadius = 16;
  static const double _outerRadius = 14;
  static const double _innerRadius = 4;

  @override
  State<ExpressiveSettingsCategoryTile> createState() =>
      _ExpressiveSettingsCategoryTileState();
}

class _ExpressiveSettingsCategoryTileState
    extends State<ExpressiveSettingsCategoryTile> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _attachFocusNode(widget.focusNode);
  }

  @override
  void didUpdateWidget(ExpressiveSettingsCategoryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode(widget.focusNode);
    }
  }

  @override
  void dispose() {
    _detachFocusNode();
    super.dispose();
  }

  void _attachFocusNode(FocusNode? node) {
    _ownsFocusNode = node == null;
    _focusNode = node ?? FocusNode(debugLabel: 'settings-category-tile');
    _focused = _focusNode.hasFocus;
    _focusNode.addListener(_onFocusChanged);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  void _onFocusChanged() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  BorderRadius _resolveRadius() {
    if (widget.isSelected) {
      return BorderRadius.circular(
        ExpressiveSettingsCategoryTile._selectedRadius,
      );
    }
    return BorderRadius.vertical(
      top: Radius.circular(
        widget.isFirst
            ? ExpressiveSettingsCategoryTile._outerRadius
            : ExpressiveSettingsCategoryTile._innerRadius,
      ),
      bottom: Radius.circular(
        widget.isLast
            ? ExpressiveSettingsCategoryTile._outerRadius
            : ExpressiveSettingsCategoryTile._innerRadius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final titleColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.onSurface;
    final subtitleColor = widget.isSelected
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.85)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    // Focus ring only visible during active D-pad navigation. Never on mouse clicks or touch.
    final showDpadFocusRing = widget.isDpadFocused && _focused;

    final BorderSide tileBorder;
    if (showDpadFocusRing) {
      tileBorder = BorderSide(
        color: colorScheme.primary,
        width: 2,
      );
    } else {
      tileBorder = const BorderSide(
        color: Colors.transparent,
        width: 1.2,
      );
    }

    final cardColor = widget.isSelected
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.surfaceContainerHigh,
          )
        : colorScheme.surfaceContainerHigh;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: M3ECard(
        focusNode: _focusNode,
        onPressed: widget.onTap,
        elevation: 0,
        // The card's swipe layer always consumes Left/Right to reveal its
        // sides, even when there are none. Disabling that mode lets the
        // sidebar use Right to jump into the options panel.
        swipeMode: M3ECardSwipeMode.dismiss,
        color: cardColor,
        borderRadius: _resolveRadius(),
        border: tileBorder,
        showFocusRing: false,
        animationDuration: const Duration(milliseconds: 220),
        animationCurve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        semanticLabel: '${widget.title}. ${widget.subtitle}',
        child: Row(
          children: [
            Icon(widget.icon, size: 21, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: titleColor,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: subtitleColor,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (widget.showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
