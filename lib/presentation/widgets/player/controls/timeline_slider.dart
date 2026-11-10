import 'package:flutter/material.dart';
import 'package:aniting/presentation/widgets/player/controls/seek_preview_bubble.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';
import 'package:aniting/presentation/widgets/player/services/seek_preview_service.dart';

/// Modern styled timeline seek bar with buffer progress, chapter ticks, and theme-adaptive coloring.
class TimelineSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final List<PlayerChapter> chapters;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onSeekingStarted;
  final VoidCallback? onSeekingEnded;

  const TimelineSlider({
    super.key,
    required this.position,
    required this.duration,
    required this.buffer,
    this.chapters = const [],
    required this.onSeek,
    this.onSeekingStarted,
    this.onSeekingEnded,
  });

  @override
  State<TimelineSlider> createState() => _TimelineSliderState();
}

class _TimelineSliderState extends State<TimelineSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  // Optimistic seek target: holds the seek position after drag ends
  // to prevent visual bounce-back while the player catches up.
  double? _seekTarget;

  // ─── Seek bar previews (trickplay) ───
  final OverlayPortalController _previewPortal = OverlayPortalController();
  final GlobalKey _trackKey = GlobalKey();
  List<StoryboardCue>? _cues;
  String? _cuesUrl;
  double? _hoverFraction;

  @override
  void initState() {
    super.initState();
    seekThumbnailsUrl.addListener(_onThumbnailsChanged);
    _onThumbnailsChanged();
  }

  @override
  void dispose() {
    seekThumbnailsUrl.removeListener(_onThumbnailsChanged);
    super.dispose();
  }

  /// Loads the storyboard of the active source, if it offers one.
  ///
  /// A storyboard is ~35 KB of text per episode, so it is parsed once and shared
  /// through [seekThumbnailsUrl]; the sprite sheet stays in Flutter's image cache.
  void _onThumbnailsChanged() {
    final url = seekThumbnailsUrl.value;
    if (url == _cuesUrl) return;

    _cuesUrl = url;
    _cues = null;

    if (url == null || url.isEmpty) {
      if (_previewPortal.isShowing) _previewPortal.hide();
      return;
    }

    loadStoryboard(url, headers: seekThumbnailsHeaders.value).then((cues) {
      if (!mounted || _cuesUrl != url) return;
      setState(() => _cues = cues);
    });
  }

  bool get _canPreview =>
      _cues != null && _cues!.isNotEmpty && widget.duration > Duration.zero;

  void _updatePreview(double fraction) {
    if (!_canPreview) return;
    setState(() => _hoverFraction = fraction.clamp(0.0, 1.0));
    if (!_previewPortal.isShowing) _previewPortal.show();
  }

  void _hidePreview() {
    if (_hoverFraction == null) return;
    setState(() => _hoverFraction = null);
    if (_previewPortal.isShowing) _previewPortal.hide();
  }

  Widget _buildPreview(BuildContext context) {
    final fraction = _hoverFraction;
    final cues = _cues;
    if (fraction == null || cues == null || cues.isEmpty) {
      return const SizedBox.shrink();
    }

    final position = Duration(
      milliseconds: (widget.duration.inMilliseconds * fraction).round(),
    );
    final cue = cueAt(cues, position);
    if (cue == null) return const SizedBox.shrink();

    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();

    const bubbleWidth = 168.0;
    final media = MediaQuery.sizeOf(context);
    final origin = box.localToGlobal(Offset.zero);

    final left = (origin.dx + box.size.width * fraction - bubbleWidth / 2).clamp(
      8.0,
      (media.width - bubbleWidth - 8).clamp(8.0, double.infinity),
    );
    // The bubble grows upwards; 130 px covers the header plus the filter chip.
    final top = (origin.dy - 140).clamp(8.0, media.height);

    return Positioned(
      left: left,
      top: top,
      width: bubbleWidth,
      child: SeekPreviewBubble(
        cue: cue,
        position: position,
        width: bubbleWidth,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TimelineSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear the optimistic target once the player reports a position
    // near where we seeked (within 1500ms tolerance or if position progressed past seekTarget).
    if (_seekTarget != null && !_isDragging) {
      final posMs = widget.position.inMilliseconds.toDouble();
      final diff = (posMs - _seekTarget!).abs();
      if (diff < 1500 || posMs > _seekTarget!) {
        _seekTarget = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = widget.duration.inMilliseconds > 0 ? widget.duration.inMilliseconds.toDouble() : 1.0;
    final double currentMs;
    if (_isDragging) {
      currentMs = _dragValue;
    } else if (_seekTarget != null) {
      currentMs = _seekTarget!.clamp(0.0, maxMs);
    } else {
      currentMs = widget.position.inMilliseconds.clamp(0, widget.duration.inMilliseconds).toDouble();
    }

    final bufferFraction = widget.duration.inMilliseconds > 0
        ? (widget.buffer.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        return MouseRegion(
          onHover: (event) {
            if (trackWidth <= 0) return;
            _updatePreview(event.localPosition.dx / trackWidth);
          },
          onExit: (_) => _hidePreview(),
          child: OverlayPortal(
            controller: _previewPortal,
            overlayChildBuilder: _buildPreview,
            child: KeyedSubtree(
              key: _trackKey,
              child: Stack(
                alignment: Alignment.center,
                children: [
            // Base dark slate/graphite background track (not pitch black)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3B43).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),

            // Buffer track background indicator
            if (bufferFraction > 0.0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: bufferFraction,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),

            // Interactive seek slider (clean white bar, zero thumb dot, edge-to-edge track)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.transparent,
                overlayColor: Colors.white.withValues(alpha: 0.12),
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 0.0,
                  disabledThumbRadius: 0.0,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                trackShape: const _FullWidthRoundedRectSliderTrackShape(),
              ),
              child: Slider(
                min: 0.0,
                max: maxMs,
                value: currentMs.clamp(0.0, maxMs),
                onChangeStart: (val) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = val;
                    _seekTarget = null;
                  });
                  _updatePreview(maxMs > 0 ? val / maxMs : 0);
                  widget.onSeekingStarted?.call();
                },
                onChanged: (val) {
                  setState(() => _dragValue = val);
                  _updatePreview(maxMs > 0 ? val / maxMs : 0);
                },
                onChangeEnd: (val) {
                  setState(() {
                    _isDragging = false;
                    _seekTarget = val; // Hold this position until player catches up
                  });
                  _hidePreview();
                  widget.onSeek(Duration(milliseconds: val.toInt()));
                  widget.onSeekingEnded?.call();
                },
              ),
            ),

            // MKV Chapter separator ticks
            if (widget.chapters.isNotEmpty && widget.duration.inMilliseconds > 0)
              Positioned.fill(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    for (final chapter in widget.chapters)
                      if (chapter.start > Duration.zero &&
                          chapter.start < widget.duration)
                        Positioned(
                          left: (chapter.start.inMilliseconds /
                                  widget.duration.inMilliseconds) *
                              constraints.maxWidth,
                          child: Container(
                            width: 2.5,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(1),
                            ),
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
      },
    );
  }
}

/// Custom slider track shape that renders edge-to-edge without the default 24px thumb padding,
/// ensuring the painted track and seek gestures align 1:1 with the container background.
class _FullWidthRoundedRectSliderTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthRoundedRectSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 5.0;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(offset.dx, trackTop, parentBox.size.width, trackHeight);
  }
}
