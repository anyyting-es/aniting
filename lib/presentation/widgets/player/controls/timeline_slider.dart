import 'package:flutter/material.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

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

  @override
  void didUpdateWidget(covariant TimelineSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear the optimistic target once the player reports a position
    // close to where we seeked (within 500ms tolerance).
    if (_seekTarget != null && !_isDragging) {
      final diff = (widget.position.inMilliseconds.toDouble() - _seekTarget!).abs();
      if (diff < 500) {
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

    return Stack(
      alignment: Alignment.center,
      children: [
        // Base dark slate/graphite background track (not pitch black)
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 24),
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
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),
          ),

        // Interactive seek slider (clean white bar, zero thumb dot)
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
            trackShape: const RoundedRectSliderTrackShape(),
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
              widget.onSeekingStarted?.call();
            },
            onChanged: (val) {
              setState(() => _dragValue = val);
            },
            onChangeEnd: (val) {
              setState(() {
                _isDragging = false;
                _seekTarget = val; // Hold this position until player catches up
              });
              widget.onSeek(Duration(milliseconds: val.toInt()));
              widget.onSeekingEnded?.call();
            },
          ),
        ),

        // MKV Chapter separator ticks
        if (widget.chapters.isNotEmpty && widget.duration.inMilliseconds > 0)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
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
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
