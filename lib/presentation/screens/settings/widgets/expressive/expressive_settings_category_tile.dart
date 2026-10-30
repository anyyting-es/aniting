import 'package:flutter/material.dart';

/// Navigation row for the settings sidebar.
///
/// Mirrors the flat navigation tiles used on the profile screen: a single
/// leading icon plus the section title, no card chrome and no subtitle. The
/// selected row is tinted so the current section stays obvious.
class ExpressiveSettingsCategoryTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool showChevron;
  final bool isDpadFocused;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const ExpressiveSettingsCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    this.showChevron = false,
    this.isDpadFocused = false,
    this.focusNode,
    required this.onTap,
  });

  static const double _radius = 10;

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final titleColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.onSurface;

    // Focus ring only visible during active D-pad navigation. Never on mouse clicks or touch.
    final showDpadFocusRing = widget.isDpadFocused && _focused;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        focusNode: _focusNode,
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(
          ExpressiveSettingsCategoryTile._radius,
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: colorScheme.onSurface.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.onSurface.withValues(alpha: 0.06)
                : null,
            borderRadius: BorderRadius.circular(
              ExpressiveSettingsCategoryTile._radius,
            ),
            border: Border.all(
              color: showDpadFocusRing
                  ? colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(widget.icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w600,
                    fontSize: 15,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
