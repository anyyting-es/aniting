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
    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: playerViewport,
          ),
          Expanded(child: infoPanel),
        ],
      ),
    );
  }
}
