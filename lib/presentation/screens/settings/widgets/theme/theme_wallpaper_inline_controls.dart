import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:seanime_app/core/preferences/wallpaper_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/m3_expressive_slider.dart';

/// Inline Expressive sliders for Wallpaper Opacity and Blur, visible directly
/// in the Appearance settings header when custom wallpaper is enabled.
class ThemeWallpaperInlineControls extends StatelessWidget {
  final AppWallpaperState wallpaper;
  final AppWallpaperNotifier notifier;
  final ColorScheme colorScheme;
  final AppTranslations l10n;

  const ThemeWallpaperInlineControls({
    super.key,
    required this.wallpaper,
    required this.notifier,
    required this.colorScheme,
    required this.l10n,
  });

  Future<void> _pickImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isNotEmpty && files.first.path != null) {
        await notifier.setWallpaperPath(files.first.path!);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 22.0,
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      thumbColor: colorScheme.primary,
      overlayShape: SliderComponentShape.noOverlay,
      trackShape: const M3ExpressiveTrackShape(
        trackHeight: 22.0,
        gap: 3.5,
        outerRadius: 11.0,
        innerRadius: 2.5,
      ),
      thumbShape: const VerticalBarThumbShape(
        width: 4.0,
        height: 28.0,
        radius: 2.0,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 1. OPACIDAD ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.wallpaperOpacity,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(wallpaper.opacity * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: sliderTheme,
            child: Slider(
              min: 0.05,
              max: 0.85,
              divisions: 16,
              value: wallpaper.opacity.clamp(0.05, 0.85),
              onChanged: (val) => notifier.setOpacity(val),
            ),
          ),
          const SizedBox(height: 14),

          // ─── 2. DESENFOQUE (BLUR) ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.wallpaperBlur,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${wallpaper.blur.round()} px',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: sliderTheme,
            child: Slider(
              min: 0.0,
              max: 30.0,
              divisions: 30,
              value: wallpaper.blur.clamp(0.0, 30.0),
              onChanged: (val) => notifier.setBlur(val),
            ),
          ),
          const SizedBox(height: 12),

          // ─── 3. BOTONES DE ACCIÓN RÁPIDA ───────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _pickImage,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: Text(
                    l10n.changeWallpaper,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: l10n.removeWallpaper,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: colorScheme.error,
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: 0.35),
                  ),
                ),
                onPressed: () => notifier.clearWallpaper(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
