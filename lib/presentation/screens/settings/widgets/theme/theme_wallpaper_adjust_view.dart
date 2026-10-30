import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/wallpaper_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/m3_expressive_slider.dart';
import '../settings_dpad_focus.dart';

/// In-page section view for adjusting wallpaper opacity, blur, and selecting/removing image.
class ThemeWallpaperAdjustView extends ConsumerWidget {
  final VoidCallback onBack;

  const ThemeWallpaperAdjustView({super.key, required this.onBack});

  Future<void> _pickWallpaper(BuildContext context, WidgetRef ref) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = ref.watch(translationsProvider);
    final wallpaper = ref.watch(wallpaperPreferencesProvider);
    final wallpaperNotifier = ref.read(wallpaperPreferencesProvider.notifier);

    final hasImage = wallpaper.hasValidWallpaper;

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
              l10n.customWallpaper,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Controls container
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row (Filename + buttons)
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.image,
                      size: 20,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasImage ? wallpaper.fileName : l10n.noWallpaperSelected,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.customWallpaperDesc,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasImage) ...[
                    IconButton(
                      tooltip: l10n.removeWallpaper,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: colorScheme.error,
                      onPressed: () => wallpaperNotifier.clearWallpaper(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: () => _pickWallpaper(context, ref),
                    icon: Icon(
                      hasImage ? LucideIcons.refreshCw : LucideIcons.folderOpen,
                      size: 16,
                    ),
                    label: Text(
                      hasImage ? l10n.changeWallpaper : l10n.pickWallpaper,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              if (hasImage) ...[
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 18),

                // Opacity Slider Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.wallpaperOpacity,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.wallpaperOpacityDesc,
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(wallpaper.opacity * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SettingsDpadSlider(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 24.0,
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.surfaceContainerHighest,
                      thumbColor: colorScheme.primary,
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
                      min: 0.05,
                      max: 0.85,
                      divisions: 16,
                      value: wallpaper.opacity.clamp(0.05, 0.85),
                      onChanged: (val) => wallpaperNotifier.setOpacity(val),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Blur Slider Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.wallpaperBlur,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.wallpaperBlurDesc,
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${wallpaper.blur.round()} px',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SettingsDpadSlider(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 24.0,
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.surfaceContainerHighest,
                      thumbColor: colorScheme.primary,
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
                      max: 30.0,
                      divisions: 30,
                      value: wallpaper.blur.clamp(0.0, 30.0),
                      onChanged: (val) => wallpaperNotifier.setBlur(val),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Preset Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip(l10n.wallpaperBlurSharp, 0.0, wallpaper.blur, colorScheme, wallpaperNotifier),
                      const SizedBox(width: 6),
                      _buildPresetChip(l10n.wallpaperBlurSoft, 6.0, wallpaper.blur, colorScheme, wallpaperNotifier),
                      const SizedBox(width: 6),
                      _buildPresetChip(l10n.wallpaperBlurBalanced, 12.0, wallpaper.blur, colorScheme, wallpaperNotifier),
                      const SizedBox(width: 6),
                      _buildPresetChip(l10n.wallpaperBlurDeep, 20.0, wallpaper.blur, colorScheme, wallpaperNotifier),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(
    String label,
    double targetValue,
    double currentValue,
    ColorScheme colorScheme,
    AppWallpaperNotifier notifier,
  ) {
    final isSelected = (currentValue - targetValue).abs() < 1.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => notifier.setBlur(targetValue),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
