import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/subtitle_style_preferences_provider.dart';

/// Complete, responsive subtitle customization sheet.
/// Allows fine-grained styling (font, size, colors, borders, shadows, and ASS override).
class SubtitleStyleView extends ConsumerWidget {
  const SubtitleStyleView({super.key});

  static const List<String> fontFamilies = [
    'sans-serif',
    'serif',
    'monospace',
    'Trebuchet MS',
    'Roboto',
    'OpenDyslexic',
  ];

  static const List<int> presetTextColors = [
    0xFFFFFFFF, // White
    0xFFFFF176, // Yellow
    0xFF80D8FF, // Cyan
    0xFFA7FFEB, // Mint
    0xFFFFD180, // Orange
    0xFFFF80AB, // Pink
    0xFFE0E0E0, // Light Grey
  ];

  static const List<int> presetBorderColors = [
    0xFF000000, // Black
    0xFF212121, // Dark Grey
    0xFFFFFFFF, // White
    0xFF0D47A1, // Deep Blue
    0xFF3E2723, // Deep Brown
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final prefs = ref.watch(subtitleStylePreferencesProvider);
    final notifier = ref.read(subtitleStylePreferencesProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Live Preview Card
          _buildLivePreview(context, prefs, l10n),
          const SizedBox(height: 16),

          // 2. ASS Override Toggle Card
          _buildAssOverrideCard(context, prefs, notifier, l10n, iconPack),
          const SizedBox(height: 16),

          // 3. Typography & Size Section
          _buildSectionHeader(context, l10n.subtitleFont, AppIcons.fileText(iconPack)),
          const SizedBox(height: 8),
          _buildFontFamilySelector(context, prefs, notifier),
          const SizedBox(height: 12),
          _buildFontSizeSlider(context, prefs, notifier, l10n),
          const SizedBox(height: 8),
          _buildStyleToggles(context, prefs, notifier, l10n, iconPack),
          const SizedBox(height: 16),

          // 4. Text & Background Colors Section
          _buildSectionHeader(context, l10n.subtitleTextColor, AppIcons.sparkles(iconPack)),
          const SizedBox(height: 8),
          _buildTextColorPicker(context, prefs, notifier),
          const SizedBox(height: 12),
          _buildBackgroundSelector(context, prefs, notifier, l10n),
          const SizedBox(height: 16),

          // 5. Border & Shadow Section
          _buildSectionHeader(context, l10n.subtitleBorderStyle, AppIcons.settings(iconPack)),
          const SizedBox(height: 8),
          _buildBorderStyleSelector(context, prefs, notifier, l10n),
          if (prefs.borderStyle != SubtitleBorderStyle.none) ...[
            const SizedBox(height: 12),
            _buildBorderSizeSlider(context, prefs, notifier, l10n),
            const SizedBox(height: 8),
            _buildBorderColorPicker(context, prefs, notifier, l10n),
          ],
          const SizedBox(height: 20),

          // 6. Reset Defaults Button
          _buildResetButton(context, notifier, l10n, iconPack),
        ],
      ),
    );
  }

  Widget _buildLivePreview(BuildContext context, SubtitleStylePrefs prefs, AppTranslations l10n) {
    final shadows = _buildTextShadows(prefs);

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1C24),
            Color(0xFF0F0F12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: prefs.bgFlutterColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.subtitlePreviewText,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: prefs.textFlutterColor,
            fontFamily: prefs.fontFamily == 'sans-serif' ? null : prefs.fontFamily,
            fontSize: 14.0 * prefs.fontSizeMultiplier,
            fontWeight: prefs.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: prefs.italic ? FontStyle.italic : FontStyle.normal,
            shadows: shadows,
          ),
        ),
      ),
    );
  }

  Widget _buildAssOverrideCard(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
    AppTranslations l10n,
    dynamic iconPack,
  ) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: prefs.overrideAss
              ? primaryColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.subtitles(iconPack),
                size: 18,
                color: prefs.overrideAss ? primaryColor : Colors.white70,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.subtitleOverrideAss,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: prefs.overrideAss ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              Switch(
                value: prefs.overrideAss,
                onChanged: (val) {
                  notifier.updateStyle((c) => c.copyWith(overrideAss: val));
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.subtitleOverrideAssDesc,
            style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildFontFamilySelector(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: fontFamilies.map((font) {
          final isSelected = prefs.fontFamily == font;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(font, style: TextStyle(fontFamily: font == 'sans-serif' ? null : font, fontSize: 11)),
              selected: isSelected,
              onSelected: (_) => notifier.updateStyle((c) => c.copyWith(fontFamily: font)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFontSizeSlider(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
    AppTranslations l10n,
  ) {
    final percent = (prefs.fontSizeMultiplier * 100).round();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(l10n.subtitleFontSize, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const Spacer(),
          Text('$percent%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          Expanded(
            flex: 3,
            child: Slider(
              value: prefs.fontSizeMultiplier,
              min: 0.7,
              max: 2.0,
              divisions: 26,
              onChanged: (val) {
                notifier.updateStyle((c) => c.copyWith(fontSizeMultiplier: val));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleToggles(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
    AppTranslations l10n,
    dynamic iconPack,
  ) {
    return Row(
      children: [
        Expanded(
          child: FilterChip(
            selected: prefs.bold,
            avatar: Icon(AppIcons.type(iconPack), size: 14),
            label: Text(l10n.subtitleBold, style: const TextStyle(fontSize: 11)),
            onSelected: (val) => notifier.updateStyle((c) => c.copyWith(bold: val)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilterChip(
            selected: prefs.italic,
            avatar: Icon(AppIcons.type(iconPack), size: 14),
            label: Text(l10n.subtitleItalic, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            onSelected: (val) => notifier.updateStyle((c) => c.copyWith(italic: val)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextColorPicker(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: presetTextColors.map((colorVal) {
        final isSelected = prefs.textColor == colorVal;
        return GestureDetector(
          onTap: () => notifier.updateStyle((c) => c.copyWith(textColor: colorVal)),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(colorVal),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white24,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackgroundSelector(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
    AppTranslations l10n,
  ) {
    final bgOptions = [
      (0x00000000, l10n.bgTransparent),
      (0x4D000000, l10n.bgSubtle),
      (0x99000000, l10n.bgMedium),
      (0xFF000000, l10n.bgSolid),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: bgOptions.map((opt) {
          final isSelected = prefs.backgroundColor == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(opt.$2, style: const TextStyle(fontSize: 11)),
              selected: isSelected,
              onSelected: (_) => notifier.updateStyle((c) => c.copyWith(backgroundColor: opt.$1)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBorderStyleSelector(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
    AppTranslations l10n,
  ) {
    final styles = [
      (SubtitleBorderStyle.none, l10n.borderStyleNone),
      (SubtitleBorderStyle.outline, l10n.borderStyleOutline),
      (SubtitleBorderStyle.dropShadow, l10n.borderStyleDropShadow),
      (SubtitleBorderStyle.raised, l10n.borderStyleRaised),
      (SubtitleBorderStyle.depressed, l10n.borderStyleDepressed),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: styles.map((s) {
          final isSelected = prefs.borderStyle == s.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(s.$2, style: const TextStyle(fontSize: 11)),
              selected: isSelected,
              onSelected: (_) => notifier.updateStyle((c) => c.copyWith(borderStyle: s.$1)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBorderSizeSlider(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
    AppTranslations l10n,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(l10n.subtitleBorderSize, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const Spacer(),
          Text(prefs.borderSize.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          Expanded(
            flex: 3,
            child: Slider(
              value: prefs.borderSize,
              min: 0.5,
              max: 6.0,
              divisions: 11,
              onChanged: (val) {
                notifier.updateStyle((c) => c.copyWith(borderSize: val));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorderColorPicker(
    BuildContext context,
    SubtitleStylePrefs prefs,
    SubtitleStylePreferencesNotifier notifier,
    AppTranslations l10n,
  ) {
    return Row(
      children: [
        Text(l10n.subtitleBorderColor, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(width: 12),
        ...presetBorderColors.map((colorVal) {
          final isSelected = prefs.borderColor == colorVal;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => notifier.updateStyle((c) => c.copyWith(borderColor: colorVal)),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Color(colorVal),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white30,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResetButton(
    BuildContext context,
    SubtitleStylePreferencesNotifier notifier,
    AppTranslations l10n,
    dynamic iconPack,
  ) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(AppIcons.refresh(iconPack), size: 16),
      label: Text(l10n.subtitleStyleReset, style: const TextStyle(fontSize: 12)),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.subtitleStyleReset),
            content: Text(l10n.subtitleStyleResetConfirm),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.reset)),
            ],
          ),
        );
        if (confirm == true) {
          await notifier.resetToDefaults();
        }
      },
    );
  }

  List<Shadow>? _buildTextShadows(SubtitleStylePrefs prefs) {
    final borderCol = prefs.borderFlutterColor;
    final bSize = prefs.borderSize;

    switch (prefs.borderStyle) {
      case SubtitleBorderStyle.none:
        return null;
      case SubtitleBorderStyle.outline:
        return [
          Shadow(offset: Offset(-bSize, -bSize), color: borderCol),
          Shadow(offset: Offset(bSize, -bSize), color: borderCol),
          Shadow(offset: Offset(-bSize, bSize), color: borderCol),
          Shadow(offset: Offset(bSize, bSize), color: borderCol),
          Shadow(offset: Offset(0, -bSize), color: borderCol),
          Shadow(offset: Offset(0, bSize), color: borderCol),
          Shadow(offset: Offset(-bSize, 0), color: borderCol),
          Shadow(offset: Offset(bSize, 0), color: borderCol),
        ];
      case SubtitleBorderStyle.dropShadow:
        return [
          Shadow(offset: Offset(bSize, bSize), blurRadius: bSize * 1.5, color: borderCol),
        ];
      case SubtitleBorderStyle.raised:
        return [
          Shadow(offset: Offset(-bSize * 0.7, -bSize * 0.7), color: Colors.white54),
          Shadow(offset: Offset(bSize * 0.7, bSize * 0.7), color: borderCol),
        ];
      case SubtitleBorderStyle.depressed:
        return [
          Shadow(offset: Offset(bSize * 0.7, bSize * 0.7), color: Colors.white54),
          Shadow(offset: Offset(-bSize * 0.7, -bSize * 0.7), color: borderCol),
        ];
    }
  }
}
