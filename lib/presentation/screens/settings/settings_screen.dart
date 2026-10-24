import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/settings_sidebar_width_provider.dart';
import 'package:seanime_app/core/preferences/tv_mode_provider.dart';
import 'package:seanime_app/presentation/screens/download_manager_screen.dart';
import 'package:seanime_app/presentation/screens/downloads_screen.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/about_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/debrid_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/local_library_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/manga_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/personalizacion_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/player_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/server_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/streaming_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/theme_settings_screen.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';

import 'widgets/expressive/expressive_settings_detail_panel.dart';
import 'widgets/expressive/expressive_settings_sidebar.dart';
/// Ancho máximo del fondo angosto de detalle (isla flotante).
const double _kDetailPanelMaxWidth = 820;

enum SettingsCategory {
  theme,
  appearance,
  extensions,
  player,
  manga,
  streaming,
  debrid,
  downloadManager,
  downloads,
  localLibrary,
  server,
  about,
}

/// Expressive Dual-Floating-Island Settings Screen.
/// Designed for modern Wayland / desktop setups with compositor blur and floating islands.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsCategory _selectedCategory = SettingsCategory.theme;
  final FocusScopeNode _detailFocusScope = FocusScopeNode(
    debugLabel: 'settings-detail',
  );
  final GlobalKey<ExpressiveSettingsSidebarState> _sidebarKey =
      GlobalKey<ExpressiveSettingsSidebarState>();

  @override
  void dispose() {
    _detailFocusScope.dispose();
    super.dispose();
  }

  Widget _buildDetailView(SettingsCategory category) {
    switch (category) {
      case SettingsCategory.theme:
        return const ThemeSettingsScreen(isEmbedded: true);
      case SettingsCategory.appearance:
        return const PersonalizacionSettingsScreen(isEmbedded: true);
      case SettingsCategory.extensions:
        return const ExtensionsMarketplaceScreen();
      case SettingsCategory.player:
        return const PlayerSettingsScreen(isEmbedded: true);
      case SettingsCategory.manga:
        return const MangaSettingsScreen(isEmbedded: true);
      case SettingsCategory.streaming:
        return const StreamingSettingsScreen(isEmbedded: true);
      case SettingsCategory.debrid:
        return const DebridSettingsScreen(isEmbedded: true);
      case SettingsCategory.downloadManager:
        return const DownloadManagerScreen(isEmbedded: true);
      case SettingsCategory.downloads:
        return const DownloadsScreen(isEmbedded: true);
      case SettingsCategory.localLibrary:
        return const LocalLibrarySettingsScreen(isEmbedded: true);
      case SettingsCategory.server:
        return const ServerSettingsScreen(isEmbedded: true);
      case SettingsCategory.about:
        return const AboutSettingsScreen(isEmbedded: true);
    }
  }

  void _onSelectCategory(SettingsCategory category, bool isWideScreen) {
    if (isWideScreen) {
      setState(() => _selectedCategory = category);
    } else {
      Widget page;
      switch (category) {
        case SettingsCategory.theme:
          page = const ThemeSettingsScreen();
          break;
        case SettingsCategory.appearance:
          page = const PersonalizacionSettingsScreen();
          break;
        case SettingsCategory.extensions:
          page = const ExtensionsMarketplaceScreen();
          break;
        case SettingsCategory.player:
          page = const PlayerSettingsScreen();
          break;
        case SettingsCategory.manga:
          page = const MangaSettingsScreen();
          break;
        case SettingsCategory.streaming:
          page = const StreamingSettingsScreen();
          break;
        case SettingsCategory.debrid:
          page = const DebridSettingsScreen();
          break;
        case SettingsCategory.downloadManager:
          page = const DownloadManagerScreen();
          break;
        case SettingsCategory.downloads:
          page = const DownloadsScreen();
          break;
        case SettingsCategory.localLibrary:
          page = const LocalLibrarySettingsScreen();
          break;
        case SettingsCategory.server:
          page = const ServerSettingsScreen();
          break;
        case SettingsCategory.about:
          page = const AboutSettingsScreen();
          break;
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconPack = ref.watch(iconPackProvider);
    final isTv = ref.watch(tvModeProvider);
    final l10n = ref.watch(translationsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 780 || isTv;

        if (isWideScreen) {
          final sidebarWidth = ref.watch(settingsSidebarWidthProvider);

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: DesktopSafeAppBar(
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: 48,
                titleSpacing: 0,
                automaticallyImplyLeading: false,
                leading: Navigator.canPop(context)
                    ? IconButton(
                        icon: Icon(
                          AppIcons.arrowLeft(iconPack),
                          color: colorScheme.onSurface,
                          size: 20,
                        ),
                        tooltip: l10n.back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : null,
                title: Text(
                  l10n.settingsTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── 1. PANEL IZQUIERDO FLOTANTE (CATEGORÍAS) ───
                  SizedBox(
                    width: sidebarWidth.clamp(320.0, 480.0),
                    child: ExpressiveSettingsSidebar(
                      key: _sidebarKey,
                      selectedCategory: _selectedCategory,
                      onSelectCategory: (cat) => _onSelectCategory(cat, true),
                      detailFocusScope: _detailFocusScope,
                    ),
                  ),

                  // ─── SEPARADOR / REDIMENSIONADOR INTERACTIVO ──────────────
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        ref
                            .read(settingsSidebarWidthProvider.notifier)
                            .setWidth(sidebarWidth + details.delta.dx);
                      },
                      child: const SizedBox(width: 16),
                    ),
                  ),

                  // ─── 2. PANEL DERECHO FLOTANTE (DETALLE / OPCIONES) ─────────
                  // Mantiene el fondo angosto (isla delimitada y centrada)
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _kDetailPanelMaxWidth,
                        ),
                        child: SizedBox.expand(
                          child: ExpressiveSettingsDetailPanel(
                            selectedCategory: _selectedCategory,
                            detailViewBuilder: _buildDetailView,
                            focusScopeNode: _detailFocusScope,
                            onExitToSidebar: () =>
                                _sidebarKey.currentState?.focusSelectedRow(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // ─── MODO MÓVIL (PANTALLA ÚNICA CON NAVEGACIÓN PUSH) ─────────
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: DesktopSafeAppBar(
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 48,
              titleSpacing: 0,
              automaticallyImplyLeading: false,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: Icon(
                        AppIcons.arrowLeft(iconPack),
                        color: colorScheme.onSurface,
                        size: 20,
                      ),
                      tooltip: l10n.back,
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null,
              title: Text(
                l10n.settingsTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: ExpressiveSettingsSidebar(
              selectedCategory: null,
              showChevron: true,
              onSelectCategory: (cat) => _onSelectCategory(cat, false),
            ),
          ),
        );
      },
    );
  }
}
