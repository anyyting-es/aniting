import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/theme/app_palette.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';
import 'package:seanime_app/presentation/widgets/common/focus_card.dart';
import 'package:seanime_app/presentation/widgets/m3_expressive_slider.dart';

/// Modern Web & Media Center Theme Settings Screen.
class ThemeSettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const ThemeSettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  int _selectedCategory = 0; // 0: Todos, 1: Oscuros, 2: Claros, 3: Material 3

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final iconPack = ref.watch(iconPackProvider);
    final iconPackNotifier = ref.read(iconPackProvider.notifier);
    final colors = context.themeColors;
    final l10n = ref.watch(translationsProvider);

    final isDark = themeSettings.themeMode != AppThemeMode.light;
    final List<AppThemePalette> presets;
    switch (_selectedCategory) {
      case 1:
        presets = AppPalettes.getDarkPresets();
        break;
      case 2:
        presets = AppPalettes.getLightPresets();
        break;
      case 3:
        presets = AppPalettes.getMaterialPresets(isDark: isDark);
        break;
      default:
        presets = AppPalettes.getPresets(isDark: isDark);
        break;
    }

    return PixelSubpageScaffold(
      title: l10n.themeAndColors,
      isEmbedded: widget.isEmbedded,
      children: [
        // ─── 1. PALETAS DE LA COMUNIDAD ───────────────────────────
        SettingsSectionHeader(title: l10n.themePresets),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            l10n.themePresetsDesc,
            style: TextStyle(fontSize: 12.5, color: colors.textMuted),
          ),
        ),
        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('Todos', 0, colors, themeSettings),
              const SizedBox(width: 8),
              _buildCategoryChip(l10n.themeSectionDark, 1, colors, themeSettings),
              const SizedBox(width: 8),
              _buildCategoryChip(l10n.themeSectionLight, 2, colors, themeSettings),
              const SizedBox(width: 8),
              _buildCategoryChip(l10n.themeSectionMaterial, 3, colors, themeSettings),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 520;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 80,
              ),
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                final isSelected = themeSettings.paletteId == preset.id && !themeSettings.isOled;

                return FocusCard(
                  onTap: () {
                    if (preset.category == 'light' && themeSettings.themeMode == AppThemeMode.dark) {
                      themeNotifier.setThemeMode(AppThemeMode.light);
                    } else if (preset.category == 'dark' && themeSettings.themeMode == AppThemeMode.light) {
                      themeNotifier.setThemeMode(AppThemeMode.dark);
                    }
                    if (preset.id == AppPalettes.oledBlackId) {
                      themeNotifier.setOled(true);
                      themeNotifier.setPaletteId(preset.id);
                    } else {
                      if (themeSettings.isOled) themeNotifier.setOled(false);
                      themeNotifier.setPaletteId(preset.id);
                    }
                  },
                  backgroundColor: preset.surface,
                  borderRadius: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Palette mini color swatches
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: preset.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: preset.border, width: 1),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: preset.surfaceElevated,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: preset.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: preset.background, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Names and description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              preset.name,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? colors.accent : preset.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              preset.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: preset.textMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Icon(
                          AppIcons.check(iconPack),
                          color: colors.accent,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 26),

        // ─── 2. PAQUETE DE ICONOS (LUCIDE WEB VS MATERIAL) ────────
        SettingsSectionHeader(title: l10n.iconPack),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            l10n.iconPackDesc,
            style: TextStyle(fontSize: 12.5, color: colors.textMuted),
          ),
        ),
        Row(
          children: [
            // Option A: Lucide (Web Moderno)
            Expanded(
              child: FocusCard(
                onTap: () => iconPackNotifier.setIconPack(AppIconPack.lucide),
                borderRadius: 10,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Lucide Web',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: iconPack == AppIconPack.lucide
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: iconPack == AppIconPack.lucide
                                ? colors.accent
                                : colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (iconPack == AppIconPack.lucide)
                          Icon(AppIcons.check(iconPack), color: colors.accent, size: 16),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Icon(LucideIcons.home, size: 18, color: colors.textSecondary),
                        Icon(LucideIcons.compass, size: 18, color: colors.textSecondary),
                        Icon(LucideIcons.bookOpen, size: 18, color: colors.textSecondary),
                        Icon(LucideIcons.settings, size: 18, color: colors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.iconPackLucideDesc,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Option B: Material Symbols (Clásico)
            Expanded(
              child: FocusCard(
                onTap: () => iconPackNotifier.setIconPack(AppIconPack.material),
                borderRadius: 10,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Material Symbols',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: iconPack == AppIconPack.material
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: iconPack == AppIconPack.material
                                ? colors.accent
                                : colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (iconPack == AppIconPack.material)
                          Icon(AppIcons.check(iconPack), color: colors.accent, size: 16),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Icon(Icons.home_rounded, size: 18, color: colors.textSecondary),
                        Icon(Icons.explore_rounded, size: 18, color: colors.textSecondary),
                        Icon(Icons.menu_book_rounded, size: 18, color: colors.textSecondary),
                        Icon(Icons.settings_rounded, size: 18, color: colors.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.iconPackMaterialDesc,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 26),

        // ─── 3. COLOR DE ACENTO Y OLED ────────────────────────────
        SettingsSectionHeader(title: l10n.accentColor),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Option 0: Theme's native accent color (Predeterminado del tema)
                  Tooltip(
                    message: l10n.themeAccentDefault,
                    child: InkWell(
                      onTap: () => themeNotifier.setAccentColor(null),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: themeSettings.currentPalette.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeSettings.customAccentIndex == null
                                ? colors.textPrimary
                                : Colors.transparent,
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
                        child: themeSettings.customAccentIndex == null
                            ? Center(
                                child: Icon(
                                  AppIcons.check(iconPack),
                                  color: themeSettings.currentPalette.isDark ? Colors.black : Colors.white,
                                  size: 18,
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: themeSettings.currentPalette.isDark
                                      ? Colors.black.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.6),
                                  size: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Custom accent color options
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
                          width: 38,
                          height: 38,
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
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: 10),
              PixelSwitchTile(
                icon: AppIcons.tv(iconPack),
                title: 'Negro puro (OLED True Black)',
                subtitle: 'Fondo negro #000000 absoluto para pantallas OLED',
                value: themeSettings.isOled,
                onChanged: (val) => themeNotifier.setOled(val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        // ─── 4. TEMA DINÁMICO DE ANIME ────────────────────────────
        SettingsSectionHeader(title: l10n.animeDynamicTheme),
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

        const SizedBox(height: 26),

        // ─── 5. ESQUINAS Y BORDES DE LA APP ──────────────────────
        SettingsSectionHeader(title: 'Esquinas y Bordes (Radio de Tarjetas)'),
        const SizedBox(height: 10),
        _ThemeSettingsRadiusSection(colors: colors),
      ],
    );
  }

  Widget _buildCategoryChip(String label, int index, AppThemeColors colors, ThemeSettings themeSettings) {
    final isSelected = _selectedCategory == index;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent.withValues(alpha: 0.15) : colors.surfaceElevated.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.accent.withValues(alpha: 0.5) : colors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colors.accent : colors.textSecondary,
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
  ConsumerState<_ThemeSettingsRadiusSection> createState() => _ThemeSettingsRadiusSectionState();
}

class _ThemeSettingsRadiusSectionState extends ConsumerState<_ThemeSettingsRadiusSection> {
  late double _localRadius;
  late double _lastBroadcastRadius;

  @override
  void initState() {
    super.initState();
    _localRadius = ref.read(themeProvider).borderRadius;
    _lastBroadcastRadius = _localRadius.roundToDouble();
  }

  void _onSliderChanged(double val) {
    setState(() => _localRadius = val);
    final rounded = val.roundToDouble();
    if (rounded != _lastBroadcastRadius) {
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
                        'Radio de esquinas',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ajusta la redondez visual de componentes',
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
                _buildRadiusChip('0 px (Cuadrado)', 0.0, _localRadius, colors),
                const SizedBox(width: 6),
                _buildRadiusChip('6 px (Sutil)', 6.0, _localRadius, colors),
                const SizedBox(width: 6),
                _buildRadiusChip('10 px (Normal)', 10.0, _localRadius, colors),
                const SizedBox(width: 6),
                _buildRadiusChip('16 px (Redondo)', 16.0, _localRadius, colors),
                const SizedBox(width: 6),
                _buildRadiusChip('22 px (Curvo)', 22.0, _localRadius, colors),
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
