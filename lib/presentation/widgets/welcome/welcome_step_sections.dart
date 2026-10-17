import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/preferences/section_visibility_provider.dart';

class WelcomeStepSections extends ConsumerWidget {
  const WelcomeStepSections({super.key});

  void _handleToggle({
    required bool val,
    required int enabledCount,
    required VoidCallback update,
  }) {
    if (!val && enabledCount <= 1) {
      return;
    }
    update();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    final animeEnabled = ref.watch(animeSectionEnabledProvider);
    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);
    final showsEnabled = ref.watch(showsSectionEnabledProvider);

    final int enabledCount = (animeEnabled ? 1 : 0) +
        (mangaEnabled ? 1 : 0) +
        (showsEnabled ? 1 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Icon + Title only (clean, matching Theme step) ───
          Row(
            children: [
              GlassCard(
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  LucideIcons.layoutGrid,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                l10n.welcomeStepSections,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Content Modules in single Glass container ───
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _ModuleToggleItem(
                  icon: LucideIcons.film,
                  title: l10n.anime,
                  subtitle: l10n.welcomeAnimeSubtitle,
                  value: animeEnabled,
                  onChanged: (val) => _handleToggle(
                    val: val,
                    enabledCount: enabledCount,
                    update: () => ref
                        .read(animeSectionEnabledProvider.notifier)
                        .setEnabled(val),
                  ),
                ),
                Divider(
                  height: 20,
                  thickness: 0.8,
                  color: theme.dividerColor.withValues(alpha: 0.08),
                ),
                _ModuleToggleItem(
                  icon: LucideIcons.bookOpen,
                  title: l10n.manga,
                  subtitle: l10n.welcomeMangaSubtitle,
                  value: mangaEnabled,
                  onChanged: (val) => _handleToggle(
                    val: val,
                    enabledCount: enabledCount,
                    update: () => ref
                        .read(mangaSectionEnabledProvider.notifier)
                        .setEnabled(val),
                  ),
                ),
                Divider(
                  height: 20,
                  thickness: 0.8,
                  color: theme.dividerColor.withValues(alpha: 0.08),
                ),
                _ModuleToggleItem(
                  icon: LucideIcons.tv,
                  title: l10n.shows,
                  subtitle: l10n.welcomeShowsSubtitle,
                  value: showsEnabled,
                  onChanged: (val) => _handleToggle(
                    val: val,
                    enabledCount: enabledCount,
                    update: () => ref
                        .read(showsSectionEnabledProvider.notifier)
                        .setEnabled(val),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleToggleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ModuleToggleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: value
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: value
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
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
            const SizedBox(width: 14),
            M3ESwitch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
