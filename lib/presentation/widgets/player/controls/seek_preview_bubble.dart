import 'package:aniting/presentation/widgets/player/services/seek_preview_service.dart';
import 'package:flutter/material.dart';

/// One frame of the seek bar preview, cropped out of a storyboard sprite sheet.
///
/// The sprite sheet is only decoded once per image (Flutter's image cache keeps
/// it), so scrubbing does not re-download anything.
class SeekPreviewBubble extends StatelessWidget {
  final StoryboardCue cue;
  final Duration position;

  /// Displayed width of the preview.
  final double width;

  const SeekPreviewBubble({
    super.key,
    required this.cue,
    required this.position,
    this.width = 168,
  });

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final tile = cue.tile;
    final hasTile = tile.width > 0 && tile.height > 0;

    final displayWidth = width;
    final displayHeight = hasTile
        ? displayWidth * (tile.height / tile.width)
        : displayWidth * 9 / 16;

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: displayWidth,
              height: displayHeight,
              color: Colors.black,
              child: hasTile
                  ? _SpriteTile(cue: cue, displayWidth: displayWidth)
                  : Image.network(
                      cue.imageUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              _format(position),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Crops `tile` out of the sprite sheet by scaling the whole sheet and offsetting
/// it inside a clip. The sheet size is derived from the storyboard itself, so no
/// extra request is needed to learn the image dimensions.
class _SpriteTile extends StatelessWidget {
  final StoryboardCue cue;
  final double displayWidth;

  const _SpriteTile({required this.cue, required this.displayWidth});

  @override
  Widget build(BuildContext context) {
    final tile = cue.tile;
    final sheet = cue.sheet;
    final scale = displayWidth / tile.width;

    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: -tile.left * scale,
            top: -tile.top * scale,
            child: SizedBox(
              width: sheet.width * scale,
              height: sheet.height * scale,
              child: Image.network(
                cue.imageUrl,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
