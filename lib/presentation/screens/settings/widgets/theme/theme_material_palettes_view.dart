import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:seanime_app/core/constants/feature_flags.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/wallpaper_preferences_provider.dart';
import 'package:seanime_app/core/theme/app_palette.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';

class PaletteOptionItem {
  final String id;
  final String name;
  final String description;
  final Color seedColor;
  final IconData? icon;

  const PaletteOptionItem({
    required this.id,
    required this.name,
    required this.description,
    required this.seedColor,
    this.icon,
  });
}

/// In-page section view for selecting Material Design 3 palettes.
class ThemeMaterialPalettesView extends ConsumerWidget {
  final VoidCallback onBack;

  const ThemeMaterialPalettesView({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = ref.watch(translationsProvider);
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    final isDark = themeSettings.themeMode != AppThemeMode.light;

    // Build the pure Material Design 3 palettes list
    final List<PaletteOptionItem> palettes = [];

    // 1. Material You Dinámico del Fondo (hidden while the wallpaper feature is off)
    if (FeatureFlags.customWallpaper) {
      final wallpaper = ref.watch(wallpaperPreferencesProvider);
      final wallpaperSeed = AppPalettes.wallpaperSeedColor ??
          wallpaper.seedColor ??
          colorScheme.primary;

      palettes.add(
        PaletteOptionItem(
          id: AppPalettes.materialWallpaperId,
          name: l10n.materialWallpaperName,
          description: l10n.materialWallpaperDesc,
          seedColor: wallpaperSeed,
          icon: LucideIcons.image,
        ),
      );
    }

    // 2. Standard Material Design 3 Harmonious Palettes
    final m3Infos = [
      PaletteOptionItem(
        id: AppPalettes.materialPurpleId,
        name: l10n.materialPurpleName,
        description: 'Diseño Material 3 con violeta dinámico y armónico',
        seedColor: const Color(0xFF6750A4),
      ),
      PaletteOptionItem(
        id: AppPalettes.materialBlueId,
        name: l10n.materialBlueName,
        description: 'Diseño Material 3 con azul pacífico y elegante',
        seedColor: const Color(0xFF0061A4),
      ),
      PaletteOptionItem(
        id: AppPalettes.materialGreenId,
        name: l10n.materialGreenName,
        description: 'Diseño Material 3 con verde esmeralda y menta fresco',
        seedColor: const Color(0xFF006E1C),
      ),
      PaletteOptionItem(
        id: AppPalettes.materialOrangeId,
        name: l10n.materialOrangeName,
        description: 'Diseño Material 3 con cálido ámbar dorado',
        seedColor: const Color(0xFF8B5000),
      ),
      PaletteOptionItem(
        id: AppPalettes.materialCrimsonId,
        name: l10n.materialCrimsonName,
        description: 'Diseño Material 3 con rosa carmesí refinado',
        seedColor: const Color(0xFF9C4146),
      ),
      PaletteOptionItem(
        id: AppPalettes.materialTealId,
        name: l10n.materialTealName,
        description: 'Diseño Material 3 con turquesa equilibrado',
        seedColor: const Color(0xFF006A6A),
      ),
    ];
    palettes.addAll(m3Infos);

    // 3. System Matugen / Dank Shell (if on Linux and detected)
    if (Platform.isLinux) {
      final systemDms = AppPalettes.detectSystemPalette();
      if (systemDms != null) {
        palettes.add(
          PaletteOptionItem(
            id: AppPalettes.systemId,
            name: l10n.paletteSystem,
            description: systemDms.description,
            seedColor: systemDms.accent,
            icon: LucideIcons.monitor,
          ),
        );
      }
    }

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.materialDesignPalettes,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.materialDesignPalettesDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grouped container for all palettes (sidebar/grouped style)
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
            children: List.generate(palettes.length, (index) {
              final item = palettes[index];
              final isSelected = themeSettings.paletteId == item.id && !themeSettings.isOled;
              final isLast = index == palettes.length - 1;

              return Column(
                children: [
                  _buildPaletteTile(
                    item: item,
                    isSelected: isSelected,
                    colorScheme: colorScheme,
                    isDark: isDark,
                    onTap: () async {
                      await themeNotifier.setOled(false);
                      await themeNotifier.setPaletteId(item.id, resetCustomAccent: false);
                    },
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPaletteTile({
    required PaletteOptionItem item,
    required bool isSelected,
    required ColorScheme colorScheme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Vibrant color circle indicator
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.seedColor,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: item.seedColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: item.icon != null
                    ? Icon(
                        item.icon,
                        size: 15,
                        color: ThemeData.estimateBrightnessForColor(item.seedColor) == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Title and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Selection indicator
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
    );
  }
}
