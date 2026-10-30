import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/player_rail_fraction_provider.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';

/// YouTube-style desktop watch page.
///
/// - Normal: a centered page with a single smooth-scrolling column (header +
///   player + watch content) and a right rail with the episode list. The rail
///   can be widened/narrowed by dragging the divider between the video and the
///   list (its width is persisted), and when the window is too narrow to host
///   the rail it collapses into a header button that opens the list as a sheet.
/// - Theater mode: an immersive full-bleed player that fills the whole window,
///   with the video fitted (black bars where the aspect ratio differs).
class PlayerDesktopLayout extends ConsumerStatefulWidget {
  final Widget pageHeader;
  final Widget viewport;
  final Widget watchContent;
  final Widget episodesRail;
  final bool isTheaterMode;
  final bool hideCursorOnVideo;
  final VoidCallback? onVideoEnter;
  final VoidCallback? onVideoHover;
  final VoidCallback? onVideoExit;

  /// Opens the episode list when the rail is collapsed (too narrow window).
  /// When null, no fallback button is rendered.
  final VoidCallback? onShowEpisodes;

  static const double railWidth = 520;
  static const double _pageMaxWidth = 2200;

  /// Reserved so the video keeps a usable size before the rail is collapsed.
  static const double _minRailWidth = 340;
  static const double _maxRailWidth = 760;
  static const double _minVideoWidth = 480;
  static const double _dividerWidth = 20;
  static const double _pageHorizontalPadding = 24;

  /// Below this width the side rail no longer fits and is replaced by a button.
  static const double railBreakpoint =
      _minRailWidth + _minVideoWidth + _dividerWidth + _pageHorizontalPadding;

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
    this.onShowEpisodes,
  });

  @override
  ConsumerState<PlayerDesktopLayout> createState() =>
      _PlayerDesktopLayoutState();
}

class _PlayerDesktopLayoutState extends ConsumerState<PlayerDesktopLayout> {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth;
              final showRail =
                  available >= PlayerDesktopLayout.railBreakpoint;

              final maxRailForWindow = math.max(
                PlayerDesktopLayout._minRailWidth,
                math.min(
                  PlayerDesktopLayout._maxRailWidth,
                  available -
                      PlayerDesktopLayout._pageHorizontalPadding -
                      PlayerDesktopLayout._minVideoWidth -
                      PlayerDesktopLayout._dividerWidth,
                ),
              );
              final railWidth =
                  (available * ref.watch(playerRailFractionProvider)).clamp(
                    PlayerDesktopLayout._minRailWidth,
                    maxRailForWindow,
                  );

              return ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 48),
                children: [
                  _buildHeaderRow(showRail),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildVideoColumn()),
                      if (showRail) ...[
                        _ResizeDivider(
                          onDrag: (dx) {
                            final targetPx = (railWidth - dx).clamp(
                              PlayerDesktopLayout._minRailWidth,
                              maxRailForWindow,
                            );
                            ref
                                .read(playerRailFractionProvider.notifier)
                                .setFraction(targetPx / available);
                          },
                        ),
                        SizedBox(width: railWidth, child: widget.episodesRail),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(bool showRail) {
    final showEpisodesButton =
        !showRail && widget.onShowEpisodes != null;
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
    return Column(
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
    );
  }
}

/// Draggable divider between the video column and the episode rail. Dragging to
/// the right grows the video and shrinks the rail (and vice versa).
class _ResizeDivider extends StatefulWidget {
  final ValueChanged<double> onDrag;

  const _ResizeDivider({required this.onDrag});

  @override
  State<_ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<_ResizeDivider> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        child: SizedBox(
          width: PlayerDesktopLayout._dividerWidth,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _hovering ? 3 : 2,
              color: _hovering
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "Episodes" pill shown on the page header when the rail is collapsed.
class _EpisodesButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _EpisodesButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    return Tooltip(
      message: l10n.episodes,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
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
    );
  }
}
