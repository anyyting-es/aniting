import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

bool get _isInTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Placeholder row used while a curated Explore section is loading.
class CuratedSectionRowSkeleton extends StatefulWidget {
  final bool isAnimated;
  final bool isTv;

  const CuratedSectionRowSkeleton({
    super.key,
    this.isAnimated = true,
    this.isTv = false,
  });

  @override
  State<CuratedSectionRowSkeleton> createState() => _CuratedSectionRowSkeletonState();
}

class _CuratedSectionRowSkeletonState extends State<CuratedSectionRowSkeleton> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isAnimated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      );
      if (!_isInTest) {
        _controller!.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAnimated) {
      return _CuratedSectionRowBody(isTv: widget.isTv);
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) {
          final opacity = 0.18 + (_controller!.value * 0.28);
          return Opacity(
            opacity: opacity,
            child: child,
          );
        },
        child: _CuratedSectionRowBody(isTv: widget.isTv),
      ),
    );
  }
}

class _CuratedSectionRowBody extends StatelessWidget {
  final bool isTv;

  const _CuratedSectionRowBody({required this.isTv});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.surfaceContainerHighest;
    final borderRadius = BorderRadius.circular(10);
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    // Misma geometría que las secciones reales de Explorar para que el
    // esqueleto no dé un salto de tamaño al llegar los datos.
    final cardWidth = isTv ? 150.0 : (isDesktop ? 215.0 : 155.0);
    final carouselSpacing = isDesktop ? 14.0 : 10.0;
    final cardHeight = ((cardWidth - 8.0) / 0.72) + 71.0;
    final carouselHeight = cardHeight + (isDesktop ? 6.0 : 4.0);

    return SizedBox(
      height: carouselHeight + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        itemCount: 5,
        separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
        itemBuilder: (context, index) {
          return Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: color,
              borderRadius: borderRadius,
            ),
          );
        },
      ),
    );
  }
}
