import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// YouTube-style "ambient mode" glow.
///
/// Paints a blurred copy of the **live** video. It reuses the exact same GPU
/// texture as the main video — no second decoder and no frame capture.
///
/// Two modes:
/// * `softEdges: false` → a flat backdrop that fills its box (used behind the
///   video in wide mode, so the letterbox bars take the frame's colours).
/// * `softEdges: true` → a halo whose four edges dissolve into the page, used
///   around the video in normal mode.
class AmbientVideoGlow extends StatelessWidget {
  final VideoController controller;

  /// Overall strength of the glow.
  final double opacity;

  /// Darkens the glow so it stays subtle behind the frame.
  final double scrimOpacity;

  /// Dissolves all four edges into the background (halo mode).
  final bool softEdges;

  final double blurSigma;

  const AmbientVideoGlow({
    super.key,
    required this.controller,
    this.opacity = 1.0,
    this.scrimOpacity = 0.42,
    this.softEdges = false,
    // NOTE: Flutter rasterises the filter at device resolution, so the sigma is
    // effectively in screen pixels. Values below ~35 leave the frame
    // recognisable, which defeats the purpose of an ambient backdrop.
    this.blurSigma = 42,
  });

  static const _transparent = Color(0x00FFFFFF);

  /// Whether the reported video rectangle can be painted.
  ///
  /// media_kit starts with a 1x1 placeholder texture (used to initialise the
  /// render context) before the real frame size is known. Blurring and
  /// scaling that placeholder would paint a flat square of a single colour
  /// behind the player, so it is hidden exactly like media_kit's own `Video`
  /// widget does.
  static bool canPaintFrame(Rect? rect) {
    return rect != null && rect.width > 1.0 && rect.height > 1.0;
  }

  /// Width (in logical pixels) of the fade ramp applied on each edge of the
  /// glow box.
  ///
  /// It is tuned so the ramp covers the band of glow that is actually visible
  /// around the frame: the glow stays strong where it meets the player and
  /// reaches zero alpha exactly at the outer edge of its box.
  static const double _edgeFadeExtent = 70;

  /// Builds a linear gradient that fades from transparent at one edge to fully
  /// opaque [_edgeFadeExtent] pixels in, and back to transparent at the other
  /// edge.
  static Shader _edgeFade({required Rect rect, required Axis axis}) {
    final extent = axis == Axis.horizontal ? rect.width : rect.height;
    // The ramp can never be longer than half of the axis, otherwise the two
    // ramps would overlap and the middle would not reach full opacity.
    final ramp = (_edgeFadeExtent / extent).clamp(0.0, 0.5);

    return LinearGradient(
      begin: axis == Axis.horizontal
          ? Alignment.centerLeft
          : Alignment.topCenter,
      end: axis == Axis.horizontal
          ? Alignment.centerRight
          : Alignment.bottomCenter,
      colors: const [
        _transparent,
        Colors.white,
        Colors.white,
        _transparent,
      ],
      stops: [0.0, ramp, 1.0 - ramp, 1.0],
    ).createShader(rect);
  }

  @override
  Widget build(BuildContext context) {
    Widget core = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: _buildTexture(),
    );

    if (softEdges) {
      // Two linear fades multiplied together: a soft rectangle with zero alpha
      // on every edge, so no hard cut can ever show.
      //
      // The ramps are measured in **pixels**, not as a fraction of the box:
      // the box is much larger than the band of glow that is actually visible
      // around the frame, so a fractional ramp would leave the visible band
      // almost transparent. A pixel-based ramp makes the glow strong right
      // where it meets the player and fully transparent at the outer edge.
      core = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => _edgeFade(
          rect: rect,
          axis: Axis.vertical,
        ),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => _edgeFade(
            rect: rect,
            axis: Axis.horizontal,
          ),
          child: core,
        ),
      );
    }

    if (scrimOpacity > 0) {
      core = Stack(
        fit: StackFit.expand,
        children: [
          core,
          ColoredBox(color: Colors.black.withValues(alpha: scrimOpacity)),
        ],
      );
    }

    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: SizedBox.expand(
          child: core,
        ),
      ),
    );
  }

  /// Mirrors what media_kit's `Video` widget does to resolve the texture id,
  /// but without binding a second `VideoController`.
  ///
  /// The frame is laid out at its **real** size (`rect`, reported by the
  /// platform controller) and then scaled to cover the glow box. Flutter's
  /// [Texture] is a `LeafRenderObjectWidget` that always fills the box it is
  /// given, so painting it at the source resolution keeps the frame's aspect
  /// ratio intact instead of stretching it — stretching is what made the glow
  /// read as a hard-edged square with vertical streaks.
  Widget _buildTexture() {
    return ValueListenableBuilder<PlatformVideoController?>(
      valueListenable: controller.notifier,
      builder: (context, platform, _) {
        if (platform == null) return const SizedBox.shrink();
        return ValueListenableBuilder<int?>(
          valueListenable: platform.id,
          builder: (context, textureId, _) {
            if (textureId == null) return const SizedBox.shrink();
            return ValueListenableBuilder<Rect?>(
              valueListenable: platform.rect,
              builder: (context, rect, _) {
                // The 1x1 placeholder texture must never be painted: blurring
                // and scaling it would show a flat square of colour behind
                // the player.
                if (!AmbientVideoGlow.canPaintFrame(rect)) {
                  return const SizedBox.shrink();
                }
                return ClipRect(
                  child: FittedBox(
                    // `cover` fills the glow box with the frame while keeping
                    // its proportions, so the blur bleeds out evenly on all
                    // four sides and never shows the source's letterbox edges.
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: rect!.width,
                      height: rect.height,
                      child: Texture(
                        textureId: textureId,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
