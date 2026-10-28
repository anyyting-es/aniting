import 'package:flutter/material.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';

/// YouTube-style desktop watch page.
///
/// - Normal: a centered page with a single smooth-scrolling column (header +
///   player + watch content) and a right rail with the episode list.
/// - Theater mode: an immersive full-bleed player that fills the whole window,
///   with the video fitted (black bars where the aspect ratio differs).
class PlayerDesktopLayout extends StatefulWidget {
  final Widget pageHeader;
  final Widget viewport;
  final Widget watchContent;
  final Widget episodesRail;
  final bool isTheaterMode;
  final bool hideCursorOnVideo;
  final VoidCallback? onVideoEnter;
  final VoidCallback? onVideoHover;
  final VoidCallback? onVideoExit;

  static const double railWidth = 520;
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

  @override
  State<PlayerDesktopLayout> createState() => _PlayerDesktopLayoutState();
}

class _PlayerDesktopLayoutState extends State<PlayerDesktopLayout> {
  final ScrollController _scrollController =
      SmoothScrollController(smoothingFactor: 16.0);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _videoRegion(Widget child) {
    return MouseRegion(
      cursor: widget.hideCursorOnVideo
          ? SystemMouseCursors.none
          : SystemMouseCursors.basic,
      onEnter:
          widget.onVideoEnter == null ? null : (_) => widget.onVideoEnter!(),
      onHover:
          widget.onVideoHover == null ? null : (_) => widget.onVideoHover!(),
      onExit: widget.onVideoExit == null ? null : (_) => widget.onVideoExit!(),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollConfig =
        ScrollConfiguration.of(context).copyWith(scrollbars: false);

    if (widget.isTheaterMode) {
      return ScrollConfiguration(
        behavior: scrollConfig,
        child: ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(child: _videoRegion(widget.viewport)),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: scrollConfig,
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: PlayerDesktopLayout._pageMaxWidth),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 48),
            children: [
              widget.pageHeader,
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _videoRegion(
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: widget.viewport,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: widget.watchContent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: PlayerDesktopLayout.railWidth,
                    child: widget.episodesRail,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
