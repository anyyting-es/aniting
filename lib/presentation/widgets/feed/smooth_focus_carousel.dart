import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Intercepts and swallows Flutter's default instantaneous `showOnScreen` request
/// (which jumps without animation and aligns strictly to the edge).
/// This allows our custom center-locked smooth focus controller to command the viewport.
class BlockShowOnScreen extends SingleChildRenderObjectWidget {
  const BlockShowOnScreen({super.key, required super.child});

  @override
  RenderBox createRenderObject(BuildContext context) => _RenderBlockShowOnScreen();
}

class _RenderBlockShowOnScreen extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    // Intentionally swallow the default jump request to allow custom smooth animation.
  }
}

/// A horizontally scrolling carousel designed for media centers, TV DPAD navigation,
/// and smooth mouse/keyboard traversal.
///
/// **Center-Locked Behavior**:
/// - As the user moves rightward from the beginning, the focus travels freely until it reaches
///   the center of the viewport.
/// - Once at the center, the focused card remains visually anchored near the center while the
///   list smoothly slides underneath (`animateTo`).
/// - When the end of the scrollable extent is reached, the focus unlatches from the center
///   and steps card-by-card to the end of the row.
/// - The exact inverse behavior occurs when traveling back to the left.
/// - When moving vertically between rows, the parent vertical feed smoothly scrolls to keep
///   the row and its header comfortably centered in view.
class SmoothFocusCarousel extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double itemWidth;
  final double spacing;
  final double height;
  final EdgeInsets padding;
  final ScrollPhysics? physics;
  final ValueChanged<int>? onFocusedIndexChanged;

  const SmoothFocusCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.height,
    this.spacing = 14.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.physics,
    this.onFocusedIndexChanged,
  });

  /// Mathematical helper to compute the exact center-locked scroll offset for an item.
  static double calculateCenterLockedOffset({
    required int index,
    required double itemWidth,
    required double spacing,
    required double paddingLeft,
    required double viewportWidth,
    required double maxScrollExtent,
  }) {
    final itemLeft = paddingLeft + index * (itemWidth + spacing);
    final itemCenter = itemLeft + (itemWidth / 2);
    final idealScroll = itemCenter - (viewportWidth / 2);
    return idealScroll.clamp(0.0, maxScrollExtent);
  }

  @override
  State<SmoothFocusCarousel> createState() => _SmoothFocusCarouselState();
}

class _SmoothFocusCarouselState extends State<SmoothFocusCarousel> {
  static final List<_SmoothFocusCarouselState> _activeCarousels = [];

  late final ScrollController _scrollController;
  final Map<int, FocusNode> _itemNodes = {};
  int? _currentlyFocusedIndex;
  int? get currentlyFocusedIndex => _currentlyFocusedIndex;

  @override
  void initState() {
    super.initState();
    _activeCarousels.add(this);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _activeCarousels.remove(this);
    for (final node in _itemNodes.values) {
      node.dispose();
    }
    _itemNodes.clear();
    _scrollController.dispose();
    super.dispose();
  }

  void focusBeginning() {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }

    void tryFocus() {
      if (!mounted) return;
      final node0 = _itemNodes[0];
      if (node0 != null) {
        final target = node0.descendants.where((n) => n.canRequestFocus).firstOrNull;
        if (target != null) {
          target.requestFocus();
          _onItemFocused(0, context);
          return;
        }
      }
    }

    tryFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryFocus();
    });
  }

  bool _navigateVertical({required bool isDown}) {
    final eligible = _activeCarousels.where((c) {
      if (!c.mounted) return false;
      if (c == this) return false;
      if (c.widget.itemCount <= 0) return false;
      final box = c.context.findRenderObject() as RenderBox?;
      return box != null && box.attached && box.hasSize;
    }).toList();

    if (eligible.isEmpty) return false;

    final myBox = context.findRenderObject() as RenderBox?;
    if (myBox == null || !myBox.attached || !myBox.hasSize) return false;
    final myY = myBox.localToGlobal(Offset.zero).dy;

    _SmoothFocusCarouselState? targetCarousel;
    if (isDown) {
      final below = eligible
          .where((c) => (c.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy > myY + 25)
          .toList();
      if (below.isNotEmpty) {
        below.sort((a, b) {
          final aY = (a.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
          final bY = (b.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
          return aY.compareTo(bY);
        });
        targetCarousel = below.first;
      }
    } else {
      final above = eligible
          .where((c) => (c.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy < myY - 25)
          .toList();
      if (above.isNotEmpty) {
        above.sort((a, b) {
          final aY = (a.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
          final bY = (b.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
          return bY.compareTo(aY);
        });
        targetCarousel = above.first;
      }
    }

    if (targetCarousel != null) {
      targetCarousel.focusBeginning();
      return true;
    }
    return false;
  }

  void _onItemFocused(int index, BuildContext itemContext) {
    _currentlyFocusedIndex = index;
    widget.onFocusedIndexChanged?.call(index);

    // 1. Smooth Center-Locked Horizontal Scroll
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final viewportWidth = position.viewportDimension;
      final maxScroll = position.maxScrollExtent;

      final targetScroll = SmoothFocusCarousel.calculateCenterLockedOffset(
        index: index,
        itemWidth: widget.itemWidth,
        spacing: widget.spacing,
        paddingLeft: widget.padding.left,
        viewportWidth: viewportWidth,
        maxScrollExtent: maxScroll,
      );

      final currentOffset = _scrollController.offset;
      if ((targetScroll - currentOffset).abs() > 1.0) {
        _scrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }

    // 2. Smooth Vertical Scroll for the Parent Feed Screen
    _smoothScrollParentVertical(context);
  }

  void _smoothScrollParentVertical(BuildContext rowContext) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final verticalScrollable = Scrollable.maybeOf(rowContext);
      if (verticalScrollable == null ||
          verticalScrollable.position.axis != Axis.vertical) {
        return;
      }

      final verticalPosition = verticalScrollable.position;
      if (!verticalPosition.hasContentDimensions) return;

      final renderBox = rowContext.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return;

      final viewportBox = verticalScrollable.context.findRenderObject() as RenderBox?;
      if (viewportBox == null || !viewportBox.hasSize || !viewportBox.attached) return;

      try {
        final rowOffsetInViewport = renderBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
        final rowHeight = renderBox.size.height;
        final viewportHeight = verticalPosition.viewportDimension;
        final maxVerticalScroll = verticalPosition.maxScrollExtent;

        // Position the row so that it occupies the upper-middle viewing area (42% down the screen)
        // leaving room above for the section title and status/search bar.
        final idealOffsetInViewport = (viewportHeight - rowHeight) * 0.42;
        final currentScroll = verticalPosition.pixels;
        final diff = rowOffsetInViewport - idealOffsetInViewport;

        // Animate smoothly if the row is substantially off-center (> 40px)
        if (diff.abs() > 40.0) {
          final targetVertical = (currentScroll + diff).clamp(0.0, maxVerticalScroll);
          if ((targetVertical - currentScroll).abs() > 1.0) {
            verticalPosition.animateTo(
              targetVertical,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            );
          }
        }
      } catch (_) {
        // Safe catch for mid-flight layout transitions
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (rowHasFocus) {
          if (!rowHasFocus) {
            _currentlyFocusedIndex = null;
          }
        },
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: ListView.separated(
            controller: _scrollController,
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: widget.physics,
            cacheExtent: 400,
            padding: widget.padding,
            itemCount: widget.itemCount,
            separatorBuilder: (context, index) => SizedBox(width: widget.spacing),
            itemBuilder: (context, index) {
              final node = _itemNodes.putIfAbsent(
                index,
                () => FocusNode(debugLabel: 'CarouselItem_${identityHashCode(this)}_$index'),
              );
              return Builder(
                builder: (itemContext) {
                  return Focus(
                    focusNode: node,
                    canRequestFocus: false,
                    descendantsAreFocusable: true,
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        _onItemFocused(index, itemContext);
                      }
                    },
                    onKeyEvent: (fNode, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          if (_navigateVertical(isDown: true)) {
                            return KeyEventResult.handled;
                          }
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          if (_navigateVertical(isDown: false)) {
                            return KeyEventResult.handled;
                          }
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: BlockShowOnScreen(
                      child: widget.itemBuilder(context, index),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
