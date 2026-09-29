import 'package:flutter/material.dart';

/// Smooth, cinematic page transition for navigation.
///
/// Features:
/// - Fluid cubic bezier easing (easeOutCubic on enter, easeInCubic on exit).
/// - Combined subtle zoom (0.96 -> 1.0), 4% slide-up, and fade transition.
/// - Eliminates jarring cuts or abrupt platform transitions.
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SmoothPageRoute({
    required this.child,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(curved);
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.0, 0.04),
              end: Offset.zero,
            ).animate(curved);

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: slideAnimation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Transición suave de deslizamiento de derecha a izquierda (Slide Right to Left).
/// Ideal para abrir Ajustes y sus subpáginas con animación estilo Android 16 / Pixel.
class SlideRightToLeftPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SlideRightToLeftPageRoute({
    required this.child,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final slideAnimation = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curved);

            return SlideTransition(
              position: slideAnimation,
              child: child,
            );
          },
        );
}

