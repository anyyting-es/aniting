import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/theme/app_theme_colors.dart';

class WelcomeStepLanguage extends ConsumerWidget {
  final ValueChanged<AppLanguage>? onLanguageChanged;

  const WelcomeStepLanguage({
    super.key,
    this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colors = context.themeColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.language_rounded, size: 42, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.welcomeTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.welcomeSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.welcomeLanguagePrompt,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            title: 'Español',
            subtitle: 'Idioma principal para menús y contenido',
            icon: Icons.translate_rounded,
            isSelected: currentLang == AppLanguage.es,
            theme: theme,
            colors: colors,
            iconPack: iconPack,
            onTap: () {
              ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.es);
              onLanguageChanged?.call(AppLanguage.es);
            },
          ),
          const SizedBox(height: 10),
          _ChoiceCard(
            title: 'English',
            subtitle: 'Primary language for UI and navigation',
            icon: Icons.language_rounded,
            isSelected: currentLang == AppLanguage.en,
            theme: theme,
            colors: colors,
            iconPack: iconPack,
            onTap: () {
              ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.en);
              onLanguageChanged?.call(AppLanguage.en);
            },
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final ThemeData theme;
  final AppThemeColors colors;
  final AppIconPack iconPack;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.theme,
    required this.colors,
    required this.iconPack,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : colors.surfaceElevated.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.16)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13.5,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(AppIcons.checkCircle(iconPack), color: theme.colorScheme.primary, size: 20)
            else
              Icon(AppIcons.radioUnchecked(iconPack), color: colors.border.withValues(alpha: 0.45), size: 18),
          ],
        ),
      ),
    );
  }
}
