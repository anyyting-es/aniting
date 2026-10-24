import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/providers/local_library_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/local_library/local_library_paths_card.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/local_library/local_library_scanner_card.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/local_library/local_library_shows_section.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/local_library/local_library_stats_card.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/local_library/local_library_unmatched_section.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';

class LocalLibrarySettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const LocalLibrarySettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<LocalLibrarySettingsScreen> createState() =>
      _LocalLibrarySettingsScreenState();
}

class _LocalLibrarySettingsScreenState
    extends ConsumerState<LocalLibrarySettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresco en segundo plano solo si los datos están viejos: si el usuario
    // entra y sale de la página, se reutiliza el estado ya cargado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(localLibraryProvider.notifier).refreshIfStale();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final state = ref.watch(localLibraryProvider);

    return PixelSubpageScaffold(
      title: l10n.localLibrarySettingsTitle,
      isEmbedded: widget.isEmbedded,
      children: [
        // ─── 1. BANNER INFORMATIVO ───────────────────────────────
        PixelInfoBanner(
          icon: Icons.info_outline_rounded,
          text: l10n.localLibrarySettingsDesc,
        ),
        const SizedBox(height: 16),

        // ─── 2. ESTADÍSTICAS Y RESUMEN ───────────────────────────
        SettingsSectionHeader(title: l10n.libraryStatsSection),
        const SizedBox(height: 8),
        LocalLibraryStatsCard(state: state),
        const SizedBox(height: 20),

        // ─── 3. ESCÁNER DE ARCHIVOS ──────────────────────────────
        SettingsSectionHeader(title: l10n.scanLibrarySection),
        const SizedBox(height: 8),
        LocalLibraryScannerCard(state: state),
        const SizedBox(height: 20),

        // ─── 4. GESTIÓN DE CARPETAS Y RUTAS ──────────────────────
        SettingsSectionHeader(title: l10n.libraryFoldersSection),
        const SizedBox(height: 8),
        LocalLibraryPathsCard(state: state),
        const SizedBox(height: 20),

        // ─── 5. SHOWS Y CONTENIDO IDENTIFICADO ───────────────────
        SettingsSectionHeader(title: l10n.localShowsSectionTitle),
        const SizedBox(height: 8),
        LocalLibraryShowsSection(state: state),
        const SizedBox(height: 20),

        // ─── 6. ARCHIVOS PENDIENTES / RESOLVER MATCH ─────────────
        SettingsSectionHeader(title: l10n.resolveUnmatchedTitle),
        const SizedBox(height: 8),
        LocalLibraryUnmatchedSection(state: state),
        const SizedBox(height: 24),
      ],
    );
  }
}
