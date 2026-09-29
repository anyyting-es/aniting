import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final prefs = ref.watch(mangaReaderPreferencesProvider);
    final notifier = ref.read(mangaReaderPreferencesProvider.notifier);

    return PixelSubpageScaffold(
      title: 'Lector de Manga',
      isEmbedded: isEmbedded,
      children: [
        // ─── MODO DE LECTURA ──────────────────────────────
        const SettingsSectionHeader(title: 'MODO DE LECTURA'),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<MangaReadingMode>(
              style: pixelSegmentedButtonStyle(theme),
              segments: const [
                ButtonSegment(
                  value: MangaReadingMode.webtoon,
                  label: Text('Deslizar'),
                  icon: Icon(Icons.swap_vert_rounded),
                ),
                ButtonSegment(
                  value: MangaReadingMode.pagedLtr,
                  label: Text('Izq. a Der.'),
                  icon: Icon(Icons.arrow_forward_rounded),
                ),
                ButtonSegment(
                  value: MangaReadingMode.pagedRtl,
                  label: Text('Der. a Izq.'),
                  icon: Icon(Icons.arrow_back_rounded),
                ),
              ],
              selected: {prefs.readingMode},
              onSelectionChanged: (set) => notifier.setReadingMode(set.first),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── BARRA DE ESTADO DEL SISTEMA ───────────────────
        const SettingsSectionHeader(title: 'BARRA DE ESTADO'),
        const SizedBox(height: 10),
        PixelCardContainer(
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<MangaStatusBarMode>(
              style: pixelSegmentedButtonStyle(theme),
              segments: const [
                ButtonSegment(
                  value: MangaStatusBarMode.smart,
                  label: Text('Inteligente'),
                  icon: Icon(Icons.auto_awesome_rounded),
                ),
                ButtonSegment(
                  value: MangaStatusBarMode.hidden,
                  label: Text('Ocultar'),
                  icon: Icon(Icons.fullscreen_rounded),
                ),
                ButtonSegment(
                  value: MangaStatusBarMode.visible,
                  label: Text('Mostrar'),
                  icon: Icon(Icons.fullscreen_exit_rounded),
                ),
              ],
              selected: {prefs.statusBarMode},
              onSelectionChanged: (set) => notifier.setStatusBarMode(set.first),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── GESTOS Y CONFORT ─────────────────────────────
        const SettingsSectionHeader(title: 'GESTOS Y VISUALIZACIÓN'),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            PixelSwitchTile(
              icon: Icons.touch_app_rounded,
              title: 'Tocar para pasar página',
              value: prefs.tapToTurnEnabled,
              onChanged: (v) => notifier.setTapToTurnEnabled(v),
            ),
            const PixelTileDivider(),
            PixelSwitchTile(
              icon: Icons.gradient_rounded,
              title: 'Sombra en bordes',
              value: prefs.subtleShadowEnabled,
              onChanged: (v) => notifier.setSubtleShadowEnabled(v),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── ALMACENAMIENTO Y DESCARGAS OFFLINE ───────────
        const SettingsSectionHeader(title: 'DESCARGAS Y ALMACENAMIENTO'),
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
                          Icons.folder_zip_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Directorio de Descargas',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Aniting/Downloads/Manga (Independiente del directorio de trabajo/caché)',
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
                          : 'Cargando ruta...',
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
