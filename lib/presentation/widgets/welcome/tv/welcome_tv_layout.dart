import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tv_audio_feedback.dart';
import 'welcome_tv_step_language.dart';
import 'welcome_tv_step_server.dart';

/// TV Layout Coordinator: clean, distraction-free 10-foot console onboarding.
/// Controlled via DPAD and controller back key.
class WelcomeTvLayout extends ConsumerStatefulWidget {
  final VoidCallback onFinish;
  final VoidCallback? onSwitchToStandard;

  const WelcomeTvLayout({
    super.key,
    required this.onFinish,
    this.onSwitchToStandard,
  });

  @override
  ConsumerState<WelcomeTvLayout> createState() => _WelcomeTvLayoutState();
}

class _WelcomeTvLayoutState extends ConsumerState<WelcomeTvLayout> {
  int _currentStep = 0; // 0 = Language, 1 = Server
  final FocusScopeNode _scopeNode = FocusScopeNode();

  @override
  void dispose() {
    _scopeNode.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (_currentStep != step) {
      setState(() => _currentStep = step);
    }
  }

  KeyEventResult _handleGlobalKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.gameButtonB) {
        if (_currentStep > 0) {
          TvAudioFeedback.playBack();
          _goToStep(0);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scopeNode,
      onKeyEvent: _handleGlobalKey,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final isStep1 = child.key == const ValueKey('step_language');
              final offsetBegin = isStep1
                  ? const Offset(-0.04, 0.0)
                  : const Offset(0.04, 0.0);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: offsetBegin,
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _currentStep == 0
                ? WelcomeTvStepLanguage(
                    key: const ValueKey('step_language'),
                    onNext: () => _goToStep(1),
                  )
                : WelcomeTvStepServer(
                    key: const ValueKey('step_server'),
                    onFinished: widget.onFinish,
                  ),
          ),
        ),
      ),
    );
  }
}
