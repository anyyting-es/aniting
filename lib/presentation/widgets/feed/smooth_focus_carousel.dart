import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/theme/app_dpad_navigator.dart';

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

  bool get _isActive {
    if (!mounted) return false;
    final ctx = context;
    if (!ctx.mounted) return false;
    Size? screenSize;
    ModalRoute<dynamic>? route;
    try {
      if (!TickerMode.of(ctx)) return false;
      if (!Visibility.of(ctx)) return false;
      screenSize = MediaQuery.maybeOf(ctx)?.size;
      route = ModalRoute.of(ctx);
    } catch (_) {
      return false;
    }
    if (route != null && !route.isCurrent) return false;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;

    // Exclude rows parked in another PageView page while keeping rows that are
    // merely below the fold of the current vertical feed.
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (screenSize != null &&
        (rect.right <= 0.0 || rect.left >= screenSize.width)) {
      return false;
    }
    return true;
  }

  double? _contentY(BuildContext ctx) {
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    var y = box.localToGlobal(Offset.zero).dy;
    final vertical = Scrollable.maybeOf(ctx, axis: Axis.vertical);
    if (vertical != null && vertical.position.hasPixels) {
      y += vertical.position.pixels;
    }
    return y;
  }

  FocusNode? _firstFocusableDescendant(FocusNode? node) {
    if (node == null) return null;
    for (final child in node.descendants) {
      final ctx = child.context;
      if (ctx == null || !ctx.mounted) continue;
      if (!AppDpadNavigator.canReceiveFocus(child)) continue;
      try {
        if (!TickerMode.of(ctx) || !Visibility.of(ctx)) continue;
      } catch (_) {
        continue;
      }
      final renderObject = ctx.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        continue;
      }
      return child;
    }
    return null;
  }

  bool focusBeginning() => focusIndex(0);

  /// Focuses the item at [index], scrolling the carousel when the item has not
  /// been built yet.
  bool focusIndex(int index) {
    if (!mounted || widget.itemCount <= 0) return false;
    final targetIndex = index.clamp(0, widget.itemCount - 1).toInt();

    final target = _firstFocusableDescendant(_itemNodes[targetIndex]);
    if (target != null) {
      // requestFocus() marks the next focus and Flutter applies it in a
      // microtask, so we report success based on the request, not hasFocus.
      target.requestFocus();
      return true;
    }

    if (!_scrollController.hasClients) return false;

    final position = _scrollController.position;
    final offset = SmoothFocusCarousel.calculateCenterLockedOffset(
      index: targetIndex,
      itemWidth: widget.itemWidth,
      spacing: widget.spacing,
      paddingLeft: widget.padding.left,
      viewportWidth: position.viewportDimension,
      maxScrollExtent: position.maxScrollExtent,
    );
    if ((offset - position.pixels).abs() > 1.0) {
      _scrollController.jumpTo(offset);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstFocusableDescendant(_itemNodes[targetIndex])?.requestFocus();
    });
    return true;
  }

  /// Focuses the item whose horizontal center is closest to [globalX].
  ///
  /// Keeping the same column when moving between rows feels much more natural
  /// than always jumping to the first card of the next row.
  bool focusClosestTo(double globalX) {
    if (!mounted || widget.itemCount <= 0) return false;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final contentX =
        globalX - box.localToGlobal(Offset.zero).dx + scrollOffset;
    final stride = widget.itemWidth + widget.spacing;
    final index = ((contentX - widget.padding.left - widget.itemWidth / 2) /
            stride)
        .round()
        .clamp(0, widget.itemCount - 1)
        .toInt();

    return focusIndex(index);
  }

  bool _navigateVertical({required bool isDown}) {
    if (!_isActive) return false;

    final myY = _contentY(context);
    if (myY == null) return false;
    final myScrollable = Scrollable.maybeOf(context, axis: Axis.vertical);

    final candidates = <_CarouselTarget>[];
    for (final carousel in _activeCarousels) {
      if (carousel == this || !carousel._isActive) continue;
      if (carousel.widget.itemCount <= 0) continue;

      final carouselScrollable = Scrollable.maybeOf(
        carousel.context,
        axis: Axis.vertical,
      );
      // Rows must belong to the same vertical feed. This avoids mixing the
      // current page with another tab or a nested scroll view.
      if (myScrollable != null) {
        if (!identical(carouselScrollable, myScrollable)) continue;
      } else if (carouselScrollable != null) {
        continue;
      }

      final y = carousel._contentY(carousel.context);
      if (y == null) continue;
      if (isDown ? y <= myY + 20.0 : y >= myY - 20.0) continue;

      candidates.add(_CarouselTarget(carousel, y));
    }

    if (candidates.isEmpty) return false;

    candidates.sort(
      (a, b) => isDown ? a.y.compareTo(b.y) : b.y.compareTo(a.y),
    );

    final focused = FocusManager.instance.primaryFocus;
    final globalX = focused != null && focused.context != null
        ? focused.rect.center.dx
        : (context.findRenderObject() as RenderBox?)
                  ?.localToGlobal(Offset.zero)
                  .dx ??
              0.0;

    for (final candidate in candidates) {
      if (candidate.carousel.focusClosestTo(globalX)) return true;
    }
    return false;
  }

  void _onItemFocused(int index) {
    if (!_isActive) return;
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
              return Focus(
                focusNode: node,
                canRequestFocus: false,
                descendantsAreFocusable: true,
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    _onItemFocused(index);
                  }
                },
                onKeyEvent: (fNode, event) {
                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
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
          ),
        ),
      ),
    );
  }
}

class _CarouselTarget {
  const _CarouselTarget(this.carousel, this.y);

  final _SmoothFocusCarouselState carousel;
  final double y;
}
