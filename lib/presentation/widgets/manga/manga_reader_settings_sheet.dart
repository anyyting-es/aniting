import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/manga_reader_preferences_provider.dart';

class MangaReaderSettingsSheet extends ConsumerWidget {
  const MangaReaderSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const MangaReaderSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(mangaReaderPreferencesProvider);
    final notifier = ref.read(mangaReaderPreferencesProvider.notifier);
    final iconPack = ref.watch(iconPackProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.manga(iconPack),
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Ajustes del Lector',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ─── 1. MODO DE LECTURA ──────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Modo de lectura',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<MangaReadingMode>(
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                segments: [
                  ButtonSegment(
                    value: MangaReadingMode.webtoon,
                    label: const Text('Deslizar'),
                    icon: Icon(AppIcons.swapVert(iconPack)),
                  ),
                  ButtonSegment(
                    value: MangaReadingMode.pagedLtr,
                    label: const Text('Izq. a Der.'),
                    icon: Icon(AppIcons.arrowRight(iconPack)),
                  ),
                  ButtonSegment(
                    value: MangaReadingMode.pagedRtl,
                    label: const Text('Der. a Izq.'),
                    icon: Icon(AppIcons.arrowLeft(iconPack)),
                  ),
                ],
                selected: {prefs.readingMode},
                onSelectionChanged: (set) => notifier.setReadingMode(set.first),
              ),
            ),

            const SizedBox(height: 18),

            // ─── 2. BARRA DE ESTADO DEL SISTEMA ───────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Barra de estado',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<MangaStatusBarMode>(
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                segments: [
                  ButtonSegment(
                    value: MangaStatusBarMode.smart,
                    label: const Text('Inteligente'),
                    icon: Icon(AppIcons.sparkles(iconPack)),
                  ),
                  ButtonSegment(
                    value: MangaStatusBarMode.hidden,
                    label: const Text('Ocultar'),
                    icon: Icon(AppIcons.fullscreen(iconPack)),
                  ),
                  ButtonSegment(
                    value: MangaStatusBarMode.visible,
                    label: const Text('Mostrar'),
                    icon: Icon(AppIcons.fullscreenExit(iconPack)),
                  ),
                ],
                selected: {prefs.statusBarMode},
                onSelectionChanged: (set) => notifier.setStatusBarMode(set.first),
              ),
            ),

            const SizedBox(height: 18),

            // ─── 3. OPCIONES ──────────────────────────────────────
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    secondary: Icon(
                      AppIcons.touchApp(iconPack),
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    title: const Text(
                      'Tocar para pasar página',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    value: prefs.tapToTurnEnabled,
                    onChanged: (v) => notifier.setTapToTurnEnabled(v),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    secondary: Icon(
                      AppIcons.gradient(iconPack),
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    title: const Text(
                      'Sombra en bordes',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    value: prefs.subtleShadowEnabled,
                    onChanged: (v) => notifier.setSubtleShadowEnabled(v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
