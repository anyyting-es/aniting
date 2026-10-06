import 'package:flutter/material.dart';

class ExploreSkeleton extends StatefulWidget {
  const ExploreSkeleton({super.key});

  @override
  State<ExploreSkeleton> createState() => _ExploreSkeletonState();
}

class _ExploreSkeletonState extends State<ExploreSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final topPadding = MediaQuery.of(context).padding.top;
    final carouselHeight = (isDesktop ? 340.0 : 260.0) + topPadding;
    
    final theme = Theme.of(context);
    final color = theme.colorScheme.surfaceContainerHighest;
    final borderRadius = BorderRadius.circular(10);
    
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = 0.18 + (_controller.value * 0.28);
          return Opacity(
            opacity: opacity,
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero carousel placeholder
            Container(
              height: carouselHeight,
              width: double.infinity,
              color: color,
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            
            // Header controls placeholder
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 140,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: borderRadius,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            
            // Genre chips placeholder
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 6,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Container(
                      width: 70,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 6),
            
            // Curated sections placeholder
            const _FullCuratedSectionSkeletonBody(),
            const _FullCuratedSectionSkeletonBody(),
            const _FullCuratedSectionSkeletonBody(),
          ],
        ),
      ),
    );
  }
}

class _FullCuratedSectionSkeletonBody extends StatelessWidget {
  const _FullCuratedSectionSkeletonBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
        const CuratedSectionRowSkeleton(isAnimated: false),
      ],
    );
  }
}

class CuratedSectionRowSkeleton extends StatefulWidget {
  final bool isAnimated;
  
  const CuratedSectionRowSkeleton({
    super.key,
    this.isAnimated = true,
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
      )..repeat(reverse: true);
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
      return const _CuratedSectionRowBody();
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
        child: const _CuratedSectionRowBody(),
      ),
    );
  }
}

class _CuratedSectionRowBody extends StatelessWidget {
  const _CuratedSectionRowBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.surfaceContainerHighest;
    final borderRadius = BorderRadius.circular(10);
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final cardWidth = isDesktop ? 180.0 : 135.0;
    final carouselHeight = isDesktop ? 320.0 : 252.0;
    final carouselSpacing = isDesktop ? 14.0 : 10.0;

    return SizedBox(
      height: carouselHeight + 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
