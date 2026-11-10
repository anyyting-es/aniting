import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:aniting/presentation/widgets/anime_preview/show_preview_data.dart';

/// Hover expansion for feed covers.
///
/// After resting the pointer on a card for [showDelay], the **card itself**
/// grows into a wide rectangle in place: the portrait artwork stretches out,
/// the show's fanart/background fades in underneath it, and the synopsis and
/// metadata fade in over a bottom scrim. Moving away collapses it back.
///
/// It is deliberately not a separate flyout panel and not a modal dialog: the
/// overlay starts exactly on top of the anchor at its original size, so the
/// growth reads as the same poster extending.
///
/// Right-click / long-press / D-pad focus still open the immersive preview;
/// only the pointer-idle behaviour is replaced.
class FeedHoverCard extends StatefulWidget {
  final ShowPreviewData Function() dataBuilder;
  final VoidCallback onOpenDetails;
  final Widget child;

  const FeedHoverCard({
    super.key,
    required this.dataBuilder,
    required this.onOpenDetails,
    required this.child,
  });

  @override
  State<FeedHoverCard> createState() => _FeedHoverCardState();
}

class _FeedHoverCardState extends State<FeedHoverCard> {
  /// How long the pointer must rest on the card before it expands.
  static const Duration _showDelay = Duration(milliseconds: 1400);

  /// Grace period before collapsing once the pointer leaves.
  static const Duration _hideDelay = Duration(milliseconds: 220);

  static const Duration _growDuration = Duration(milliseconds: 420);
  static const Duration _shrinkDuration = Duration(milliseconds: 320);

  /// Cross-fade at the very end of the collapse, right before the overlay is
  /// removed, so swapping back to the real card never pops.
  static const Duration _fadeOutDuration = Duration(milliseconds: 140);

  static const double _screenPadding = 8;

  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _anchorKey = GlobalKey();

  Timer? _showTimer;
  Timer? _hideTimer;
  Timer? _collapseTimer;
  Timer? _fadeOutTimer;

  /// Drives the grow/shrink tween. Kept as plain state (no AnimationController)
  /// so a hot reload can never leave a `late` field uninitialised.
  bool _expanded = false;

  /// True during the final cross-fade of the collapse.
  bool _fadingOut = false;

  bool _isOpen = false;
  bool _pointerInside = false;

  Rect? _anchorRect;
  Size? _targetSize;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _collapseTimer?.cancel();
    _fadeOutTimer?.cancel();
    super.dispose();
  }

  void _handleEnter() {
    _pointerInside = true;
    _hideTimer?.cancel();
    if (_isOpen) {
      // Re-entering while the card is collapsing should expand it again
      // instead of letting the collapse finish and close.
      _collapseTimer?.cancel();
      _fadeOutTimer?.cancel();
      if (!_expanded || _fadingOut) {
        setState(() {
          _expanded = true;
          _fadingOut = false;
        });
      }
      return;
    }
    _showTimer?.cancel();
    _showTimer = Timer(_showDelay, _open);
  }

  void _handleExit() {
    _pointerInside = false;
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!mounted || _pointerInside) return;
      _close();
    });
  }

  Rect? _measureAnchor() {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _open() {
    if (!mounted || _isOpen) return;
    final rect = _measureAnchor();
    if (rect == null) return;

    setState(() {
      _anchorRect = rect;
      _targetSize = _resolveTargetSize(rect);
      _isOpen = true;
      _expanded = true;
      _fadingOut = false;
    });
    _portal.show();
  }

  void _close() {
    if (!mounted || !_isOpen) return;

    _collapseTimer?.cancel();
    _fadeOutTimer?.cancel();
    setState(() => _expanded = false);

    // 1) Collapse back to the card's own rect.
    _collapseTimer = Timer(
      _shrinkDuration + const Duration(milliseconds: 30),
      () {
        if (!mounted || _pointerInside || _expanded) return;

        // 2) Cross-fade into the real card. At this point the overlay shows
        //    the poster over a flat surface, while the card underneath also
        //    has its title, so fading removes the last visible pop.
        setState(() => _fadingOut = true);

        _fadeOutTimer = Timer(_fadeOutDuration, () {
          if (!mounted || _pointerInside || _expanded) return;
          setState(() {
            _isOpen = false;
            _fadingOut = false;
          });
          _portal.hide();
        });
      },
    );
  }

  /// The expanded rectangle: it must **fully cover the original card** at every
  /// frame, otherwise the card underneath keeps peeking out around the growing
  /// overlay and the result reads as a double image. So the height never drops
  /// below the anchor height and the width never below the anchor width.
  Size _resolveTargetSize(Rect rect) {
    final media = MediaQuery.sizeOf(context);
    final maxWidth = media.width - _screenPadding * 2;
    final maxHeight = media.height - _screenPadding * 2;

    final width = (rect.width * 2.15).clamp(rect.width, maxWidth);

    final minHeight = math.min(rect.height, maxHeight);
    final idealHeight = (width * 0.58).clamp(0.0, maxHeight);
    final height = math.max(minHeight, idealHeight);

    return Size(width.toDouble(), height.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleEnter(),
      onExit: (_) => _handleExit(),
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: KeyedSubtree(key: _anchorKey, child: widget.child),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final anchor = _anchorRect;
    final target = _targetSize;
    if (anchor == null || target == null) return const SizedBox.shrink();

    final media = MediaQuery.sizeOf(context);
    final anchorSize = anchor.size;

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _expanded ? 1 : 0),
        duration: _expanded ? _growDuration : _shrinkDuration,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final size = Size.lerp(anchorSize, target, t)!;

          // Grow around the anchor's centre, then shift only as much as needed
          // to stay on screen — never so much that the original card would peek
          // out from under the overlay.
          final leftLo = math.max(_screenPadding, anchor.right - size.width);
          final leftHi = math.min(
            media.width - _screenPadding - size.width,
            anchor.left,
          );
          final left = (anchor.center.dx - size.width / 2).clamp(
            math.min(leftLo, leftHi),
            math.max(leftLo, leftHi),
          );

          final topLo = math.max(_screenPadding, anchor.bottom - size.height);
          final topHi = math.min(
            media.height - _screenPadding - size.height,
            anchor.top,
          );
          final top = (anchor.center.dy - size.height / 2).clamp(
            math.min(topLo, topHi),
            math.max(topLo, topHi),
          );

          return Stack(
            children: [
              Positioned(
                left: left.toDouble(),
                top: top.toDouble(),
                width: size.width,
                height: size.height,
                child: MouseRegion(
                  onEnter: (_) => _handleEnter(),
                  onExit: (_) => _handleExit(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _close();
                      widget.onOpenDetails();
                    },
                    child: AnimatedOpacity(
                      opacity: _fadingOut ? 0 : 1,
                      duration: _fadeOutDuration,
                      curve: Curves.easeOut,
                      child: _ExpandingCover(
                        data: widget.dataBuilder(),
                        progress: t,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The card being stretched: portrait cover on top, fanart underneath, details
/// fading in over a bottom scrim.
class _ExpandingCover extends StatelessWidget {
  final ShowPreviewData data;

  /// 0 = still the original poster, 1 = fully expanded rectangle.
  final double progress;

  const _ExpandingCover({required this.data, required this.progress});

  static double _band(double t, double begin, double end) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return (t - begin) / (end - begin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final fanartT = _band(progress, 0.12, 0.55);
    final detailsT = _band(progress, 0.35, 0.9);
    final posterT = 1 - _band(progress, 0.0, 0.4);

    final fanart = data.backgroundUrl ?? data.coverUrl;
    final poster = data.coverUrl;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant.withValues(
              alpha: 0.25 + 0.2 * progress,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18 + 0.22 * progress),
              blurRadius: 8 + 20 * progress,
              offset: Offset(0, 3 + 9 * progress),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colors.surfaceContainerHigh),

              // Fanart / background, revealed as the poster stretches.
              if (fanart != null && fanart.isNotEmpty)
                Opacity(
                  opacity: fanartT,
                  child: CachedNetworkImage(
                    imageUrl: fanart,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    memCacheWidth: 960,
                    fadeInDuration: const Duration(milliseconds: 180),
                    placeholder: (context, _) =>
                        ColoredBox(color: colors.surfaceContainerHigh),
                    errorWidget: (context, _, _) =>
                        ColoredBox(color: colors.surfaceContainerHigh),
                  ),
                ),

              // Bottom scrim so the text stays readable on any artwork.
              Opacity(
                opacity: fanartT,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.92),
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.12),
                      ],
                    ),
                  ),
                ),
              ),

              // The details, over the bottom of the rectangle.
              Opacity(
                opacity: detailsT,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _Details(data: data),
                  ),
                ),
              ),

              // The original poster, fading out as it "becomes" the fanart.
              // Kept at the card's own 0.72 poster ratio and top-aligned, so the
              // last frames of the collapse are indistinguishable from the real
              // card underneath instead of stretching over the title area.
              if (poster != null && poster.isNotEmpty)
                Opacity(
                  opacity: posterT.clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AspectRatio(
                      aspectRatio: 0.72,
                      child: CachedNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.medium,
                        memCacheWidth: 720,
                        fadeInDuration: const Duration(milliseconds: 120),
                        placeholder: (context, _) =>
                            ColoredBox(color: colors.surfaceContainerHigh),
                        errorWidget: (context, _, _) =>
                            ColoredBox(color: colors.surfaceContainerHigh),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final ShowPreviewData data;

  const _Details({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = data.description?.trim();
    final genres = data.genres.take(3).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            height: 1.15,
            color: Colors.white,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 6),
            ],
          ),
        ),
        if (data.subtitle != null && data.subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            data.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
        const SizedBox(height: 5),
        _MetaRow(data: data),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            genres.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.32,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final ShowPreviewData data;

  const _MetaRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final progress = data.progress;
    final total = data.totalCount;

    final entries = <Widget>[
      for (final meta in data.meta.take(4))
        _chip(theme, meta.icon, meta.label),
      if (progress != null && progress > 0)
        _chip(
          theme,
          Icons.play_arrow_rounded,
          total != null && total > 0 ? '$progress/$total' : '$progress',
          highlight: true,
        ),
    ];

    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 3,
      children: entries,
    );
  }

  Widget _chip(
    ThemeData theme,
    IconData icon,
    String label, {
    bool highlight = false,
  }) {
    final tint = highlight
        ? Colors.white
        : Colors.white.withValues(alpha: 0.78);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.5, color: tint),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10.5,
            color: tint,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
