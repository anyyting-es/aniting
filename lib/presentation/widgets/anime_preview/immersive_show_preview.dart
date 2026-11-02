import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/utils/synopsis_utils.dart';
import 'package:seanime_app/presentation/widgets/anime_preview/show_preview_data.dart';

/// Opens the immersive preview as a transparent full-screen route, so the
/// background stays visible (dimmed) around it and the poster can fly with a [Hero].
Future<void> showImmersiveShowPreview({
  required BuildContext context,
  required ShowPreviewData data,
  Object? heroTag,
  VoidCallback? onOpenDetails,
}) {
  final navigator = Navigator.of(context);
  return navigator.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (pageContext, animation, secondaryAnimation) =>
          ImmersiveShowPreview(
            data: data,
            heroTag: heroTag,
            onOpenDetails: onOpenDetails,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.965, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Immersive preview dialog with default fixed dimensions and one-click expand capability.
class ImmersiveShowPreview extends ConsumerStatefulWidget {
  final ShowPreviewData data;
  final Object? heroTag;
  final VoidCallback? onOpenDetails;

  const ImmersiveShowPreview({
    super.key,
    required this.data,
    this.heroTag,
    this.onOpenDetails,
  });

  @override
  ConsumerState<ImmersiveShowPreview> createState() =>
      _ImmersiveShowPreviewState();
}

class _ImmersiveShowPreviewState extends ConsumerState<ImmersiveShowPreview> {
  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final accent = widget.data.accentColor ?? theme.colorScheme.primary;

    final targetWidth = size.width - 32;
    final targetHeight = math.min(520.0, size.height - 32);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: _background(accent, size),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          width: targetWidth,
                          height: targetHeight,
                          margin: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 680;
                              if (compact) {
                                return SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                        child: GestureDetector(
                                          onTap: _openDetails,
                                          child: _artwork(compact: true),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _panel(
                                        context,
                                        accent,
                                        scrollable: false,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: _openDetails,
                                    child: _artwork(compact: false),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: SizedBox(
                                      height: _artworkHeight(),
                                      child: _panel(
                                        context,
                                        accent,
                                        scrollable: true,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 14,
                      child: IconButton(
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.38),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails() {
    final onOpenDetails = widget.onOpenDetails;
    if (onOpenDetails == null) return;
    Navigator.of(context).pop();
    onOpenDetails();
  }

  Widget _background(Color accent, Size size) {
    final imageUrl =
        widget.data.episode?.imageUrl ??
        widget.data.coverUrl ??
        widget.data.backgroundUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF07080C)),
        if (imageUrl != null && imageUrl.isNotEmpty)
          Opacity(
            opacity: 0.55,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 64,
                sigmaY: 64,
                tileMode: TileMode.decal,
              ),
              child: Transform.scale(
                scale: 1.25,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 900,
                  filterQuality: FilterQuality.low,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.85),
              radius: 1.15,
              colors: [
                accent.withValues(alpha: 0.40),
                accent.withValues(alpha: 0.12),
                Colors.transparent,
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.86),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
      ],
    );
  }

  Widget _artwork({required bool compact}) {
    final episodeImage = widget.data.episode?.imageUrl;
    final isWide = episodeImage != null && episodeImage.trim().isNotEmpty;
    final imageUrl = isWide ? episodeImage : widget.data.coverUrl;
    final width = compact
        ? (isWide ? double.infinity : 160.0)
        : (isWide ? 340.0 : 250.0);
    final aspect = isWide ? 16 / 9 : 0.72;
    final radius = isWide ? 18.0 : 22.0;

    Widget image = SizedBox(
      width: width,
      height: width / aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: isWide ? 1080 : 640,
                memCacheHeight: isWide ? 620 : 900,
                filterQuality: FilterQuality.medium,
                placeholder: (_, _) =>
                    const ColoredBox(color: Color(0xFF1A1D27)),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Color(0xFF1A1D27),
                  child: Icon(
                    Icons.movie_rounded,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              )
            : const ColoredBox(
                color: Color(0xFF1A1D27),
                child: Icon(
                  Icons.movie_rounded,
                  color: Colors.white24,
                  size: 40,
                ),
              ),
      ),
    );

    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return SizedBox(
      width: width,
      height: width / aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: image,
      ),
    );
  }

  double _artworkHeight() {
    final hasEpisodeImage =
        widget.data.episode?.imageUrl?.trim().isNotEmpty ?? false;
    final width = hasEpisodeImage ? 340.0 : 250.0;
    return width / (hasEpisodeImage ? 16 / 9 : 0.72);
  }

  Widget _panel(
    BuildContext context,
    Color accent, {
    required bool scrollable,
  }) {
    final episode = widget.data.episode;
    final episodeTitle = episode?.title?.trim();
    final hasEpisodeTitle = episodeTitle != null && episodeTitle.isNotEmpty;
    final heading = hasEpisodeTitle ? episodeTitle : widget.data.title;
    final subheading = hasEpisodeTitle
        ? widget.data.title
        : widget.data.subtitle;
    final badgeLabel =
        episode?.label ?? (widget.data.isManga ? 'MANGA' : 'ANIME');
    final rawDescription = (episode?.synopsis?.trim().isNotEmpty ?? false)
        ? episode!.synopsis!.trim()
        : widget.data.description;
    final description = cleanSynopsis(rawDescription);
    final episodeRating = episode?.rating;
    final metaItems = <ShowPreviewMeta>[
      if (episode != null) ...[
        if (episode.rating != null)
          ShowPreviewMeta(episode.rating!, Icons.star_rounded),
        if (episode.duration != null)
          ShowPreviewMeta(episode.duration!, Icons.schedule_rounded),
        if (episode.airDate != null)
          ShowPreviewMeta(episode.airDate!, Icons.calendar_today_rounded),
      ],
      ...widget.data.meta.where(
        (item) =>
            episode == null ||
            item.icon != Icons.star_rounded ||
            episodeRating == null,
      ),
    ];

    final content = Padding(
      padding: EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: Color.lerp(accent, Colors.white, 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openDetails,
            child: Text(
              heading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.14,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (subheading != null) ...[
            const SizedBox(height: 6),
            Text(
              subheading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (metaItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in metaItems)
                  _MetaPill(label: item.label, icon: item.icon),
              ],
            ),
          ],
          if (widget.data.genres.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final genre in widget.data.genres)
                  _GenrePill(label: genre, accent: accent),
              ],
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.80),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenrePill extends StatelessWidget {
  final String label;
  final Color accent;

  const _GenrePill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color.lerp(accent, Colors.white, 0.25),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
