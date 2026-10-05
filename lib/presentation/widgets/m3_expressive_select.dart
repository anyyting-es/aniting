import 'package:flutter/material.dart';

/// Item data definition for [M3ExpressiveSelect].
class M3SelectItem<T> {
  final T value;
  final String label;
  final Widget? leading;
  final Widget? trailing;
  final String? subtitle;

  const M3SelectItem({
    required this.value,
    required this.label,
    this.leading,
    this.trailing,
    this.subtitle,
  });
}

/// A modern, expressive Material 3 Select / Dropdown component inspired by shadcn-m3e.
/// Features:
/// - Rounded trigger pill with smooth hover feedback & animated 180° chevron.
/// - Floating overlay menu with spring/cubic scale & fade animation.
/// - Active item tinted with accent color and a crisp checkmark icon (`✓`).
/// - Backdrop shadow, dark/light theme elevation, and outside-tap auto dismissal.
class M3ExpressiveSelect<T> extends StatefulWidget {
  final T? value;
  final List<M3SelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? placeholder;
  final double? width;
  final double minWidth;
  final double height;
  final EdgeInsetsGeometry padding;
  final Widget? leading;
  final BorderRadius? borderRadius;

  const M3ExpressiveSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.placeholder,
    this.width,
    this.minWidth = 0,
    this.height = 32,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.leading,
    this.borderRadius,
  });

  @override
  State<M3ExpressiveSelect<T>> createState() => _M3ExpressiveSelectState<T>();
}

class _M3ExpressiveSelectState<T> extends State<M3ExpressiveSelect<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _isOpen = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 140),
    );

    // Expressive spring pop ("salto con boom" / overshoot dynamics)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_animController);

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
  }

  @override
  void didUpdateWidget(M3ExpressiveSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If opened and items or value changed, refresh overlay after the current build phase finishes
    if (_isOpen && _overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen && _overlayEntry != null) {
          _overlayEntry!.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    _closeDropdown(immediate: true);
    _animController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (widget.onChanged == null || widget.items.isEmpty) return;
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    if (_isOpen) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _isOpen = true;
    _overlayEntry = _createOverlayEntry();
    overlay.insert(_overlayEntry!);
    _animController.forward(from: 0.0);
    setState(() {});
  }

  void _closeDropdown({bool immediate = false}) {
    if (!_isOpen && _overlayEntry == null) return;
    _isOpen = false;
    if (mounted) setState(() {});

    if (immediate) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
      _animController.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  void _selectValue(T value) {
    _closeDropdown();
    widget.onChanged?.call(value);
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final measuredWidth = renderBox?.size.width ?? (widget.width ?? 140);
    final targetWidth = widget.width ?? (widget.minWidth > 0 ? (measuredWidth < widget.minWidth ? widget.minWidth : measuredWidth) : measuredWidth);
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(10);

    return OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Stack(
          children: [
            // Full-screen barrier detector to close on outside click
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDropdown,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

            // Floating follower anchored below trigger with EXACT same width as trigger
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 5),
              child: SizedBox(
                width: targetWidth,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          width: targetWidth,
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2028) : theme.colorScheme.surfaceContainerHigh,
                            borderRadius: effectiveRadius,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                                blurRadius: 18,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: effectiveRadius,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: widget.items.map((item) {
                                  final isSelected = widget.value == item.value;
                                  return _M3SelectItemTile<T>(
                                    item: item,
                                    isSelected: isSelected,
                                    onTap: () => _selectValue(item.value),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedItem = widget.items.where((i) => i.value == widget.value).firstOrNull;
    final displayText = selectedItem?.label ?? widget.placeholder ?? '';
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(10);

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: (widget.onChanged != null && widget.items.isNotEmpty)
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: widget.height,
            width: widget.width,
            constraints: (widget.width == null && widget.minWidth > 0)
                ? BoxConstraints(minWidth: widget.minWidth)
                : null,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: _isOpen
                  ? (isDark ? Colors.white.withValues(alpha: 0.10) : theme.colorScheme.surfaceContainerHighest)
                  : (_isHovered
                      ? (isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerHigh)),
              borderRadius: effectiveRadius,
              border: Border.all(
                color: _isOpen
                    ? theme.colorScheme.primary.withValues(alpha: 0.7)
                    : (_isHovered
                        ? (isDark ? Colors.white.withValues(alpha: 0.18) : theme.colorScheme.outlineVariant)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35))),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _isOpen
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _M3SelectItemTile<T> extends StatefulWidget {
  final M3SelectItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;

  const _M3SelectItemTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_M3SelectItemTile<T>> createState() => _M3SelectItemTileState<T>();
}

class _M3SelectItemTileState<T> extends State<_M3SelectItemTile<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    if (widget.isSelected) {
      bg = theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14);
    } else if (_isHovered) {
      bg = isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.surfaceContainerHighest;
    } else {
      bg = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (widget.item.leading != null) ...[
                widget.item.leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: widget.isSelected
                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                        : (isDark ? Colors.white.withValues(alpha: 0.9) : theme.colorScheme.onSurface),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: isDark ? Colors.white : theme.colorScheme.primary,
                ),
              ] else if (widget.item.trailing != null) ...[
                const SizedBox(width: 6),
                widget.item.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
