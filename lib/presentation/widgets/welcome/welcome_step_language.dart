import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';

import '../../../core/i18n/i18n_provider.dart';

class WelcomeStepLanguage extends ConsumerStatefulWidget {
  final ValueChanged<AppLanguage>? onLanguageChanged;

  const WelcomeStepLanguage({
    super.key,
    this.onLanguageChanged,
  });

  @override
  ConsumerState<WelcomeStepLanguage> createState() => _WelcomeStepLanguageState();
}

class _WelcomeStepLanguageState extends ConsumerState<WelcomeStepLanguage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _contentFadeAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOutCubic,
    );

    _contentFadeAnimation = CurvedAnimation(
      parent: _expandController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _open() {
    if (_isOpen) return;
    setState(() => _isOpen = true);
    _expandController.forward();
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _expandController.reverse();
  }

  void _selectLanguage(AppLanguage lang) {
    ref.read(appLanguageProvider.notifier).setLanguage(lang);
    widget.onLanguageChanged?.call(lang);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    final langLabel = currentLang == AppLanguage.es ? 'Español' : 'English';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 3),

          // ─── App Logo (Puro flotando sin cajón) ───
          Image.asset(
            'assets/icons/logo.png',
            width: 88,
            height: 88,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),

          // ─── Bienvenido a Aniting (Limpio y estilizado) ───
          Text(
            l10n.welcomeTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ─── Language Selector (Centrado, elástico y con física fluida) ───
          SizedBox(
            height: 100,
            child: Align(
              alignment: Alignment.topCenter,
              child: TapRegion(
                onTapOutside: (_) {
                  if (_isOpen && mounted) {
                    _close();
                  }
                },
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, _) {
                    final t = _expandAnimation.value;
                    final height = lerpDouble(40.0, 86.0, t)!;
                    final width = lerpDouble(140.0, 148.0, t)!;

                    return GlassCard(
                      borderRadius: BorderRadius.circular(22),
                      padding: const EdgeInsets.all(2),
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Estado colapsado: píldora individual interactiva
                              if (t < 0.85)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: (1.0 - t * 2.2).clamp(0.0, 1.0),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _open,
                                        child: Center(
                                          child: Text(
                                            langLabel,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Estado expandido: opciones fluidas con transición de escala/fade
                              if (t > 0.08)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: _contentFadeAnimation.value,
                                    child: Transform.translate(
                                      offset: Offset(0, 4 * (1.0 - t.clamp(0.0, 1.0))),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                borderRadius: const BorderRadius.vertical(
                                                  top: Radius.circular(19),
                                                ),
                                                onTap: () => _selectLanguage(AppLanguage.es),
                                                child: const Center(
                                                  child: Text(
                                                    'Español',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              height: 1,
                                              width: 104,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                            ),
                                            Expanded(
                                              child: InkWell(
                                                borderRadius: const BorderRadius.vertical(
                                                  bottom: Radius.circular(19),
                                                ),
                                                onTap: () => _selectLanguage(AppLanguage.en),
                                                child: const Center(
                                                  child: Text(
                                                    'English',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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

          const Spacer(flex: 4),
        ],
      ),
    );
  }
}
