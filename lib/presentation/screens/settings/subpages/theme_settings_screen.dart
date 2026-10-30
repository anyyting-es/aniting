import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/feature_flags.dart';
import '../../../../core/i18n/i18n_provider.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../widgets/pixel_settings_widgets.dart';
import '../widgets/pixel_subpage_scaffold.dart';
import '../widgets/settings_dpad_focus.dart';
import '../widgets/theme/theme_appearance_header_card.dart';
import '../widgets/theme/theme_dark_mode_view.dart';
import '../widgets/theme/theme_material_palettes_view.dart';
import '../widgets/theme/theme_wallpaper_adjust_view.dart';
import '../../../widgets/m3_expressive_slider.dart';

enum ThemeSubSection {
  main,
  darkMode,
  palettes,
  wallpaper,
}

/// Modern Web & Media Center Theme Settings Screen.
/// In-page sections for Dark Mode, Material Design 3 Palettes, and Wallpaper (No modals!).
class ThemeSettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const ThemeSettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  ThemeSubSection _currentSection = ThemeSubSection.main;

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final iconPack = ref.watch(iconPackProvider);
    final iconPackNotifier = ref.read(iconPackProvider.notifier);
    final colors = context.themeColors;
    final l10n = ref.watch(translationsProvider);

    return PopScope(
      canPop: _currentSection == ThemeSubSection.main,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _currentSection = ThemeSubSection.main);
        }
      },
      child: PixelSubpageScaffold(
        title: _currentSection == ThemeSubSection.main
            ? l10n.themeAndColors
            : (_currentSection == ThemeSubSection.darkMode
                ? l10n.darkMode
                : (_currentSection == ThemeSubSection.palettes
                    ? l10n.themeAndColors
                    : l10n.customWallpaper)),
        isEmbedded: widget.isEmbedded,
        children: [
          if (_currentSection == ThemeSubSection.darkMode)
            ThemeDarkModeView(
              onBack: () => setState(() => _currentSection = ThemeSubSection.main),
            )
          else if (_currentSection == ThemeSubSection.palettes)
            ThemeMaterialPalettesView(
              onBack: () => setState(() => _currentSection = ThemeSubSection.main),
            )
          else if (_currentSection == ThemeSubSection.wallpaper &&
              FeatureFlags.customWallpaper)
            ThemeWallpaperAdjustView(
              onBack: () => setState(() => _currentSection = ThemeSubSection.main),
            )
          else ...[
            // ─── 1. CABECERA APARIENCIA (WALLPAPER + TOGGLE + MODOS) ───
            ThemeAppearanceHeaderCard(
              onOpenDarkMode: () => setState(() => _currentSection = ThemeSubSection.darkMode),
              onOpenPalettes: () => setState(() => _currentSection = ThemeSubSection.palettes),
              onOpenWallpaper: () {
                if (!FeatureFlags.customWallpaper) return;
                setState(() => _currentSection = ThemeSubSection.wallpaper);
              },
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

            // ─── 3. TEMA DINÁMICO DE ANIME ────────────────────────────
            SettingsSectionHeader(title: l10n.appearanceAndDisplay),
            const SizedBox(height: 10),
            PixelSettingsGroupCard(
              children: [
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

            // ─── 4. ESQUINAS Y BORDES DE LA APP ───────────────────────
            SettingsSectionHeader(title: l10n.cornerAndBorders),
            const SizedBox(height: 10),
            _ThemeSettingsRadiusSection(colors: colors),
          ],
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
    return SettingsDpadFocus(
      borderRadius: BorderRadius.circular(16),
      onActivate: onTap,
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.14)
                : colors.surfaceElevated.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colors.accent
                  : colors.border.withValues(alpha: 0.35),
              width: isSelected ? 1.6 : 1.0,
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
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? colors.accent : colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      AppIcons.checkCircle(iconPack),
                      color: colors.accent,
                      size: 17,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: icons
                    .map(
                      (ic) => Icon(
                        ic,
                        size: 20,
                        color: isSelected ? colors.accent : colors.textSecondary,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSettingsRadiusSection extends ConsumerStatefulWidget {
  final AppThemeColors colors;
  const _ThemeSettingsRadiusSection({required this.colors});

  @override
  ConsumerState<_ThemeSettingsRadiusSection> createState() =>
      _ThemeSettingsRadiusSectionState();
}

class _ThemeSettingsRadiusSectionState
    extends ConsumerState<_ThemeSettingsRadiusSection> {
  double _localRadius = 10.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _localRadius = ref.read(themeProvider).borderRadius;
  }

  void _onSliderChanged(double value) {
    setState(() {
      _isDragging = true;
      _localRadius = value;
    });
  }

  void _onSliderEnd(double value) {
    setState(() => _isDragging = false);
    ref.read(themeProvider.notifier).setBorderRadius(value);
  }

  void _selectPreset(double value) {
    setState(() => _localRadius = value);
    ref.read(themeProvider.notifier).setBorderRadius(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final l10n = ref.watch(translationsProvider);

    if (!_isDragging) {
      final current = ref.watch(themeProvider.select((s) => s.borderRadius));
      if (_localRadius != current) {
        _localRadius = current;
      }
    }

    return PixelCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.cornerRadius,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.4),
                  ),
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
          const SizedBox(height: 10),
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

  Widget _buildRadiusChip(
    String label,
    double value,
    double current,
    AppThemeColors colors,
  ) {
    final isSelected = (current - value).abs() < 1.0;
    return SettingsDpadFocus(
      borderRadius: BorderRadius.circular(8),
      onActivate: () => _selectPreset(value),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: () => _selectPreset(value),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.accent.withValues(alpha: 0.2)
                  : colors.surfaceElevated.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? colors.accent.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.accent : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
