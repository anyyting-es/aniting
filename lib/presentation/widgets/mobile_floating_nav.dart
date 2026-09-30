import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';
import 'package:seanime_app/presentation/widgets/floating_nav/floating_dock_pill.dart';
import 'package:seanime_app/presentation/widgets/floating_nav/floating_resume_companion.dart';
import 'package:seanime_app/presentation/widgets/floating_resume_bar.dart';

/// A floating mobile navigation bar coordinating a solid Material Design 3 dock
/// with an animated zero-overlap resume companion.
///
/// Animation & Trajectory:
/// - When expanding (scrolling up / at top):
///   1. Rises vertically in its dedicated right column until reaching the top line.
///   2. Expands horizontally across the full width, while the dock widens and the selected
///      item deploys its label to the right.
/// - When collapsing (scrolling down):
///   1. First shrinks horizontally into a 64x64 square on the right side while staying above the dock.
///      Simultaneously, the dock contracts and switches to icon-only mode.
///   2. Then glides vertically downwards into the row beside the dock without ever passing on top of it.
class MobileFloatingNav extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DesktopSidebarItem> items;
  final bool isResumeExpanded;

  const MobileFloatingNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    this.isResumeExpanded = true,
  });

  @override
  ConsumerState<MobileFloatingNav> createState() => _MobileFloatingNavState();
}

class _MobileFloatingNavState extends ConsumerState<MobileFloatingNav>
    with SingleTickerProviderStateMixin {
  static const double _kDockHeight = 68.0;
  static const double _kExpandedBarHeight = 68.0;
  static const double _kVerticalGap = 8.0;
  static const double _kCompanionWidth = 68.0;
  static const double _kCompanionGap = 10.0;
  static const double _kBottomMargin = 8.0;

  late final AnimationController _animController;
  late final Animation<double> _animCurve;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.isResumeExpanded ? 1.0 : 0.0,
    );
    _animCurve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant MobileFloatingNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isResumeExpanded != oldWidget.isResumeExpanded) {
      if (widget.isResumeExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final resumeEnabled = ref.watch(resumeBarEnabledProvider);
    final session = ref.watch(lastSessionProvider);

    final hasResume = resumeEnabled && session != null;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          const marginH = 26.0;
          final availableWidth = totalWidth - (marginH * 2);

          // If no active session or resume disabled, render simple standalone dock
          if (!hasResume) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: _kBottomMargin,
                ),
                child: FloatingDockPill(
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: widget.onDestinationSelected,
                  items: widget.items,
                  labelProgress: 1.0,
                  height: _kDockHeight,
                  borderRadius: BorderRadius.circular(34.0),
                ),
              ),
            );
          }

          return AnimatedBuilder(
            animation: _animCurve,
            builder: (context, _) {
              final value = _animCurve.value; // 1.0 = expanded, 0.0 = collapsed

              // 2-Phase Staged Non-Overlapping Trajectory:
              // Phase 1 (value: 0.5 to 1.0): Horizontal width expansion/contraction
              final tWidth = ((value - 0.5) / 0.5).clamp(0.0, 1.0);
              // Phase 2 (value: 0.0 to 0.5): Vertical rise/drop along right slot
              final tHeight = (value / 0.5).clamp(0.0, 1.0);

              // Total container height expands smoothly as companion rises
              final totalHeight = lerpDouble(
                _kDockHeight,
                _kDockHeight + _kVerticalGap + _kExpandedBarHeight,
                tHeight,
              )!;

              // Dock Geometry: strictly contracted to its intrinsic items width
              final dockWidth = FloatingDockPill.calculateWidth(
                items: widget.items,
                selectedIndex: widget.selectedIndex,
                labelProgress: tWidth,
              );

              // Resume Companion Geometry
              final resumeWidth = lerpDouble(
                _kCompanionWidth,
                availableWidth,
                tWidth,
              )!;

              // Vertical offset for Resume Companion:
              // - At value 0.0: bottom is 0.0 (same row as the dock, side-by-side)
              // - At value >= 0.5: bottom is parked at _kDockHeight + _kVerticalGap (above dock)
              final resumeBottom = lerpDouble(
                0.0,
                _kDockHeight + _kVerticalGap,
                tHeight,
              )!;

              // Horizontal Geometry:
              // When collapsed (tHeight = 0, tWidth = 0):
              //   Dock & Companion are centered together side-by-side with _kCompanionGap between them
              final combinedWidth = dockWidth + _kCompanionGap + _kCompanionWidth;
              final collapsedStartX = (totalWidth - combinedWidth) / 2;
              final dockLeftCollapsed = collapsedStartX;
              final companionLeftCollapsed = collapsedStartX + dockWidth + _kCompanionGap;

              // When expanded above (tHeight = 1):
              //   - Dock is centered alone: (totalWidth - dockWidth) / 2
              //   - Companion parked above: right edge aligned to marginH, or full availableWidth
              final dockLeftExpanded = (totalWidth - dockWidth) / 2;
              final companionLeftParked = totalWidth - marginH - _kCompanionWidth;
              final companionLeftAtTop = lerpDouble(companionLeftParked, marginH, tWidth)!;

              final dockLeft = lerpDouble(dockLeftCollapsed, dockLeftExpanded, tHeight)!;
              final companionLeft = lerpDouble(companionLeftCollapsed, companionLeftAtTop, tHeight)!;

              return SizedBox(
                width: totalWidth,
                height: totalHeight + _kBottomMargin,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Mobile Navigation Dock
                    Positioned(
                      left: dockLeft,
                      bottom: _kBottomMargin,
                      width: dockWidth,
                      height: _kDockHeight,
                      child: FloatingDockPill(
                        selectedIndex: widget.selectedIndex,
                        onDestinationSelected: widget.onDestinationSelected,
                        items: widget.items,
                        labelProgress: tWidth,
                        width: dockWidth,
                        height: _kDockHeight,
                        borderRadius: BorderRadius.circular(34.0),
                      ),
                    ),

                    // 2. Resume Card / Companion (never passes over dock)
                    Positioned(
                      left: companionLeft,
                      bottom: _kBottomMargin + resumeBottom,
                      width: resumeWidth,
                      height: _kDockHeight,
                      child: FloatingResumeCompanion(
                        session: session,
                        tWidth: tWidth,
                        width: resumeWidth,
                        height: _kDockHeight,
                        borderRadius: BorderRadius.circular(34.0),
                        l10n: l10n,
                        onTap: () => FloatingResumeBar.resumePlayback(
                          context,
                          ref,
                          session,
                        ),
                        onDismiss: () => ref
                            .read(lastSessionProvider.notifier)
                            .clearSession(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
