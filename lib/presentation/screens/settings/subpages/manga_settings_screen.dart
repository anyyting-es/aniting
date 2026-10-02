import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/download_preferences_provider.dart';
import 'package:seanime_app/core/preferences/manga_reader_preferences_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA: AJUSTES DEL LECTOR DE MANGA (GLOBAL)
// ─────────────────────────────────────────────────────────────────────────────
class MangaSettingsScreen extends ConsumerWidget {
  final bool isEmbedded;
  const MangaSettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final prefs = ref.watch(mangaReaderPreferencesProvider);
    final notifier = ref.read(mangaReaderPreferencesProvider.notifier);

    return PixelSubpageScaffold(
      title: l10n.mangaReader,
      isEmbedded: isEmbedded,
      children: [
        // ─── MODO DE LECTURA ──────────────────────────────
        SettingsSectionHeader(title: l10n.mangaReadingModeSection),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<MangaReadingMode>(
              style: pixelSegmentedButtonStyle(theme),
              segments: [
                ButtonSegment(
                  value: MangaReadingMode.webtoon,
                  label: Text(MangaReadingMode.webtoon.localizedName(l10n)),
                  icon: Icon(AppIcons.swapVert(iconPack)),
                ),
                ButtonSegment(
                  value: MangaReadingMode.pagedLtr,
                  label: Text(MangaReadingMode.pagedLtr.localizedName(l10n)),
                  icon: Icon(AppIcons.arrowRight(iconPack)),
                ),
                ButtonSegment(
                  value: MangaReadingMode.pagedRtl,
                  label: Text(MangaReadingMode.pagedRtl.localizedName(l10n)),
                  icon: Icon(AppIcons.arrowLeft(iconPack)),
                ),
              ],
              selected: {prefs.readingMode},
              onSelectionChanged: (set) => notifier.setReadingMode(set.first),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── BARRA DE ESTADO DEL SISTEMA ───────────────────
        SettingsSectionHeader(title: l10n.mangaStatusBarSection),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<MangaStatusBarMode>(
              style: pixelSegmentedButtonStyle(theme),
              segments: [
                ButtonSegment(
                  value: MangaStatusBarMode.smart,
                  label: Text(MangaStatusBarMode.smart.localizedName(l10n)),
                  icon: Icon(AppIcons.sparkles(iconPack)),
                ),
                ButtonSegment(
                  value: MangaStatusBarMode.hidden,
                  label: Text(MangaStatusBarMode.hidden.localizedName(l10n)),
                  icon: Icon(AppIcons.fullscreen(iconPack)),
                ),
                ButtonSegment(
                  value: MangaStatusBarMode.visible,
                  label: Text(MangaStatusBarMode.visible.localizedName(l10n)),
                  icon: Icon(AppIcons.fullscreenExit(iconPack)),
                ),
              ],
              selected: {prefs.statusBarMode},
              onSelectionChanged: (set) => notifier.setStatusBarMode(set.first),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── GESTOS Y CONFORT ─────────────────────────────
        SettingsSectionHeader(title: l10n.mangaGesturesSection),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: AppIcons.touchApp(iconPack),
              title: l10n.mangaTapToTurn,
              value: prefs.tapToTurnEnabled,
              onChanged: (v) => notifier.setTapToTurnEnabled(v),
            ),
            const PixelTileDivider(),
            PixelSwitchTile(
              icon: AppIcons.gradient(iconPack),
              title: l10n.mangaSubtleShadow,
              value: prefs.subtleShadowEnabled,
              onChanged: (v) => notifier.setSubtleShadowEnabled(v),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── ALMACENAMIENTO Y DESCARGAS OFFLINE ───────────
        SettingsSectionHeader(title: l10n.mangaDownloadsSection),
        const SizedBox(height: 10),
        Consumer(
          builder: (context, ref, _) {
            final downloadPrefs = ref.watch(downloadPreferencesProvider);
            return PixelCardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          AppIcons.download(iconPack),
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.mangaDownloadDir,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.mangaDownloadDirDesc,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      downloadPrefs.resolvedBasePath.isNotEmpty
                          ? '${downloadPrefs.resolvedBasePath}/Manga'
                          : l10n.loadingPath,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
