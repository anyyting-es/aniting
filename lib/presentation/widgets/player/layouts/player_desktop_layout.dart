import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// YouTube-style desktop watch page with three layout modes
/// ([PlayerLayoutMode]):
///
/// - `normal`: a centered page with a single smooth-scrolling column (header +
///   player + watch content) and a right rail with the episode list. The rail
///   has a fixed width; when the window is too narrow to host it, it collapses
///   into a header button that opens the list as a sheet. Hiding the rail
///   shrinks the page into a narrower centered column with just the video and
///   the comments.
/// - `wide`: the video spans the full window width and the watch content plus
///   the episode rail are stacked underneath, so a slice of the page stays
///   visible while watching.
/// - `cinema`: an immersive full-bleed player that fills the whole window, with
///   the video fitted (black bars where the aspect ratio differs).
class PlayerDesktopLayout extends StatefulWidget {
  final Widget pageHeader;
  final Widget viewport;
  final Widget watchContent;
  final Widget episodesRail;
  final PlayerLayoutMode layoutMode;

  /// Whether the episode rail should be rendered at all.
  final bool showEpisodeRail;
  final bool hideCursorOnVideo;
  final VoidCallback? onVideoEnter;
  final VoidCallback? onVideoHover;
  final VoidCallback? onVideoExit;

  /// Opens the episode list when the rail is hidden. When null, no fallback
  /// button is rendered.
  final VoidCallback? onShowEpisodes;

  /// Soft blurred halo painted around the video (normal mode only). It bleeds
  /// past the video bounds, tinting the surrounding background with the colours
  /// of the current frame.
  final Widget? ambientHalo;

  static const double _pageMaxWidth = 2200;

  /// Narrower, centered page used when the episode rail is hidden.
  static const double _narrowPageMaxWidth = 1180;

  /// Fraction of the window height the video may take in [PlayerLayoutMode.wide]
  /// so a slice of the content below it stays visible.
  static const double _wideVideoHeightFactor = 0.78;

  /// Fixed width of the episode rail. It is the same in every layout mode and
  /// no longer depends on the window size.
  static const double railWidth = 440;

  static const double _minVideoWidth = 480;
  static const double _pageHorizontalPadding = 24;
  static const double _railGap = 20;

  /// How far the ambient halo bleeds past each edge of the video.
  ///
  /// It is a fixed amount (not a fraction of the video) so the room reserved
  /// for it in the page padding can be computed up-front and is guaranteed to
  /// be enough at every window size.
  static const double _haloBleed = 56;

  /// Below this width the rail no longer fits and is replaced by a button.
  static const double railBreakpoint =
      railWidth + _minVideoWidth + _railGap + _pageHorizontalPadding;

  const PlayerDesktopLayout({
    super.key,
    required this.pageHeader,
    required this.viewport,
    required this.watchContent,
    required this.episodesRail,
    this.layoutMode = PlayerLayoutMode.normal,
    this.showEpisodeRail = true,
    this.hideCursorOnVideo = false,
    this.onVideoEnter,
    this.onVideoHover,
    this.onVideoExit,
    this.onShowEpisodes,
    this.ambientHalo,
  });

  @override
  State<PlayerDesktopLayout> createState() => _PlayerDesktopLayoutState();
}

class _PlayerDesktopLayoutState extends State<PlayerDesktopLayout>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController =
      SmoothScrollController(smoothingFactor: 16.0);

  /// Plays a short fade/slide whenever the layout mode changes, so switching
  /// between normal / wide / cinema does not feel like an instant snap.
  late final AnimationController _modeReveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant PlayerDesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutMode != widget.layoutMode) {
      _modeReveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _modeReveal.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Fades + lifts the page while a layout change settles.
  Widget _withModeReveal(Widget child) {
    return AnimatedBuilder(
      animation: _modeReveal,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_modeReveal.value);
        return Opacity(
          opacity: 0.45 + 0.55 * t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
    );
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

    if (widget.layoutMode == PlayerLayoutMode.cinema) {
      return _withModeReveal(
        ScrollConfiguration(
          behavior: scrollConfig,
          child: ColoredBox(
            color: Colors.black,
            child: SizedBox.expand(child: _videoRegion(widget.viewport)),
          ),
        ),
      );
    }

    return _withModeReveal(
      ScrollConfiguration(
        behavior: scrollConfig,
        child: LayoutBuilder(
          builder: (context, viewportConstraints) {
            return widget.layoutMode == PlayerLayoutMode.wide
                ? _buildWideLayout(viewportConstraints)
                : _buildNormalLayout();
          },
        ),
      ),
    );
  }

  Widget _buildNormalLayout() {
    final targetWidth = widget.showEpisodeRail
        ? PlayerDesktopLayout._pageMaxWidth
        : PlayerDesktopLayout._narrowPageMaxWidth;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: targetWidth, end: targetWidth),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, width, child) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: child,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final showRail =
                widget.showEpisodeRail &&
                available >= PlayerDesktopLayout.railBreakpoint;

            return ListView(
              controller: _scrollController,
              // The horizontal padding reserves room for the ambient halo to
              // bleed into. Without it the halo overflowed the video column
              // and the scroll viewport (Clip.hardEdge) sliced it off, leaving
              // a hard vertical seam — the floating shadow that used to show
              // up behind the player on the left side.
              //
              // The room is reserved on both sides so the halo stays perfectly
              // symmetric and never reaches the viewport edge.
              padding: EdgeInsets.fromLTRB(
                PlayerDesktopLayout._pageHorizontalPadding +
                    (widget.ambientHalo != null
                        ? PlayerDesktopLayout._haloBleed
                        : 0),
                0,
                PlayerDesktopLayout._pageHorizontalPadding +
                    (widget.ambientHalo != null
                        ? PlayerDesktopLayout._haloBleed
                        : 0),
                48,
              ),
              children: [
                _buildHeaderRow(railRendered: showRail),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildVideoColumn()),
                    _buildAnimatedRail(showRail: showRail),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Collapses/expands the episode rail with a width wipe instead of snapping
  /// it in and out, so hiding the list feels continuous with the video growing.
  ///
  /// Uses an [Align] with a `widthFactor` (which clips, but does **not** re-lay
  /// the child out narrower) rather than an [OverflowBox]: inside a [ListView]
  /// the vertical constraints are unbounded, and an `OverflowBox` would try to
  /// size itself to infinity.
  Widget _buildAnimatedRail({required bool showRail}) {
    const target = PlayerDesktopLayout.railWidth;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: showRail ? target : 0,
        end: showRail ? target : 0,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, width, child) {
        if (width <= 0.5) return const SizedBox.shrink();
        final t = (width / target).clamp(0.0, 1.0);
        return Padding(
          padding: EdgeInsets.only(left: PlayerDesktopLayout._railGap * t),
          child: ClipRect(
            child: Align(
              alignment: Alignment.topLeft,
              widthFactor: t,
              child: SizedBox(
                width: target,
                child: Opacity(opacity: t, child: child),
              ),
            ),
          ),
        );
      },
      child: widget.episodesRail,
    );
  }

  Widget _buildWideLayout(BoxConstraints viewport) {
    final videoHeight = math.max(
      240.0,
      viewport.maxHeight * PlayerDesktopLayout._wideVideoHeightFactor,
    );
    final showRail = widget.showEpisodeRail;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      children: [
        // No page header here: the video starts at the very top and owns the
        // back button + title in its own overlay top bar.
        SizedBox(
          height: videoHeight,
          width: double.infinity,
          child: _videoRegion(widget.viewport),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: widget.watchContent,
                ),
              ),
              _buildAnimatedRail(showRail: showRail),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow({required bool railRendered}) {
    final showEpisodesButton = !railRendered && widget.onShowEpisodes != null;
    if (!showEpisodesButton) return widget.pageHeader;

    return Row(
      children: [
        Expanded(child: widget.pageHeader),
        const SizedBox(width: 8),
        _EpisodesButton(onTap: widget.onShowEpisodes!),
      ],
    );
  }

  Widget _buildVideoColumn() {
    final halo = widget.ambientHalo;

    if (halo == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _buildVideo()),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: widget.watchContent,
          ),
        ],
      );
    }

    // The halo is painted **behind** the video and bleeds past it on every
    // side.
    //
    // IMPORTANT: both children are `Positioned`, and the halo is listed
    // **first**. A `Stack` paints its positioned children in list order, so
    // the halo goes down and the video goes on top of it.
    //
    // (A non-positioned child would be painted *before* the positioned ones,
    // but a `Positioned` halo alone would end up painted *last* — on top of
    // the video — smearing the blurred frame over the player.)
    //
    // The stack is exactly the size of the video, so the video keeps the full
    // column width and never overlaps the episode rail. [Stack.clipBehavior]
    // is `none`, so the halo paints outside without changing the layout.
    //
    // The room needed for that overflow is reserved by the page padding (see
    // the `ListView` in [_buildNormalLayout]). That is what keeps the scroll
    // viewport from slicing the halo and leaving a floating, hard-edged
    // shadow behind the player.
    return LayoutBuilder(
      builder: (context, constraints) {
        final videoWidth = constraints.maxWidth;
        final videoHeight = videoWidth * 9 / 16;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: videoWidth,
              height: videoHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Bottom layer: the blurred wash. It bleeds past the frame
                  // and dissolves into the page on all four sides.
                  Positioned(
                    left: -PlayerDesktopLayout._haloBleed,
                    right: -PlayerDesktopLayout._haloBleed,
                    top: -PlayerDesktopLayout._haloBleed,
                    bottom: -PlayerDesktopLayout._haloBleed,
                    child: IgnorePointer(child: halo),
                  ),
                  // The video itself, painted on top of the wash.
                  Positioned.fill(child: _buildVideo()),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: widget.watchContent,
            ),
          ],
        );
      },
    );
  }

  /// The rounded player.
  ///
  /// It fills its parent, which is already sized to a 16:9 box.
  Widget _buildVideo() {
    return _videoRegion(
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: widget.viewport,
      ),
    );
  }
}

/// Compact "Episodes" pill shown on the page header when the rail is hidden.
class _EpisodesButton extends ConsumerStatefulWidget {
  final VoidCallback onTap;

  const _EpisodesButton({required this.onTap});

  @override
  ConsumerState<_EpisodesButton> createState() => _EpisodesButtonState();
}

class _EpisodesButtonState extends ConsumerState<_EpisodesButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    return Tooltip(
      message: l10n.showEpisodeList,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedScale(
          scale: _hovering ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovering
                    ? theme.colorScheme.primary.withValues(alpha: 0.6)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: _hovering ? 0.55 : 0.35,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                hoverColor: Colors.transparent,
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.list(iconPack),
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.episodes,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
