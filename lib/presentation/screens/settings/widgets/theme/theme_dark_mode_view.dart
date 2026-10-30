import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import '../settings_dpad_focus.dart';

/// In-page section view for selecting dark mode mode (standard, OLED, system).
class ThemeDarkModeView extends ConsumerWidget {
  final VoidCallback onBack;

  const ThemeDarkModeView({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = ref.watch(translationsProvider);
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation header with back button
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack,
              tooltip: l10n.previous,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.selectDarkMode,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grouped container for dark mode options (sidebar/grouped style)
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 1. Oscuro Estándar
              _buildOptionTile(
                title: l10n.darkModeManual,
                icon: Icons.dark_mode_rounded,
                isSelected: themeSettings.themeMode == AppThemeMode.dark && !themeSettings.isOled,
                colorScheme: colorScheme,
                onTap: () async {
                  await themeNotifier.setOled(false);
                  await themeNotifier.setThemeMode(AppThemeMode.dark);
                },
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),

              // 2. OLED Negro Puro
              _buildOptionTile(
                title: l10n.darkModeOled,
                icon: Icons.brightness_2_rounded,
                isSelected: themeSettings.isOled,
                colorScheme: colorScheme,
                onTap: () async {
                  await themeNotifier.setThemeMode(AppThemeMode.dark);
                  await themeNotifier.setOled(true);
                },
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),

              // 3. Seguir Sistema
              _buildOptionTile(
                title: l10n.darkModeSystem,
                icon: Icons.settings_brightness_rounded,
                isSelected: themeSettings.themeMode == AppThemeMode.system,
                colorScheme: colorScheme,
                onTap: () async {
                  await themeNotifier.setOled(false);
                  await themeNotifier.setThemeMode(AppThemeMode.system);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return SettingsDpadFocus(
      borderRadius: BorderRadius.circular(0),
      onActivate: onTap,
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 22,
                    color: colorScheme.primary,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
