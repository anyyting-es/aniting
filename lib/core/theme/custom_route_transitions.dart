import 'package:flutter/material.dart';

/// Modern deceleration curve for smooth, physical motion.
/// Responsive initial velocity with soft, natural landing.
const Cubic kWebDecelCurve = Cubic(0.16, 1.0, 0.3, 1.0);

/// Builds an expressive, organic page transition:
/// - Incoming route: subtle in-place breathing expansion (0.98 -> 1.0) and ~10px micro-lift with 100% solid opacity.
/// - Outgoing route on exit: smooth clean fade out (without awkward shrinking).
/// - Return page (the underlying screen being returned to): smooth organic step-forward
///   expansion (0.96 -> 1.0) and vertical lift (~16px), giving life and motion to the content!
Widget buildWebPageTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final enterCurve = CurvedAnimation(
    parent: animation,
    curve: kWebDecelCurve,
  );

  // Subtle breathing expansion on enter (0.98 -> 1.0)
  final scaleIn = Tween<double>(
    begin: 0.98,
    end: 1.0,
  ).animate(enterCurve);

  // Subtle vertical micro-lift (~10-12px) on enter
  final slideIn = Tween<Offset>(
    begin: const Offset(0.0, 0.015),
    end: Offset.zero,
  ).animate(enterCurve);

  // Clean fade out only when exiting/popping (100% solid on enter via quick interval)
  final exitFade = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.001),
      reverseCurve: Curves.easeIn,
    ),
  );

  // Secondary curve driving the underlying screen
  final secondaryCurve = CurvedAnimation(
    parent: secondaryAnimation,
    curve: kWebDecelCurve,
    reverseCurve: Curves.easeOutCubic,
  );

  // When another route is pushed, the underlying page recedes gently to 0.96.
  // When returning, the page expands back (0.96 -> 1.0) making all cards/content spring forward!
  final returnScale = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(secondaryCurve);

  // When returning, the content rises ~16px back into position
  final returnSlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0.0, 0.02),
  ).animate(secondaryCurve);

  return SlideTransition(
    position: returnSlide,
    child: ScaleTransition(
      scale: returnScale,
      child: FadeTransition(
        opacity: exitFade,
        child: SlideTransition(
          position: slideIn,
          child: ScaleTransition(
            scale: scaleIn,
            child: child,
          ),
        ),
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

/// Modern, snappy breathing route (220ms enter / 200ms return motion).
class WebPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  WebPageRoute({
    required this.child,
    super.settings,
    super.opaque,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 220),
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
/// under the same cohesive, high-quality transition.
class SlideRightToLeftPageRoute<T> extends WebPageRoute<T> {
  SlideRightToLeftPageRoute({
    required super.child,
    super.settings,
    super.opaque,
  });
}
