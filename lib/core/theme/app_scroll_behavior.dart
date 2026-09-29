import 'dart:ui';
import 'package:flutter/material.dart';

/// Global scroll behavior that enables drag-to-scroll with mouse, touch,
/// stylus, and trackpad across all platforms.
///
/// This provides a smooth touch-like experience even when using a mouse on desktop.
class AppScrollBehavior extends MaterialScrollBehavior {
  final bool showScrollbar;
  const AppScrollBehavior({this.showScrollbar = true});

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    // Avoid assertion failures or hide scrollbar if disabled
    if (!showScrollbar || details.controller == null) {
      return child;
    }
    return super.buildScrollbar(context, child, details);
  }
}
