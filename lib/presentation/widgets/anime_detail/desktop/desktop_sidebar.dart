import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopSidebar extends ConsumerWidget {
  final String? coverUrl;
  final String? format;
  final String? status;
  final String? airedStr;
  final String? seasonYearStr;
  final num? score;
  final String? studio;

  const DesktopSidebar({
    super.key,
    required this.coverUrl,
    this.format,
    this.status,
    this.airedStr,
    this.seasonYearStr,
    this.score,
    this.studio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 250,
      child: Center(
        child: _DesktopSidebarPoster(
          coverUrl: coverUrl,
          fallbackColor: theme.colorScheme.surfaceContainer,
        ),
      ),
    );
  }
}

class _DesktopSidebarPoster extends StatefulWidget {
  final String? coverUrl;
  final Color fallbackColor;

  const _DesktopSidebarPoster({
    required this.coverUrl,
    required this.fallbackColor,
  });

  @override
  State<_DesktopSidebarPoster> createState() => _DesktopSidebarPosterState();
}

class _DesktopSidebarPosterState extends State<_DesktopSidebarPoster> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          width: 250,
          height: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: _isHovered ? 0.18 : 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.65 : 0.45),
                blurRadius: _isHovered ? 24 : 16,
                offset: Offset(0, _isHovered ? 8 : 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: widget.coverUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 500,
                  memCacheHeight: 720,
                  errorWidget: (_, _, _) => Container(color: widget.fallbackColor),
                )
              : Container(color: widget.fallbackColor),
        ),
      ),
    );
  }
}
