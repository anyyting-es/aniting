import 'package:flutter/material.dart';

/// Modern web deceleration curve (Apple / Linear / Framer Motion style).
/// Starts with instant velocity for immediate touch feedback, then softly lands.
const Cubic kWebDecelCurve = Cubic(0.16, 1.0, 0.3, 1.0);

/// Builds a modern web-style page transition with clean opacity fade
/// and a subtle vertical micro-lift (Y: ~18-20px), completely avoiding
/// scale distortion, raster blurring, or heavy platform zooms.
Widget buildWebPageTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  // Primary incoming animation with cubic easing
  final enterCurve = CurvedAnimation(
    parent: animation,
    curve: kWebDecelCurve,
    reverseCurve: Curves.easeInCubic,
  );

  // Subtle vertical micro-lift (~18-20px)
  final slideIn = Tween<Offset>(
    begin: const Offset(0.0, 0.025),
    end: Offset.zero,
  ).animate(enterCurve);

  // Smooth opacity fade with quick 85% plateau for instant legibility
  final fadeIn = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    ),
  );

  // Outgoing background animation when a new route pushes on top
  final exitCurve = CurvedAnimation(
    parent: secondaryAnimation,
    curve: kWebDecelCurve,
    reverseCurve: Curves.easeInCubic,
  );

  final fadeOut = Tween<double>(
    begin: 1.0,
    end: 0.90,
  ).animate(exitCurve);

  final slideOut = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0.0, -0.012),
  ).animate(exitCurve);

  return SlideTransition(
    position: slideOut,
    child: FadeTransition(
      opacity: fadeOut,
      child: SlideTransition(
        position: slideIn,
        child: FadeTransition(
          opacity: fadeIn,
          child: child,
        ),
      ),
    ),
  );
}

/// Global PageTransitionsBuilder for ThemeData.pageTransitionsTheme.
/// Unifies all standard routes (MaterialPageRoute, modal routes, etc.)
/// across all platforms with the modern web-style transition.
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

/// Modern, snappy web-style page route (240ms enter / 200ms exit).
class WebPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  WebPageRoute({
    required this.child,
    super.settings,
    super.opaque,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 240),
          reverseTransitionDuration: const Duration(milliseconds: 200),
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

/// Backwards-compatible subclass of WebPageRoute.
/// Unifies previously horizontal slide routes (Settings, Lists, Calendar, etc.)
/// under the same cohesive, high-quality web-style transition.
class SlideRightToLeftPageRoute<T> extends WebPageRoute<T> {
  SlideRightToLeftPageRoute({
    required super.child,
    super.settings,
    super.opaque,
  });
}
