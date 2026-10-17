import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/preferences/section_visibility_provider.dart';

class WelcomeStepSections extends ConsumerWidget {
  const WelcomeStepSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    final animeEnabled = ref.watch(animeSectionEnabledProvider);
    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);
    final showsEnabled = ref.watch(showsSectionEnabledProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.layoutGrid,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.welcomeStepSections,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.welcomeSectionsPrompt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Clean open rows (no boxes, no card container)
          Column(
            children: [
              _ModuleToggleItem(
                title: l10n.anime,
                subtitle: 'Búsqueda avanzada, temporadas, géneros, calendario y catálogo completo',
                value: animeEnabled,
                onChanged: (val) {
                  ref
                      .read(animeSectionEnabledProvider.notifier)
                      .setEnabled(val);
                },
              ),
              const SizedBox(height: 22),
              _ModuleToggleItem(
                title: l10n.manga,
                subtitle: 'Lector de manga, capítulos, biblioteca y lecturas sin conexión',
                value: mangaEnabled,
                onChanged: (val) {
                  ref
                      .read(mangaSectionEnabledProvider.notifier)
                      .setEnabled(val);
                },
              ),
              const SizedBox(height: 22),
              _ModuleToggleItem(
                title: l10n.shows,
                subtitle: 'Series de TV, películas y biblioteca multimedia (también incluye anime)',
                value: showsEnabled,
                onChanged: (val) {
                  ref
                      .read(showsSectionEnabledProvider.notifier)
                      .setEnabled(val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleToggleItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ModuleToggleItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        M3ESwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
