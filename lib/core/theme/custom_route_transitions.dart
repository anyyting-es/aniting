import 'package:flutter/material.dart';

/// Modern deceleration curve for smooth, physical motion.
/// Responsive initial velocity with soft, natural landing.
const Cubic kWebDecelCurve = Cubic(0.16, 1.0, 0.3, 1.0);

/// Builds an expressive, satisfying "Micro-Breath Fade" page transition
/// (used across routes: Anime Detail, Manga Detail, Search, etc.):
/// - Zero translation (no jarring sliding or screen shaking in X/Y).
/// - Incoming route: organic fade-in (0.0 -> 1.0) with an imperceptible, satisfying
///   micro-breath tactile heartbeat scale (0.985 -> 1.0).
/// - Outgoing route on exit: silky-smooth, instant dissolve without any lag,
///   stutter, or abrupt cuts at the end.
/// - Underlying route: completely unencumbered by transforms or re-rasterization,
///   guaranteeing a rock-solid 120 FPS pop animation.
Widget buildWebPageTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutCubic,
  );

  // Progressive, smooth fade on enter (0.0 -> 1.0) and exit (1.0 -> 0.0) with zero clipping or pops
  final fadeTransition = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(curvedAnimation);

  // Micro-breath tactile heartbeat scale (0.985 -> 1.0) on enter,
  // softly dissolving back on exit with zero translation
  final scaleTransition = Tween<double>(
    begin: 0.985,
    end: 1.0,
  ).animate(curvedAnimation);

  return FadeTransition(
    opacity: fadeTransition,
    child: ScaleTransition(
      scale: scaleTransition,
      child: child,
    ),
  );
}

/// Builds a native-feeling horizontal slide transition (Right-to-Left):
/// - Incoming route slides smoothly from right (1.0 -> 0.0) with subtle elevation shadow.
/// - Underlying route shifts gently to the left (0.0 -> -0.25) with parallax depth.
/// - On pop/back, incoming route smoothly slides away to the right (0.0 -> 1.0)
///   and underlying route restores without sudden jumps or scaling artifacts.
Widget buildHorizontalSlideTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final enterCurve = CurvedAnimation(
    parent: animation,
    curve: kWebDecelCurve,
    reverseCurve: Curves.easeInCubic,
  );

  final secondaryCurve = CurvedAnimation(
    parent: secondaryAnimation,
    curve: kWebDecelCurve,
    reverseCurve: Curves.easeOutCubic,
  );

  // Incoming page slides from right (1.0 -> 0.0)
  final slideIn = Tween<Offset>(
    begin: const Offset(1.0, 0.0),
    end: Offset.zero,
  ).animate(enterCurve);

  // Underlying page shifts slightly to the left (-0.25)
  final slideUnder = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.25, 0.0),
  ).animate(secondaryCurve);

  return SlideTransition(
    position: slideUnder,
    child: SlideTransition(
      position: slideIn,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

/// Global PageTransitionsBuilder for ThemeData.pageTransitionsTheme.
/// Unifies all standard routes (MaterialPageRoute, modal routes, etc.)
/// across all platforms with the modern smooth motion transition.
class WebPageTransitionsBuilder extends PageTransitionsBuilder {
  const WebPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildWebPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Modern, snappy fade & vertical slide route (260ms enter / 220ms return motion).
class WebPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  WebPageRoute({
    required this.child,
    super.settings,
    super.opaque,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return buildWebPageTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        );
}

/// Backwards-compatible subclass of WebPageRoute.
/// Used when navigating to AnimeDetailScreen, MangaDetailScreen, etc.
class SmoothPageRoute<T> extends WebPageRoute<T> {
  SmoothPageRoute({
    required super.child,
    super.settings,
    super.opaque,
  });
}

/// Silky-smooth horizontal slide route (Right-to-Left).
/// Used in Settings and child subpages, Lists, Downloads, Marketplace, etc.
class SlideRightToLeftPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SlideRightToLeftPageRoute({
    required this.child,
    super.settings,
    super.opaque,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return buildHorizontalSlideTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        );
}

