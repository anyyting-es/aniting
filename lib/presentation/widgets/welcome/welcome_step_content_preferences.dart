import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/preferences/title_language_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../m3_expressive_slider.dart';

class WelcomeStepContentPreferences extends ConsumerWidget {
  const WelcomeStepContentPreferences({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleLang = ref.watch(titleLanguageProvider);
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colors = context.themeColors;

    String sampleTitle;
    switch (titleLang) {
      case TitleLanguage.english:
        sampleTitle = 'Frieren: Beyond Journey’s End';
        break;
      case TitleLanguage.native:
        sampleTitle = '葬送のフリーレン';
        break;
      case TitleLanguage.romaji:
        sampleTitle = 'Sousou no Frieren';
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.welcomeStepPreferences,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          // ─── FILA PRINCIPAL: OPCIONES A LA IZQUIERDA, POSTER A LA DERECHA ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Lado izquierdo: Opciones de texto simples con visto (sin cajas ni bordes)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMinimalOption(
                      label: 'Romaji',
                      isSelected: titleLang == TitleLanguage.romaji,
                      colors: colors,
                      onTap: () => ref.read(titleLanguageProvider.notifier).setLanguage(TitleLanguage.romaji),
                    ),
                    const SizedBox(height: 14),
                    _buildMinimalOption(
                      label: 'English',
                      isSelected: titleLang == TitleLanguage.english,
                      colors: colors,
                      onTap: () => ref.read(titleLanguageProvider.notifier).setLanguage(TitleLanguage.english),
                    ),
                    const SizedBox(height: 14),
                    _buildMinimalOption(
                      label: 'Native',
                      isSelected: titleLang == TitleLanguage.native,
                      colors: colors,
                      onTap: () => ref.read(titleLanguageProvider.notifier).setLanguage(TitleLanguage.native),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Lado derecho: Poster vertical amplio y más grande + Título con altura fija
              SizedBox(
                width: 180,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final radius = ref.watch(themeProvider.select((s) => s.borderRadius));
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: Container(
                            width: 180,
                            height: 265,
                            color: colors.surfaceElevated.withValues(alpha: 0.25),
                            child: CachedNetworkImage(
                              imageUrl: 'https://image.tmdb.org/t/p/original/kT1ZkLmG9oNUz2Z10PqKCh8CwLI.jpg',
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.accent.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              errorWidget: (ctx, url, err) => Center(
                                child: Icon(Icons.movie_rounded, size: 40, color: colors.textMuted),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Contenedor de altura fija (38px) para que el cambio de idioma no mueva la UI
                    SizedBox(
                      height: 38,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            );
                          },
                          child: Text(
                            sampleTitle,
                            key: ValueKey(sampleTitle),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ─── SLIDER DE ESQUINAS (M3 EXPRESSIVE) ────────
          _WelcomeStepRadiusSlider(colors: colors),
        ],
      ),
    );
  }

  Widget _buildMinimalOption({
    required String label,
    required bool isSelected,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: isSelected ? 22 : 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? colors.textPrimary
                : colors.textSecondary.withValues(alpha: 0.35),
            letterSpacing: isSelected ? -0.4 : -0.2,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _WelcomeStepRadiusSlider extends ConsumerStatefulWidget {
  final AppThemeColors colors;
  const _WelcomeStepRadiusSlider({required this.colors});

  @override
  ConsumerState<_WelcomeStepRadiusSlider> createState() => _WelcomeStepRadiusSliderState();
}

class _WelcomeStepRadiusSliderState extends ConsumerState<_WelcomeStepRadiusSlider> {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.cornerRadius,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            Text(
              '${_localRadius.round()} px',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
      ],
    );
  }
}
