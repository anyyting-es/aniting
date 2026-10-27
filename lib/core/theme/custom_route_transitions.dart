import 'package:flutter/material.dart';

/// Modern Material 3 & Animeko Motion Schemes
/// Specifications from M3 motion and Animeko NavigationMotionScheme:
/// - Enter Duration: 400ms (Emphasized Decelerate)
/// - Exit Duration: 200ms (Emphasized Accelerate)
/// - Enter Easing: Cubic(0.05, 0.7, 0.1, 1.0) - Emphasized Decelerate
/// - Exit Easing: Cubic(0.3, 0.0, 0.8, 0.15) - Emphasized Accelerate
const Cubic kM3EmphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
const Cubic kM3EmphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
const Cubic kM3Emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
const Duration kM3EnterDuration = Duration(milliseconds: 400);
const Duration kM3ExitDuration = Duration(milliseconds: 200);

/// Modern deceleration curve for smooth, physical motion.
/// Responsive initial velocity with soft, natural landing.
const Cubic kWebDecelCurve = Cubic(0.16, 1.0, 0.3, 1.0);

/// Builds an expressive, staggered Animeko/M3 desktop page transition:
/// - Staggered cross-dissolve: outgoing page fades out quickly (200ms with EmphasizedAccelerate)
///   while incoming page gracefully decelerates into view (400ms with EmphasizedDecelerate).
/// - Clean, subtle breath scale (0.985 -> 1.0) to give physical weight without jarring translation.
/// - Uncluttered background: avoids heavy re-rasterization or multi-axis transforms.
Widget buildWebPageTransition({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  // Staggered enter curve (Animeko NavigationMotionScheme: delayMillis = exitDuration, duration = enterDuration)
  // Across the 400ms timeline, the first ~150-200ms is the outgoing fade, followed by confident deceleration
  final curvedEnter = CurvedAnimation(
    parent: animation,
    curve: kM3EmphasizedDecelerate,
    reverseCurve: kM3EmphasizedAccelerate,
  );

  // Progressive, smooth fade on enter (0.0 -> 1.0) and exit (1.0 -> 0.0) with zero clipping or pops
  final fadeTransition = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(curvedEnter);

  // Secondary animation (when a new route is pushed on top of this one)
  final curvedSecondary = CurvedAnimation(
    parent: secondaryAnimation,
    curve: kM3EmphasizedAccelerate,
    reverseCurve: kM3EmphasizedDecelerate,
  );

  final secondaryFade = Tween<double>(
    begin: 1.0,
    end: 0.90,
  ).animate(curvedSecondary);

  return FadeTransition(
    opacity: secondaryFade,
    child: FadeTransition(
      opacity: fadeTransition,
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

/// Modern, snappy Animeko/M3 staggered route (400ms enter / 200ms exit).
class WebPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  WebPageRoute({
    required this.child,
    super.settings,
    super.opaque = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: kM3EnterDuration,
          reverseTransitionDuration: kM3ExitDuration,
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
    super.opaque = true,
  });
}

/// Silky-smooth horizontal slide route (Right-to-Left).
/// Used in Settings and child subpages, Lists, Downloads, Marketplace, etc.
class SlideRightToLeftPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SlideRightToLeftPageRoute({
    required this.child,
    super.settings,
    super.opaque = true,
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

