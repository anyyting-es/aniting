import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/desktop_scrollbar_provider.dart';
import 'package:seanime_app/core/preferences/episode_view_mode_provider.dart';
import 'package:seanime_app/core/preferences/layout_mode_provider.dart';
import 'package:seanime_app/core/preferences/mobile_nav_style_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/preferences/show_scores_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';
import 'package:seanime_app/presentation/widgets/m3_expressive_slider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA: APARIENCIA E INTERFAZ (ESTILO ANDROID 16 / PIXEL)
// ─────────────────────────────────────────────────────────────────────────────
class PersonalizacionSettingsScreen extends ConsumerWidget {
  final bool isEmbedded;
  const PersonalizacionSettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontId = ref.watch(themeProvider.select((s) => s.fontId));
    final titleLang = ref.watch(titleLanguageProvider);
    final episodeViewMode = ref.watch(episodeViewModeProvider);
    final mobileNavStyle = ref.watch(mobileNavStyleProvider);
    final layoutMode = ref.watch(layoutModeProvider);
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final currentLanguage = ref.watch(appLanguageProvider);

    return PixelSubpageScaffold(
      title: l10n.appearanceAndDisplay,
      isEmbedded: isEmbedded,
      children: [
        // ─── IDIOMA DE LA INTERFAZ ──────────────────────────────
        SettingsSectionHeader(title: l10n.appLanguage),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: InkWell(
            onTap: () => _showAppLanguageDialog(context, ref, l10n, currentLanguage),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appLanguageDesc,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentLanguage == AppLanguage.en ? 'English' : 'Español',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── IDIOMA PREFERIDO DE TÍTULOS ──────────────────────────
        SettingsSectionHeader(title: l10n.preferredTitleLanguage),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: InkWell(
            onTap: () => _showTitleLanguageDialog(context, ref, l10n, titleLang),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  Icons.subtitles_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.preferredTitleLanguageDesc,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        titleLang.label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── TIPOGRAFÍA DE LA APLICACIÓN ──────────────────────────
        SettingsSectionHeader(title: l10n.fontStyle),
        const SizedBox(height: 10),
        Builder(
          builder: (context) {
            final currentFont = kAvailableFonts.firstWhere(
              (f) => f.id == fontId,
              orElse: () => kAvailableFonts.first,
            );
            return PixelCardContainer(
              child: InkWell(
                onTap: () => _showFontFamilyDialog(context, ref, l10n, fontId),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.font_download_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.fontStyleDesc,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentFont.displayName,
                            style: currentFont.textStyleBuilder != null
                                ? currentFont.textStyleBuilder!(
                                    textStyle: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                : TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // ─── ESQUINAS Y BORDES DE LA APP ──────────────────────────
        SettingsSectionHeader(title: 'Esquinas y Bordes (Radio de Tarjetas)'),
        const SizedBox(height: 10),
        _PersonalizacionRadiusSection(),
        const SizedBox(height: 24),

        // ─── MODO DE VISTA DE EPISODIOS ───────────────────────────
        SettingsSectionHeader(title: l10n.episodeDisplay),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: InkWell(
            onTap: () => _showEpisodeDisplayDialog(context, ref, l10n, episodeViewMode),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  episodeViewMode == EpisodeViewMode.list
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.episodeDisplayDesc,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        episodeViewMode == EpisodeViewMode.list
                            ? l10n.detailedList
                            : l10n.grid,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── ESTILO DE BARRA MÓVIL ────────────────────────────────
        SettingsSectionHeader(title: l10n.mobileNavStyle),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: InkWell(
            onTap: () => _showMobileNavStyleDialog(context, ref, l10n, mobileNavStyle),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  mobileNavStyle == MobileNavStyle.classic
                      ? Icons.dock_rounded
                      : Icons.view_sidebar_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mobileNavStyleDesc,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mobileNavStyle.localizedLabel(l10n),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── MODO DE INTERFAZ Y PANTALLA ──────────────────────────
        SettingsSectionHeader(title: 'Modo de Interfaz (Adaptativo)'),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: InkWell(
            onTap: () => _showLayoutModeDialog(context, ref, layoutMode),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  layoutMode == LayoutMode.desktop
                      ? Icons.desktop_windows_rounded
                      : layoutMode == LayoutMode.tv
                          ? Icons.tv_rounded
                          : layoutMode == LayoutMode.mobile
                              ? Icons.smartphone_rounded
                              : Icons.devices_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diseño adaptado para tu dispositivo',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        layoutMode.label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── PUNTUACIONES EN PORTADAS ─────────────────────────────
        SettingsSectionHeader(title: l10n.showScores),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: Icons.star_outline_rounded,
              title: l10n.showScores,
              subtitle: l10n.showScoresDesc,
              value: ref.watch(showScoresProvider),
              onChanged: (val) =>
                  ref.read(showScoresProvider.notifier).setShowScores(val),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── BARRA FLOTANTE: SIGUE DONDE TE QUEDASTE ───────────────
        SettingsSectionHeader(title: l10n.floatingResumeBar),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: Icons.history_toggle_off_rounded,
              title: l10n.floatingResumeBar,
              subtitle: l10n.floatingResumeBarDesc,
              value: ref.watch(resumeBarEnabledProvider),
              onChanged: (val) =>
                  ref.read(resumeBarEnabledProvider.notifier).setEnabled(val),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── DESPLAZAMIENTO (ESCRITORIO / PC) ─────────────────────
        SettingsSectionHeader(title: l10n.desktopScrollbar),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: Icons.mouse_rounded,
              title: l10n.desktopScrollbar,
              subtitle: l10n.desktopScrollbarDesc,
              value: ref.watch(desktopScrollbarProvider),
              onChanged: (val) =>
                  ref.read(desktopScrollbarProvider.notifier).setEnabled(val),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGOS FLOTANTES PARA SELECCIÓN DE IDIOMA Y FUENTE
// ─────────────────────────────────────────────────────────────────────────────

/// Muestra un diálogo con las opciones de barra de navegación en móvil
void _showMobileNavStyleDialog(
  BuildContext context,
  WidgetRef ref,
  AppTranslations l10n,
  MobileNavStyle currentStyle,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.mobileNavStyle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: MobileNavStyle.values.map((style) {
              final isSelected = style == currentStyle;
              final icon = style == MobileNavStyle.classic
                  ? Icons.dock_rounded
                  : Icons.view_sidebar_rounded;

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  style.localizedLabel(l10n),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.35),
                  size: 22,
                ),
                onTap: () {
                  ref.read(mobileNavStyleProvider.notifier).setStyle(style);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

/// Muestra un diálogo flotante con las opciones de idioma de la app (English / Español)
void _showAppLanguageDialog(
  BuildContext context,
  WidgetRef ref,
  AppTranslations l10n,
  AppLanguage currentLanguage,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.appLanguage,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values.map((lang) {
              final isSelected = lang == currentLanguage;
              final label = lang == AppLanguage.en ? 'English' : 'Español';
              final icon = lang == AppLanguage.en
                  ? Icons.translate_rounded
                  : Icons.language_rounded;

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.35),
                  size: 22,
                ),
                onTap: () {
                  ref.read(appLanguageProvider.notifier).setLanguage(lang);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

/// Muestra un diálogo flotante con las opciones de idioma de títulos (Romaji, Inglés, Nativo)
void _showTitleLanguageDialog(
  BuildContext context,
  WidgetRef ref,
  AppTranslations l10n,
  TitleLanguage currentLang,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.preferredTitleLanguage,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: TitleLanguage.values.map((lang) {
              final isSelected = lang == currentLang;

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  lang.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  lang.example,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.35),
                  size: 22,
                ),
                onTap: () {
                  ref.read(titleLanguageProvider.notifier).setLanguage(lang);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

/// Muestra un diálogo flotante con las opciones de fuente de la app
void _showFontFamilyDialog(
  BuildContext context,
  WidgetRef ref,
  AppTranslations l10n,
  String currentFontId,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.fontStyle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: kAvailableFonts.map((font) {
                final isSelected = font.id == currentFontId;
                final titleStyle = font.textStyleBuilder != null
                    ? font.textStyleBuilder!(
                        textStyle: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      )
                    : TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      );

                final subtitleStyle = font.textStyleBuilder != null
                    ? font.textStyleBuilder!(
                        textStyle: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      );

                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    font.displayName,
                    style: titleStyle,
                  ),
                  subtitle: Text(
                    '${font.description} • Aa Bb 123',
                    style: subtitleStyle,
                  ),
                  trailing: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.35),
                    size: 22,
                  ),
                  onTap: () {
                    ref.read(themeProvider.notifier).setFontFamily(font.id);
                    Navigator.of(ctx).pop();
                  },
                );
              }).toList(),
            ),
          ),
        ),
      );
    },
  );
}

/// Muestra un diálogo flotante para elegir el modo de visualización de episodios (Lista / Cuadrícula)
void _showEpisodeDisplayDialog(
  BuildContext context,
  WidgetRef ref,
  AppTranslations l10n,
  EpisodeViewMode currentMode,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final options = [
        (
          mode: EpisodeViewMode.list,
          label: l10n.detailedList,
          icon: Icons.view_list_rounded,
          subtitle: 'Muestra miniaturas grandes con título y sinopsis',
        ),
        (
          mode: EpisodeViewMode.grid,
          label: l10n.grid,
          icon: Icons.grid_view_rounded,
          subtitle: 'Cuadrícula compacta y numerada de episodios',
        ),
      ];

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.episodeDisplay,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final isSelected = opt.mode == currentMode;

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(
                  opt.icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  opt.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  opt.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.35),
                  size: 22,
                ),
                onTap: () {
                  ref.read(episodeViewModeProvider.notifier).setMode(opt.mode);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

class _PersonalizacionRadiusSection extends ConsumerStatefulWidget {
  const _PersonalizacionRadiusSection();

  @override
  ConsumerState<_PersonalizacionRadiusSection> createState() => _PersonalizacionRadiusSectionState();
}

class _PersonalizacionRadiusSectionState extends ConsumerState<_PersonalizacionRadiusSection> {
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
    final theme = Theme.of(context);

    // Keep synchronized if updated from elsewhere
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
                  Icon(
                    Icons.rounded_corner_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Radio de bordes',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ajusta la redondez de tarjetas y componentes',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_localRadius.round()} px',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 24.0,
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
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
                _buildRadiusChip('0 px (Cuadrado)', 0.0, _localRadius, theme),
                const SizedBox(width: 6),
                _buildRadiusChip('6 px (Sutil)', 6.0, _localRadius, theme),
                const SizedBox(width: 6),
                _buildRadiusChip('10 px (Normal)', 10.0, _localRadius, theme),
                const SizedBox(width: 6),
                _buildRadiusChip('16 px (Redondo)', 16.0, _localRadius, theme),
                const SizedBox(width: 6),
                _buildRadiusChip('22 px (Curvo)', 22.0, _localRadius, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusChip(String label, double value, double currentRadius, ThemeData theme) {
    final isSelected = (currentRadius.round() == value.round());
    return InkWell(
      onTap: () => _onChipSelected(value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.25),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Muestra un diálogo flotante con las opciones de modo de interfaz (Auto, Escritorio, Móvil, TV)
void _showLayoutModeDialog(
  BuildContext context,
  WidgetRef ref,
  LayoutMode currentMode,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Modo de Interfaz',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: LayoutMode.values.map((mode) {
              final isSelected = mode == currentMode;
              final icon = switch (mode) {
                LayoutMode.auto => Icons.devices_rounded,
                LayoutMode.desktop => Icons.desktop_windows_rounded,
                LayoutMode.mobile => Icons.smartphone_rounded,
                LayoutMode.tv => Icons.tv_rounded,
              };
              final subtitle = switch (mode) {
                LayoutMode.auto => 'Detección automática por tamaño de pantalla',
                LayoutMode.desktop => 'Diseño completo en 2 columnas con barra hero',
                LayoutMode.mobile => 'Diseño vertical compacto para teléfonos',
                LayoutMode.tv => 'Interfaz simplificada a 10 pies para control remoto y D-Pad',
              };

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : null),
                title: Text(
                  mode.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.35),
                  size: 22,
                ),
                onTap: () {
                  ref.read(layoutModeProvider.notifier).setMode(mode);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

