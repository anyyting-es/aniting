import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/i18n_provider.dart';
import 'tv_audio_feedback.dart';

class _LanguageOption {
  final String label;
  final String greeting;
  final String subtitle;
  final AppLanguage? appLang;

  const _LanguageOption(this.label, this.greeting, this.subtitle, [this.appLang]);
}

/// Supported application languages with dynamic localized greeting & subtitle for TV wheel
const List<_LanguageOption> _tvLanguages = [
  _LanguageOption(
    'Español',
    'Bienvenido a Aniting',
    'Para disfrutar de tu Anime, Manga y Series.',
    AppLanguage.es,
  ),
  _LanguageOption(
    'English',
    'Welcome to Aniting',
    'Enjoy your favorite Anime, Manga & Shows.',
    AppLanguage.en,
  ),
];

/// TV Step 1: Clean console language selection wheel.
/// Brand & live translated greeting on the left, vertical scrolling wheel on the right.
class WelcomeTvStepLanguage extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const WelcomeTvStepLanguage({
    super.key,
    required this.onNext,
  });

  @override
  ConsumerState<WelcomeTvStepLanguage> createState() => _WelcomeTvStepLanguageState();
}

class _WelcomeTvStepLanguageState extends ConsumerState<WelcomeTvStepLanguage> {
  int _selectedIndex = 0;
  late final FixedExtentScrollController _scrollController;
  final FocusNode _wheelFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final current = ref.read(appLanguageProvider);
    _selectedIndex = current == AppLanguage.es ? 0 : 1;
    _scrollController = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _wheelFocusNode.dispose();
    super.dispose();
  }

  void _moveUp() {
    if (_selectedIndex > 0) {
      setState(() => _selectedIndex--);
      _scrollController.animateToItem(
        _selectedIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      TvAudioFeedback.playMove();
    }
  }

  void _moveDown() {
    if (_selectedIndex < _tvLanguages.length - 1) {
      setState(() => _selectedIndex++);
      _scrollController.animateToItem(
        _selectedIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      TvAudioFeedback.playMove();
    }
  }

  void _selectCurrent() {
    TvAudioFeedback.playSelect();
    final chosen = _tvLanguages[_selectedIndex];
    if (chosen.appLang != null) {
      ref.read(appLanguageProvider.notifier).setLanguage(chosen.appLang!);
    } else {
      ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.es);
    }
    widget.onNext();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveUp();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _moveDown();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.space) {
        _selectCurrent();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final currentOption = _tvLanguages[_selectedIndex];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ─── LEFT: BRAND & LIVE TRANSLATING WELCOME MESSAGE ──────────
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(left: 48, right: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean single logo image directly
                Image.asset(
                  'assets/icons/logo.png',
                  width: 68,
                  height: 68,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'ANITING',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic live greeting and subtitle transitioning with wheel index
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.08),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey<int>(_selectedIndex),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentOption.greeting,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentOption.subtitle,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── RIGHT: FIXED-FOCUS ROULETTE / WHEEL ─────────────────────
        Expanded(
          flex: 6,
          child: Focus(
            focusNode: _wheelFocusNode,
            autofocus: true,
            onKeyEvent: _handleKey,
            child: Padding(
              padding: const EdgeInsets.only(right: 32),
              child: SizedBox(
                height: 380,
                child: ListWheelScrollView.useDelegate(
                  controller: _scrollController,
                  itemExtent: 56.0,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 2.4,
                  perspective: 0.003,
                  onSelectedItemChanged: (index) {
                    if (_selectedIndex != index) {
                      setState(() => _selectedIndex = index);
                      TvAudioFeedback.playMove();
                    }
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _tvLanguages.length,
                    builder: (context, index) {
                      final item = _tvLanguages[index];
                      final isCurrent = index == _selectedIndex;
                      final distance = (index - _selectedIndex).abs();

                      final double fontSize;
                      final double opacity;
                      final FontWeight weight;

                      if (isCurrent) {
                        fontSize = 30.0;
                        opacity = 1.0;
                        weight = FontWeight.bold;
                      } else if (distance == 1) {
                        fontSize = 22.0;
                        opacity = 0.45;
                        weight = FontWeight.w500;
                      } else if (distance == 2) {
                        fontSize = 18.0;
                        opacity = 0.22;
                        weight = FontWeight.w400;
                      } else {
                        fontSize = 15.0;
                        opacity = 0.08;
                        weight = FontWeight.w300;
                      }

                      return GestureDetector(
                        onTap: () {
                          if (index == _selectedIndex) {
                            _selectCurrent();
                          } else {
                            setState(() => _selectedIndex = index);
                            _scrollController.animateToItem(
                              index,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                            );
                            TvAudioFeedback.playMove();
                          }
                        },
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: Colors.transparent,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: weight,
                              color: Colors.white.withValues(alpha: opacity),
                              letterSpacing: isCurrent ? 0.6 : 0.0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrent) ...[
                                  Container(
                                    width: 14,
                                    height: 3,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                                Text(item.label),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
