import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// A sleek, compact, semi-transparent search bar tailored for Anime and Manga feeds.
/// Integrates directly with in-page search (no modal sheet), featuring instant typing,
/// back-button navigation to restore feed content, and responsive desktop constraints.
class CompactSearchBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onBack;
  final VoidCallback? onClear;
  final bool isSearching;
  final double maxWidth;

  const CompactSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onBack,
    this.onClear,
    this.isSearching = false,
    this.maxWidth = 540.0,
  });

  @override
  ConsumerState<CompactSearchBar> createState() => _CompactSearchBarState();
}

class _CompactSearchBarState extends ConsumerState<CompactSearchBar> {
  bool _isHovered = false;
  late final FocusNode _internalFocusNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _effectiveFocusNode.addListener(_onStateChange);
    widget.controller.addListener(_onStateChange);
  }

  @override
  void didUpdateWidget(CompactSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChange);
      widget.controller.addListener(_onStateChange);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode).removeListener(_onStateChange);
      _effectiveFocusNode.addListener(_onStateChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onStateChange);
    widget.controller.removeListener(_onStateChange);
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  bool get _isActive => _isHovered || _effectiveFocusNode.hasFocus || widget.isSearching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);

    // Semi-transparent, calm and neutral palette
    final defaultBg = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);

    final activeBg = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);

    final defaultBorder = theme.colorScheme.outlineVariant.withValues(alpha: 0.22);
    final activeBorder = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : theme.colorScheme.primary.withValues(alpha: 0.7);

    final showBackButton = widget.isSearching || widget.controller.text.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 40,
            decoration: BoxDecoration(
              color: _isActive ? activeBg : defaultBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isActive ? activeBorder : defaultBorder,
                width: _isActive ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  key: const ValueKey('compact_search_leading_slot'),
                  width: 38,
                  height: 38,
                  child: Center(
                    child: showBackButton
                        ? IconButton(
                            key: const ValueKey('compact_search_back_btn'),
                            focusNode: FocusNode(canRequestFocus: false, skipTraversal: true),
                            icon: Icon(AppIcons.arrowLeft(iconPack), size: 19),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            tooltip: 'Volver',
                            color: _isActive
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            onPressed: widget.onBack,
                          )
                        : Padding(
                            key: const ValueKey('compact_search_icon_padding'),
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              AppIcons.search(iconPack),
                              size: 18,
                              color: _isActive
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  key: const ValueKey('compact_search_expanded_slot'),
                  child: TextField(
                    key: const ValueKey('compact_search_text_field'),
                    controller: widget.controller,
                    focusNode: _effectiveFocusNode,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                SizedBox(
                  key: const ValueKey('compact_search_trailing_slot'),
                  width: 36,
                  height: 38,
                  child: Center(
                    child: widget.controller.text.isNotEmpty
                        ? IconButton(
                            key: const ValueKey('compact_search_clear_btn'),
                            focusNode: FocusNode(canRequestFocus: false, skipTraversal: true),
                            icon: Icon(AppIcons.close(iconPack), size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 38),
                            tooltip: 'Limpiar',
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            onPressed: widget.onClear,
                          )
                        : const SizedBox.shrink(),
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
