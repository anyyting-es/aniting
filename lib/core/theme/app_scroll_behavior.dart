import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
export 'smooth_scroll_controller.dart';

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
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // El efecto "stretch" es una affordance nativa de Android/iOS. En
    // escritorio, la rueda del ratón sigue emitiendo overscroll al llegar
    // al tope o al pie de cualquier lista, y el efecto deformaba el
    // contenido (iconos y textos se veían aplastados/estirados). En PC
    // dejamos el scroll limpio, sin deformación.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return StretchingOverscrollIndicator(
          axisDirection: details.direction,
          clipBehavior: Clip.hardEdge,
          child: child,
        );
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return child;
    }
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
