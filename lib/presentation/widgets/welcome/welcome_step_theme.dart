import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/theme_provider.dart';

class WelcomeStepTheme extends ConsumerStatefulWidget {
  const WelcomeStepTheme({super.key});

  @override
  ConsumerState<WelcomeStepTheme> createState() => _WelcomeStepThemeState();
}

class _WelcomeStepThemeState extends ConsumerState<WelcomeStepTheme> {
  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final iconPack = ref.watch(iconPackProvider);
    final iconPackNotifier = ref.read(iconPackProvider.notifier);
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colors = context.themeColors;

    final bool isOledSelected = themeSettings.isOled;
    final bool isDarkSelected = !themeSettings.isOled && themeSettings.themeMode == AppThemeMode.dark;
    final bool isLightSelected = !themeSettings.isOled && themeSettings.themeMode == AppThemeMode.light;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.theme(iconPack), size: 24, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.welcomeStepTheme,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. THEME SELECTION (Dark, Light, OLED)
          Text(
            l10n.themeMode,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildVisualThemeCard(
                label: l10n.themeDark,
                isSelected: isDarkSelected,
                mode: AppThemeMode.dark,
                isOled: false,
                iconPack: iconPack,
                colors: colors,
                theme: theme,
                onTap: () async {
                  await themeNotifier.setOled(false);
                  await themeNotifier.setThemeMode(AppThemeMode.dark);
                  await themeNotifier.setPaletteId(AppPalettes.catppuccinId, resetCustomAccent: false);
                },
              ),
              const SizedBox(width: 10),
              _buildVisualThemeCard(
                label: l10n.themeLight,
                isSelected: isLightSelected,
                mode: AppThemeMode.light,
                isOled: false,
                iconPack: iconPack,
                colors: colors,
                theme: theme,
                onTap: () async {
                  await themeNotifier.setOled(false);
                  await themeNotifier.setThemeMode(AppThemeMode.light);
                  await themeNotifier.setPaletteId(AppPalettes.catppuccinLatteId, resetCustomAccent: false);
                },
              ),
              const SizedBox(width: 10),
              _buildVisualThemeCard(
                label: l10n.themeOled,
                isSelected: isOledSelected,
                mode: AppThemeMode.dark,
                isOled: true,
                iconPack: iconPack,
                colors: colors,
                theme: theme,
                onTap: () async {
                  await themeNotifier.setThemeMode(AppThemeMode.dark);
                  await themeNotifier.setOled(true);
                  await themeNotifier.setPaletteId(AppPalettes.oledBlackId, resetCustomAccent: false);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. ACCENT COLOR SELECTOR
          Text(
            l10n.accentColor,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildAccentColorPicker(themeSettings, themeNotifier, iconPack, colors, l10n),
          const SizedBox(height: 20),

          // 3. ICON PACK SELECTOR
          Text(
            l10n.iconPack,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildIconPackCard(
                  title: 'Lucide Web',
                  isSelected: iconPack == AppIconPack.lucide,
                  iconPack: iconPack,
                  icons: const [
                    LucideIcons.home,
                    LucideIcons.compass,
                    LucideIcons.bookOpen,
                    LucideIcons.settings,
                  ],
                  colors: colors,
                  onTap: () => iconPackNotifier.setIconPack(AppIconPack.lucide),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildIconPackCard(
                  title: 'Material Symbols',
                  isSelected: iconPack == AppIconPack.material,
                  iconPack: iconPack,
                  icons: const [
                    Icons.home_rounded,
                    Icons.explore_rounded,
                    Icons.menu_book_rounded,
                    Icons.settings_rounded,
                  ],
                  colors: colors,
                  onTap: () => iconPackNotifier.setIconPack(AppIconPack.material),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualThemeCard({
    required String label,
    required bool isSelected,
    required AppThemeMode mode,
    required bool isOled,
    required AppIconPack iconPack,
    required AppThemeColors colors,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.12)
                : colors.surfaceElevated.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colors.accent
                  : colors.border.withValues(alpha: 0.45),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini graphical window mockup
              Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? colors.accent.withValues(alpha: 0.35)
                        : colors.border.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildThemeGraphic(mode, isOled, iconPack, colors, isSelected),
              ),
              const SizedBox(height: 7),
              // Mode label + indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOled
                        ? AppIcons.tv(iconPack)
                        : (mode == AppThemeMode.dark
                            ? AppIcons.darkMode(iconPack)
                            : AppIcons.lightMode(iconPack)),
                    size: 13,
                    color: isSelected ? colors.accent : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? colors.accent : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeGraphic(
    AppThemeMode mode,
    bool isOled,
    AppIconPack iconPack,
    AppThemeColors colors,
    bool isSelected,
  ) {
    final isDark = mode == AppThemeMode.dark;
    final winBg = isOled
        ? Colors.black
        : (isDark ? const Color(0xFF141620) : const Color(0xFFF5F6FA));
    final headerColor = isOled
        ? const Color(0xFF0A0A0E)
        : (isDark ? const Color(0xFF1B1E2B) : const Color(0xFFE9ECF4));
    final cardBg = isOled
        ? const Color(0xFF101016)
        : (isDark ? const Color(0xFF1F2333) : Colors.white);
    final lineMuted = isOled
        ? const Color(0xFF22222E)
        : (isDark ? const Color(0xFF33384D) : const Color(0xFFCBD0DC));
    final borderColor = isOled
        ? const Color(0xFF1C1C26)
        : (isDark ? const Color(0xFF2B2F42) : const Color(0xFFDFE2EC));

    return Container(
      color: winBg,
      child: Column(
        children: [
          // Mini window header bar
          Container(
            height: 11,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            color: headerColor,
            child: Row(
              children: [
                Container(width: 3.5, height: 3.5, decoration: const BoxDecoration(color: Color(0xFFEF5350), shape: BoxShape.circle)),
                const SizedBox(width: 2.5),
                Container(width: 3.5, height: 3.5, decoration: const BoxDecoration(color: Color(0xFFFFB74D), shape: BoxShape.circle)),
                const SizedBox(width: 2.5),
                Container(width: 3.5, height: 3.5, decoration: const BoxDecoration(color: Color(0xFF81C784), shape: BoxShape.circle)),
                const Spacer(),
                Container(width: 14, height: 2.5, decoration: BoxDecoration(color: lineMuted, borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
          // Mini window body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  // Mini sidebar
                  Container(
                    width: 10,
                    decoration: BoxDecoration(
                      color: isOled
                          ? const Color(0xFF0F0F14)
                          : (isDark ? const Color(0xFF181B26) : const Color(0xFFE5E8F2)),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Mini content card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(3.5),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 5.0,
                                height: 5.0,
                                decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 3.5),
                              Expanded(
                                child: Container(height: 2.0, decoration: BoxDecoration(color: lineMuted, borderRadius: BorderRadius.circular(1.5))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Container(width: 18, height: 2, decoration: BoxDecoration(color: lineMuted.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(1))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconPackCard({
    required String title,
    required bool isSelected,
    required AppIconPack iconPack,
    required List<IconData> icons,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.12)
              : colors.surfaceElevated.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border.withValues(alpha: 0.45),
            width: 1.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? colors.accent : colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(AppIcons.checkCircle(iconPack), color: colors.accent, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: icons
                  .map((ic) => Icon(ic, size: 18, color: isSelected ? colors.accent : colors.textSecondary))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentColorPicker(
    ThemeSettings themeSettings,
    ThemeNotifier themeNotifier,
    AppIconPack iconPack,
    AppThemeColors colors,
    AppTranslations l10n,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Theme default accent
          Tooltip(
            message: l10n.themeAccentDefault,
            child: InkWell(
              onTap: () => themeNotifier.setAccentColor(null),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: themeSettings.currentPalette.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeSettings.customAccentIndex == null ? colors.textPrimary : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: themeSettings.customAccentIndex == null
                      ? [
                          BoxShadow(
                            color: themeSettings.currentPalette.accent.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    themeSettings.customAccentIndex == null
                        ? AppIcons.check(iconPack)
                        : AppIcons.sparkles(iconPack),
                    color: themeSettings.currentPalette.isDark ? Colors.black : Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
          // Custom material accent swatches
          ...List.generate(kMaterialAccents.length, (index) {
            final item = kMaterialAccents[index];
            final isSelected = themeSettings.customAccentIndex == index;

            return Tooltip(
              message: item.localizedName(l10n),
              child: InkWell(
                onTap: () => themeNotifier.setAccentColor(index),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colors.textPrimary : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Center(
                          child: Icon(
                            AppIcons.check(iconPack),
                            color: item.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            size: 16,
                          ),
                        )
                      : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
