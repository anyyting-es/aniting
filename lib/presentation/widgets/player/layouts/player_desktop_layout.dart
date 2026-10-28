import 'package:flutter/material.dart';

/// YouTube-style desktop watch page.
///
/// - Normal: the whole page (header, player, watch content and episodes rail)
///   is constrained to a max width and centered as a single unit.
/// - Theater mode: an immersive full-bleed player that fills the whole window,
///   with the video fitted (black bars where the aspect ratio differs).
class PlayerDesktopLayout extends StatelessWidget {
  final Widget pageHeader;
  final Widget viewport;
  final Widget watchContent;
  final Widget episodesRail;
  final bool isTheaterMode;
  final bool hideCursorOnVideo;
  final VoidCallback? onVideoEnter;
  final VoidCallback? onVideoHover;
  final VoidCallback? onVideoExit;

  static const double railWidth = 400;
  static const double _pageMaxWidth = 2200;

  const PlayerDesktopLayout({
    super.key,
    required this.pageHeader,
    required this.viewport,
    required this.watchContent,
    required this.episodesRail,
    this.isTheaterMode = false,
    this.hideCursorOnVideo = false,
    this.onVideoEnter,
    this.onVideoHover,
    this.onVideoExit,
  });

  Widget _videoRegion(Widget child) {
    return MouseRegion(
      cursor: hideCursorOnVideo
          ? SystemMouseCursors.none
          : SystemMouseCursors.basic,
      onEnter: onVideoEnter == null ? null : (_) => onVideoEnter!(),
      onHover: onVideoHover == null ? null : (_) => onVideoHover!(),
      onExit: onVideoExit == null ? null : (_) => onVideoExit!(),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollConfig =
        ScrollConfiguration.of(context).copyWith(scrollbars: false);

    if (isTheaterMode) {
      return ScrollConfiguration(
        behavior: scrollConfig,
        child: ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(child: _videoRegion(viewport)),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: scrollConfig,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
          child: Column(
            children: [
              pageHeader,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 48),
                        children: [
                          _videoRegion(
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: viewport,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          watchContent,
                        ],
                      ),
                    ),
                    SizedBox(
                      width: railWidth,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 12, 24),
                        child: episodesRail,
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
}
