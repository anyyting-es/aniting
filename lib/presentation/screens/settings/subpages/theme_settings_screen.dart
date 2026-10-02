import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/i18n/i18n_provider.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../widgets/pixel_settings_widgets.dart';
import '../widgets/pixel_subpage_scaffold.dart';
import '../../../widgets/m3_expressive_slider.dart';

/// Modern Web & Media Center Theme Settings Screen, matching the clean appearance of the Setup Wizard.
class ThemeSettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const ThemeSettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  int _themeCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    final currentPalette = ref.read(themeProvider).paletteId;
    final initialMode = ref.read(themeProvider).themeMode;
    if (currentPalette.startsWith('material_')) {
      _themeCategoryIndex = 2;
    } else if (initialMode == AppThemeMode.light) {
      _themeCategoryIndex = 1;
    } else {
      _themeCategoryIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final iconPack = ref.watch(iconPackProvider);
    final iconPackNotifier = ref.read(iconPackProvider.notifier);
    final colors = context.themeColors;
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

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

    return PixelSubpageScaffold(
      title: l10n.themeAndColors,
      isEmbedded: widget.isEmbedded,
      children: [
        // ─── 1. MODE (Dark, Light, System) ────────────────────────
        SettingsSectionHeader(title: l10n.mode),
        const SizedBox(height: 10),
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
        const SizedBox(height: 24),

        // ─── 2. ICON PACK ─────────────────────────────────────────
        SettingsSectionHeader(title: l10n.iconPack),
        const SizedBox(height: 10),
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
        const SizedBox(height: 24),

        // ─── 3. ACCENT COLOR ──────────────────────────────────────
        SettingsSectionHeader(title: l10n.accentColor),
        const SizedBox(height: 10),
        _buildAccentColorPicker(themeSettings, themeNotifier, iconPack, colors, l10n),
        const SizedBox(height: 24),

        // ─── 4. COMMUNITY PALETTES ────────────────────────────────
        SettingsSectionHeader(title: l10n.themePresets),
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
          final isSelected = themeSettings.paletteId == pal.id &&
              (pal.id == AppPalettes.oledBlackId ? themeSettings.isOled : !themeSettings.isOled);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () async {
                if (pal.category == 'light' && themeSettings.themeMode == AppThemeMode.dark) {
                  await themeNotifier.setThemeMode(AppThemeMode.light);
                } else if (pal.category == 'dark' && themeSettings.themeMode == AppThemeMode.light) {
                  await themeNotifier.setThemeMode(AppThemeMode.dark);
                }
                if (pal.id == AppPalettes.oledBlackId) {
                  await themeNotifier.setOled(true);
                  await themeNotifier.setPaletteId(pal.id);
                } else {
                  if (themeSettings.isOled) await themeNotifier.setOled(false);
                  await themeNotifier.setPaletteId(pal.id);
                }
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
                      child: Text(
                        pal.localizedName(l10n),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13.5,
                          color: isSelected ? colors.accent : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: 20),

        // ─── 5. OLED & TEMA DINÁMICO ──────────────────────────────
        SettingsSectionHeader(title: l10n.appearanceAndDisplay),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: AppIcons.tv(iconPack),
              title: l10n.oledTrueBlackTitle,
              subtitle: l10n.oledTrueBlackDesc,
              value: themeSettings.isOled,
              onChanged: (val) => themeNotifier.setOled(val),
            ),
            const Divider(height: 1, indent: 56),
            PixelSwitchTile(
              icon: AppIcons.sparkles(iconPack),
              title: l10n.animeDynamicTheme,
              subtitle: l10n.animeDynamicThemeDesc,
              value: themeSettings.animeDynamicTheme,
              onChanged: (val) => themeNotifier.setAnimeDynamicTheme(val),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ─── 6. ESQUINAS Y BORDES DE LA APP ──────────────────────
        SettingsSectionHeader(title: l10n.cornerAndBorders),
        const SizedBox(height: 10),
        _ThemeSettingsRadiusSection(colors: colors),
      ],
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

    final isDark = mode == AppThemeMode.dark;
    final winBg = isDark ? const Color(0xFF13151F) : const Color(0xFFF6F7FB);
    final cardBg = isDark ? const Color(0xFF1C1F2E) : Colors.white;
    final dotColor = isDark ? const Color(0xFF3B4054) : const Color(0xFFCBD0DC);
    final lineTitle = isDark ? const Color(0xFF262A3B) : const Color(0xFFDFE2EC);
    final lineMuted = isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E8F0);
    final borderColor = isDark ? const Color(0xFF2E3347) : const Color(0xFFE2E5EE);

    return Container(
      color: winBg,
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4.5, height: 4.5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Container(width: 16, height: 3, decoration: BoxDecoration(color: lineTitle, borderRadius: BorderRadius.circular(2))),
            ],
          ),
          const Spacer(),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF25293D) : const Color(0xFFECEFF6),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(width: 5),
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

/// Slider for app corner radius adjustment with Material 3 Expressive shapes.
class _ThemeSettingsRadiusSection extends ConsumerStatefulWidget {
  final AppThemeColors colors;
  const _ThemeSettingsRadiusSection({required this.colors});

  @override
  ConsumerState<_ThemeSettingsRadiusSection> createState() => _ThemeSettingsRadiusSectionState();
}

class _ThemeSettingsRadiusSectionState extends ConsumerState<_ThemeSettingsRadiusSection> {
  late double _localRadius;
  double? _lastBroadcastRadius;

  @override
  void initState() {
    super.initState();
    _localRadius = ref.read(themeProvider).borderRadius;
  }

  void _onSliderChanged(double val) {
    setState(() => _localRadius = val);
    final rounded = val.roundToDouble();
    if (_lastBroadcastRadius != rounded) {
      _lastBroadcastRadius = rounded;
      ref.read(themeProvider.notifier).setPreviewBorderRadius(rounded);
    }
  }

  void _onSliderEnd(double val) {
    final rounded = val.roundToDouble();
    setState(() => _localRadius = rounded);
    _lastBroadcastRadius = rounded;
    ref.read(themeProvider.notifier).setBorderRadius(rounded);
  }

  void _onChipSelected(double val) {
    setState(() => _localRadius = val);
    _lastBroadcastRadius = val;
    ref.read(themeProvider.notifier).setBorderRadius(val);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final l10n = ref.watch(translationsProvider);

    ref.listen<double>(
      themeProvider.select((s) => s.borderRadius),
      (prev, next) {
        if ((next - _localRadius).abs() > 0.01) {
          setState(() {
            _localRadius = next;
            _lastBroadcastRadius = next.roundToDouble();
          });
        }
      },
    );

    return PixelCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.rounded_corner_rounded, size: 20, color: colors.textSecondary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cornerRadius,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.adjustCornerRadiusDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_localRadius.round()} px',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 24.0,
              activeTrackColor: colors.accent,
              inactiveTrackColor: colors.surfaceElevated,
              thumbColor: colors.accent,
              overlayShape: SliderComponentShape.noOverlay,
              trackShape: const M3ExpressiveTrackShape(
                trackHeight: 24.0,
                gap: 4.0,
                outerRadius: 12.0,
                innerRadius: 2.5,
              ),
              thumbShape: const VerticalBarThumbShape(
                width: 4.0,
                height: 32.0,
                radius: 2.0,
              ),
            ),
            child: Slider(
              min: 0.0,
              max: 24.0,
              divisions: 24,
              value: _localRadius.clamp(0.0, 24.0),
              onChanged: _onSliderChanged,
              onChangeEnd: _onSliderEnd,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRadiusChip(l10n.cornerRadiusSquare, 0.0, _localRadius, colors),
                const SizedBox(width: 6),
                _buildRadiusChip(l10n.cornerRadiusSubtle, 6.0, _localRadius, colors),
                const SizedBox(width: 6),
                _buildRadiusChip(l10n.cornerRadiusNormal, 10.0, _localRadius, colors),
                const SizedBox(width: 6),
                _buildRadiusChip(l10n.cornerRadiusRound, 16.0, _localRadius, colors),
                const SizedBox(width: 6),
                _buildRadiusChip(l10n.cornerRadiusCurved, 22.0, _localRadius, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusChip(String label, double value, double currentRadius, AppThemeColors colors) {
    final isSelected = (currentRadius.round() == value.round());
    return InkWell(
      onTap: () => _onChipSelected(value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent.withValues(alpha: 0.18) : colors.surfaceElevated.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border.withValues(alpha: 0.3),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colors.accent : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
