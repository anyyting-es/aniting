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
  int _themeCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    final initialMode = ref.read(themeProvider).themeMode;
    if (initialMode == AppThemeMode.light) {
      _themeCategoryIndex = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final iconPack = ref.watch(iconPackProvider);
    final iconPackNotifier = ref.read(iconPackProvider.notifier);
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colors = context.themeColors;

    final List<AppThemePalette> activePalettes;
    if (_themeCategoryIndex == 0) {
      activePalettes = AppPalettes.getDarkPresets();
    } else if (_themeCategoryIndex == 1) {
      activePalettes = AppPalettes.getLightPresets();
    } else {
      activePalettes = AppPalettes.getMaterialPresets(
        isDark: themeSettings.themeMode != AppThemeMode.light,
      );
    }

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

          // 1. THEME MODE (Dark, Light, System) WITH VISUAL GRAPHICS
          Text(
            'Modo',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildVisualThemeModeCard(
                label: l10n.themeDark,
                mode: AppThemeMode.dark,
                isSelected: themeSettings.themeMode == AppThemeMode.dark,
                iconPack: iconPack,
                colors: colors,
                theme: theme,
                onTap: () {
                  themeNotifier.setThemeMode(AppThemeMode.dark);
                  setState(() => _themeCategoryIndex = 0);
                },
              ),
              const SizedBox(width: 10),
              _buildVisualThemeModeCard(
                label: l10n.themeLight,
                mode: AppThemeMode.light,
                isSelected: themeSettings.themeMode == AppThemeMode.light,
                iconPack: iconPack,
                colors: colors,
                theme: theme,
                onTap: () {
                  themeNotifier.setThemeMode(AppThemeMode.light);
                  setState(() => _themeCategoryIndex = 1);
                },
              ),
              const SizedBox(width: 10),
              _buildVisualThemeModeCard(
                label: l10n.themeSystem,
                mode: AppThemeMode.system,
                isSelected: themeSettings.themeMode == AppThemeMode.system,
                iconPack: iconPack,
                colors: colors,
                theme: theme,
                onTap: () => themeNotifier.setThemeMode(AppThemeMode.system),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. ICON PACK SELECTOR
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
          const SizedBox(height: 20),

          // 3. ACCENT COLOR SELECTOR
          Text(
            l10n.accentColor,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildAccentColorPicker(themeSettings, themeNotifier, iconPack, colors, l10n),
          const SizedBox(height: 20),

          // 4. COMMUNITY THEMES PALETTES
          Text(
            l10n.themePresets,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surfaceElevated.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildCategoryTab(
                  label: l10n.themeSectionDark,
                  isSelected: _themeCategoryIndex == 0,
                  theme: theme,
                  onTap: () => setState(() => _themeCategoryIndex = 0),
                ),
                const SizedBox(width: 4),
                _buildCategoryTab(
                  label: l10n.themeSectionLight,
                  isSelected: _themeCategoryIndex == 1,
                  theme: theme,
                  onTap: () => setState(() => _themeCategoryIndex = 1),
                ),
                const SizedBox(width: 4),
                _buildCategoryTab(
                  label: l10n.themeSectionMaterial,
                  isSelected: _themeCategoryIndex == 2,
                  theme: theme,
                  onTap: () => setState(() => _themeCategoryIndex = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Palettes List
          ...activePalettes.map((pal) {
            final isSelected = themeSettings.paletteId == pal.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  if (pal.category == 'light' && themeSettings.themeMode == AppThemeMode.dark) {
                    await themeNotifier.setThemeMode(AppThemeMode.light);
                  } else if (pal.category == 'dark' && themeSettings.themeMode == AppThemeMode.light) {
                    await themeNotifier.setThemeMode(AppThemeMode.dark);
                  }
                  await themeNotifier.setPaletteId(pal.id);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.accent.withValues(alpha: 0.12)
                        : colors.surfaceElevated.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? colors.accent.withValues(alpha: 0.5) : colors.border.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Palette mini color swatches
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: pal.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: pal.border, width: 1.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: pal.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pal.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13.5,
                                color: isSelected ? colors.accent : null,
                              ),
                            ),
                            Text(
                              pal.description,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(AppIcons.check(iconPack), color: colors.accent, size: 20)
                      else
                        Icon(AppIcons.radioUnchecked(iconPack), color: colors.border.withValues(alpha: 0.4), size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVisualThemeModeCard({
    required String label,
    required AppThemeMode mode,
    required bool isSelected,
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
                height: 54,
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
                child: _buildThemeModeGraphic(mode, iconPack, colors, isSelected),
              ),
              const SizedBox(height: 7),
              // Mode label + indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    mode == AppThemeMode.dark
                        ? AppIcons.darkMode(iconPack)
                        : mode == AppThemeMode.light
                            ? AppIcons.lightMode(iconPack)
                            : AppIcons.systemMode(iconPack),
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

  Widget _buildThemeModeGraphic(
    AppThemeMode mode,
    AppIconPack iconPack,
    AppThemeColors colors,
    bool isSelected,
  ) {
    if (mode == AppThemeMode.system) {
      return Row(
        children: [
          // Left half: Light mode
          Expanded(
            child: Container(
              color: const Color(0xFFF5F6FA),
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFCBD0DC), shape: BoxShape.circle)),
                      const SizedBox(width: 2.5),
                      Container(width: 12, height: 3, decoration: BoxDecoration(color: const Color(0xFFDFE2EC), borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFFE2E5EE), width: 0.8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Container(height: 2.5, decoration: BoxDecoration(color: const Color(0xFFCBD0DC), borderRadius: BorderRadius.circular(1))),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          // Vertical divider
          Container(width: 1, color: const Color(0xFF4A4E69).withValues(alpha: 0.3)),
          // Right half: Dark mode
          Expanded(
            child: Container(
              color: const Color(0xFF141620),
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF3B4054), shape: BoxShape.circle)),
                      const SizedBox(width: 2.5),
                      Container(width: 12, height: 3, decoration: BoxDecoration(color: const Color(0xFF262A3B), borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E212E),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF2E3347), width: 0.8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Container(height: 2.5, decoration: BoxDecoration(color: const Color(0xFF3B4054), borderRadius: BorderRadius.circular(1))),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final isDarkMode = mode == AppThemeMode.dark;
    final bgColor = isDarkMode ? const Color(0xFF141620) : const Color(0xFFF5F6FA);
    final headerColor = isDarkMode ? const Color(0xFF1B1E2B) : const Color(0xFFE9ECF4);
    final cardBg = isDarkMode ? const Color(0xFF1F2333) : Colors.white;
    final lineMuted = isDarkMode ? const Color(0xFF33384D) : const Color(0xFFCBD0DC);
    final borderColor = isDarkMode ? const Color(0xFF2B2F42) : const Color(0xFFDFE2EC);

    return Container(
      color: bgColor,
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
                      color: isDarkMode ? const Color(0xFF181B26) : const Color(0xFFE5E8F2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Mini content card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
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
                                width: 5.5,
                                height: 5.5,
                                decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 3.5),
                              Expanded(
                                child: Container(height: 2.5, decoration: BoxDecoration(color: lineMuted, borderRadius: BorderRadius.circular(1.5))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3.5),
                          Container(width: 20, height: 2, decoration: BoxDecoration(color: lineMuted.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(1))),
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

  Widget _buildCategoryTab({
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.4) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
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
              message: item.name,
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
