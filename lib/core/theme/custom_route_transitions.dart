import 'package:flutter/material.dart';

/// Modern deceleration curve for smooth, physical motion.
/// Responsive initial velocity with soft, natural landing.
const Cubic kWebDecelCurve = Cubic(0.1, 0.9, 0.2, 1.0);

/// Builds an expressive, organic page transition (used for Anime Detail, Manga Detail, etc.):
/// - Incoming route: smooth progressive fade-in (0.0 -> 1.0) and gentle vertical rise (~3-4% height).
///   Completely eliminates jarring 1-frame opacity pops and scale distortions.
/// - Outgoing route on exit: smooth clean fade-out and subtle descend.
/// - Underlying route: rests comfortably with gentle micro-parallax, without jittery scaling or blurring.
Widget buildWebPageTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final enterCurve = CurvedAnimation(
    parent: animation,
    curve: kWebDecelCurve,
    reverseCurve: Curves.easeInCubic,
  );

  // Progressive, smooth fade on enter (0.0 -> 1.0) and exit (1.0 -> 0.0)
  final fadeTransition = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    ),
  );

  // Gentle vertical micro-slide on enter (~3-4% screen height)
  final slideIn = Tween<Offset>(
    begin: const Offset(0.0, 0.035),
    end: Offset.zero,
  ).animate(enterCurve);

  // Subtle parallax shift for the underlying screen (0.0 -> -0.015)
  final secondarySlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0.0, -0.015),
  ).animate(
    CurvedAnimation(
      parent: secondaryAnimation,
      curve: kWebDecelCurve,
      reverseCurve: Curves.easeOutCubic,
    ),
  );

  return SlideTransition(
    position: secondarySlide,
    child: FadeTransition(
      opacity: fadeTransition,
      child: SlideTransition(
        position: slideIn,
        child: child,
      ),
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
          transitionDuration: const Duration(milliseconds: 260),
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

