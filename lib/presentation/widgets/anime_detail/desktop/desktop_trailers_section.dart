import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class DesktopTrailersSection extends ConsumerStatefulWidget {
  final String? trailerId;
  final String? trailerSite;
  final VoidCallback onTap;

  const DesktopTrailersSection({
    super.key,
    required this.trailerId,
    this.trailerSite,
    required this.onTap,
  });

  @override
  ConsumerState<DesktopTrailersSection> createState() => _DesktopTrailersSectionState();
}

class _DesktopTrailersSectionState extends ConsumerState<DesktopTrailersSection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.trailerId == null || widget.trailerId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isYouTube = widget.trailerSite?.toLowerCase() == 'youtube' || widget.trailerSite == null;
    final thumbnailUrl = isYouTube
        ? 'https://img.youtube.com/vi/${widget.trailerId}/hqdefault.jpg'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.trailersAndVideos,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              width: 330,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: thumbnailUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 200),
                              errorWidget: (_, _, _) => Container(color: Colors.black45),
                            )
                          : Container(color: Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.officialTrailer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _isHovered
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white : theme.colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
