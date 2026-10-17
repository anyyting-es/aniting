import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/i18n_provider.dart';

class WelcomeStepLanguage extends ConsumerWidget {
  final ValueChanged<AppLanguage>? onLanguageChanged;

  const WelcomeStepLanguage({
    super.key,
    this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

          // ─── Bienvenido a Aniting (Limpio con sombra de profundidad) ───
          Text(
            l10n.welcomeTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 18,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ─── Language Dropdown (Flotando con Liquid Glass sutil) ───
          GlassMenuAnchor(
            width: 170,
            items: [
              GlassMenuItem(
                label: 'Español',
                icon: currentLang == AppLanguage.es
                    ? Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary)
                    : null,
                onPressed: () {
                  ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.es);
                  onLanguageChanged?.call(AppLanguage.es);
                },
              ),
              GlassMenuItem(
                label: 'English',
                icon: currentLang == AppLanguage.en
                    ? Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary)
                    : null,
                onPressed: () {
                  ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.en);
                  onLanguageChanged?.call(AppLanguage.en);
                },
              ),
            ],
            builder: (context, controller) {
              return GlassButton(
                onPressed: controller.open,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        langLabel,
                        key: ValueKey<String>(langLabel),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.chevronDown, size: 15),
                  ],
                ),
              );
            },
          ),

          const Spacer(flex: 4),
        ],
      ),
    );
  }
}
