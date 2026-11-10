import 'package:flutter/material.dart';

/// Layout for mobile portrait video playback (YouTube-style watch page):
/// renders the 16:9 player viewport at the top and an expandable info &
/// episode navigation panel filling the remaining space below.
class PlayerMobileLayout extends StatelessWidget {
  final Widget playerViewport;
  final Widget infoPanel;

  const PlayerMobileLayout({
    super.key,
    required this.playerViewport,
    required this.infoPanel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        // The status bar strip stays opaque: the player route itself is
        // transparent on Android so the native ExoPlayer surface can show
        // through the 16:9 viewport below.
        SizedBox(
          height: topInset,
          width: double.infinity,
          child: ColoredBox(color: theme.scaffoldBackgroundColor),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: playerViewport),
                Expanded(child: infoPanel),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
