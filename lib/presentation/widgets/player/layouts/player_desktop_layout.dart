import 'package:flutter/material.dart';

/// Layout for desktop windowed video playback:
/// renders the main player viewport on the left and a smoothly
/// collapsible side info panel (380dp) on the right.
class PlayerDesktopLayout extends StatelessWidget {
  final Widget playerViewport;
  final Widget sidePanel;
  final bool isSidePanelCollapsed;

  const PlayerDesktopLayout({
    super.key,
    required this.playerViewport,
    required this.sidePanel,
    required this.isSidePanelCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: playerViewport),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          width: isSidePanelCollapsed ? 0 : 380,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 380,
              maxWidth: 380,
              child: SizedBox(
                width: 380,
                child: sidePanel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
