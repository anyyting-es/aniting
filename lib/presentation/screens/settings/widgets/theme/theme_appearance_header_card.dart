import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/constants/feature_flags.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/wallpaper_preferences_provider.dart';
import 'package:seanime_app/core/theme/app_palette.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import '../settings_dpad_focus.dart';
import 'theme_wallpaper_inline_controls.dart';

/// Expressive Header Card matching the modern Appearance layout:
/// Left: Wallpaper preview thumbnail (clean image, no filters) with hover actions and tap-to-adjust.
/// Right: 3-segment mode selector (Claro / Oscuro / Sistema), OLED toggle (only in dark mode), and custom wallpaper.
class ThemeAppearanceHeaderCard extends ConsumerWidget {
  final VoidCallback onOpenWallpaper;

  const ThemeAppearanceHeaderCard({
    super.key,
    required this.onOpenWallpaper,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = ref.watch(translationsProvider);
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final wallpaper = ref.watch(wallpaperPreferencesProvider);

    return PixelCardContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 540;

          final controlsWidget = _buildControlsColumn(
            context,
            ref,
            themeSettings,
            themeNotifier,
            colorScheme,
            l10n,
          );

          if (!FeatureFlags.customWallpaper) {
            return controlsWidget;
          }

          final previewWidget = _WallpaperThumbnail(
            wallpaper: wallpaper,
            colorScheme: colorScheme,
            l10n: l10n,
            onOpenWallpaper: onOpenWallpaper,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: previewWidget),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: controlsWidget),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              previewWidget,
              const SizedBox(height: 14),
              controlsWidget,
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlsColumn(
    BuildContext context,
    WidgetRef ref,
    ThemeSettings themeSettings,
    ThemeNotifier themeNotifier,
    ColorScheme colorScheme,
    AppTranslations l10n,
  ) {
    final wallpaper = ref.watch(wallpaperPreferencesProvider);
    final wallpaperNotifier = ref.read(wallpaperPreferencesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ─── ROW 1: M3EBUTTONGROUP CONNECTED (CLARO / OSCURO / SISTEMA) ───
        M3EButtonGroup(
          type: M3EButtonGroupType.connected,
          direction: Axis.horizontal,
          shape: M3EButtonShape.round,
          size: M3EButtonSize.sm,
          style: M3EButtonStyle.filled,
          density: M3EButtonGroupDensity.regular,
          neighborSquish: true,
          expandedRatio: 0.15,
          overflow: M3EButtonGroupOverflow.scroll,
          selectionRequired: true,
          selectedIndex: switch (themeSettings.themeMode) {
            AppThemeMode.light => 0,
            AppThemeMode.dark => 1,
            AppThemeMode.system => 2,
          },
          decoration: M3EButtonDecoration(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primary;
              }
              return colorScheme.surfaceContainerHighest;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.onPrimary;
              }
              return colorScheme.onSurface;
            }),
          ),
          onSelectedIndexChanged: (int? index) async {
            if (index == null) return;
            if (index == 0) {
              await themeNotifier.updateThemeMode(AppThemeMode.light);
            } else if (index == 1) {
              await themeNotifier.updateThemeMode(AppThemeMode.dark);
            } else if (index == 2) {
              await themeNotifier.updateThemeMode(AppThemeMode.system);
            }
          },
          actions: <M3EButtonGroupAction>[
            M3EButtonGroupAction(
              icon: const Icon(Icons.light_mode_outlined, size: 16),
              label: Text(l10n.themeLight),
            ),
            M3EButtonGroupAction(
              icon: const Icon(Icons.dark_mode_rounded, size: 16),
              label: Text(l10n.themeDark),
            ),
            M3EButtonGroupAction(
              icon: const Icon(Icons.settings_brightness_rounded, size: 16),
              label: Text(l10n.themeSystem),
            ),
          ],
        ),

        // ─── ROW 2: OLED SOLO CUANDO ESTÁ EN MODO OSCURO (CON ANIMACIÓN EXPRESIVA) ───
        ExcludeFocus(
          excluding: themeSettings.themeMode != AppThemeMode.dark,
          child: AnimatedCrossFade(
            crossFadeState: themeSettings.themeMode == AppThemeMode.dark
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeOutCubic,
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeInCubic,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: PixelSwitchTile(
                  icon: Icons.brightness_2_rounded,
                  title: l10n.darkModeOled,
                  subtitle: l10n.darkModeSubtitleManual,
                  value: themeSettings.isOled,
                  borderRadius: BorderRadius.circular(16),
                  onChanged: (val) async {
                    await themeNotifier.setOled(val);
                  },
                ),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ),

        // ─── ROW 3: FONDO PERSONALIZADO INLINE (SI ESTÁ HABILITADO) ──
        if (FeatureFlags.customWallpaper) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSubOptionTile(
                  icon: LucideIcons.image,
                  title: l10n.customWallpaper,
                  subtitle: wallpaper.hasValidWallpaper
                      ? wallpaper.fileName
                      : (wallpaper.filePath != null ? l10n.disabled : l10n.noWallpaperSelected),
                  colorScheme: colorScheme,
                  trailing: Switch(
                    value: wallpaper.hasValidWallpaper,
                    activeColor: colorScheme.primary,
                    onChanged: (val) async {
                      if (val) {
                        if (wallpaper.filePath != null && File(wallpaper.filePath!).existsSync()) {
                          await wallpaperNotifier.setEnabled(true);
                          await themeNotifier.setOled(false);
                          await themeNotifier.setPaletteId(
                            AppPalettes.materialWallpaperId,
                            resetCustomAccent: true,
                          );
                        } else {
                          try {
                            final files = await FilePicker.pickFiles(type: FileType.image);
                            if (files.isNotEmpty && files.first.path != null) {
                              await wallpaperNotifier.setWallpaperPath(files.first.path);
                            }
                          } catch (_) {}
                        }
                      } else {
                        await wallpaperNotifier.setEnabled(false);
                      }
                    },
                  ),
                  onTap: onOpenWallpaper,
                ),
                if (wallpaper.hasValidWallpaper) ...[
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                  ThemeWallpaperInlineControls(
                    wallpaper: wallpaper,
                    notifier: wallpaperNotifier,
                    colorScheme: colorScheme,
                    l10n: l10n,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return SettingsDpadFocus(
      borderRadius: BorderRadius.circular(16),
      onActivate: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive 16:9 Wallpaper thumbnail with pure image (no blur/effects) and hover overlay.
class _WallpaperThumbnail extends ConsumerStatefulWidget {
  final AppWallpaperState wallpaper;
  final ColorScheme colorScheme;
  final AppTranslations l10n;
  final VoidCallback onOpenWallpaper;

  const _WallpaperThumbnail({
    required this.wallpaper,
    required this.colorScheme,
    required this.l10n,
    required this.onOpenWallpaper,
  });

  @override
  ConsumerState<_WallpaperThumbnail> createState() => _WallpaperThumbnailState();
}

class _WallpaperThumbnailState extends ConsumerState<_WallpaperThumbnail> {
  bool _isHovered = false;

  Future<void> _pickWallpaper() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isNotEmpty) {
        final path = files.first.path;
        if (path != null && path.isNotEmpty) {
          await ref.read(wallpaperPreferencesProvider.notifier).setWallpaperPath(path);
        }
      }
    } catch (e) {
      debugPrint('Error picking wallpaper: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.wallpaper.hasValidWallpaper;
    final colorScheme = widget.colorScheme;
    final l10n = widget.l10n;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: hasImage ? widget.onOpenWallpaper : _pickWallpaper,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Pure Wallpaper Image without ANY filters or blur
                if (hasImage)
                  Image.file(
                    File(widget.wallpaper.filePath!),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholder(colorScheme, l10n),
                  )
                else
                  _buildPlaceholder(colorScheme, l10n),

                // 2. Bottom-left Filename Badge (always visible, high contrast)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasImage ? LucideIcons.image : LucideIcons.imagePlus,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            hasImage ? widget.wallpaper.fileName : l10n.noWallpaperSelected,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Hover Overlay with interactive actions (No separate card!)
                ExcludeFocus(
                  excluding: !_isHovered,
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.65),
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Change / Pick Image Button
                            FilledButton.tonalIcon(
                              onPressed: _pickWallpaper,
                              icon: Icon(
                                hasImage ? LucideIcons.refreshCw : LucideIcons.folderOpen,
                                size: 15,
                              ),
                              label: Text(
                                hasImage ? l10n.changeWallpaper : l10n.pickWallpaper,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: const Size(0, 36),
                              ),
                            ),
                            if (hasImage) ...[
                              const SizedBox(width: 8),
                              // Adjust Opacity & Blur Button
                              IconButton.filledTonal(
                                tooltip: l10n.adjustWallpaper,
                                onPressed: widget.onOpenWallpaper,
                                icon: const Icon(LucideIcons.sliders, size: 16),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Remove Button
                              IconButton.filledTonal(
                                tooltip: l10n.removeWallpaper,
                                onPressed: () => ref.read(wallpaperPreferencesProvider.notifier).clearWallpaper(),
                                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.error.withValues(alpha: 0.8),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme, AppTranslations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.imagePlus,
                size: 22,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            ExcludeFocus(
              child: FilledButton.tonalIcon(
                onPressed: _pickWallpaper,
                icon: const Icon(LucideIcons.folderOpen, size: 15),
                label: Text(
                  l10n.pickWallpaper,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
