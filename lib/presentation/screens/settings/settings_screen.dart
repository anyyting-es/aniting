import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/settings_sidebar_width_provider.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/download_manager_screen.dart';
import 'package:seanime_app/presentation/screens/downloads_screen.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/about_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/manga_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/personalizacion_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/player_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/server_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/streaming_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/theme_settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/welcome_screen.dart';
import 'package:seanime_app/presentation/widgets/anilist_auth_sheet.dart';

enum SettingsCategory {
  theme,
  appearance,
  extensions,
  player,
  manga,
  streaming,
  downloadManager,
  downloads,
  server,
  about,
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA PRINCIPAL: AJUSTES (ADAPTATIVA: SINGLE / DUAL-PANE ANDROID 16)
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsCategory _selectedCategory = SettingsCategory.theme;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
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
      case SettingsCategory.downloadManager:
        return const DownloadManagerScreen(isEmbedded: true);
      case SettingsCategory.downloads:
        return const DownloadsScreen(isEmbedded: true);
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
        case SettingsCategory.downloadManager:
          page = const DownloadManagerScreen();
          break;
        case SettingsCategory.downloads:
          page = const DownloadsScreen();
          break;
        case SettingsCategory.server:
          page = const ServerSettingsScreen();
          break;
        case SettingsCategory.about:
          page = const AboutSettingsScreen();
          break;
      }
      Navigator.of(context).push(SlideRightToLeftPageRoute(child: page));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serverState = ref.watch(serverNotifierProvider);
    final status = serverState.status;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 720;

        final settingsListView = ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // ─── 1. BARRA DE BÚSQUEDA SUELTA ──────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 16, top: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                decoration: InputDecoration(
                  hintText: l10n.searchSettingsHint,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 14.5,
                  ),
                  prefixIcon: Icon(AppIcons.search(iconPack), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(AppIcons.close(iconPack), size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // ─── 2. PERFIL / ANILIST (SUELTO) ─────────────────────────
            InkWell(
              onTap: () => AnilistAuthSheet.show(context),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: status?.avatarUrl != null
                          ? NetworkImage(status!.avatarUrl!)
                          : null,
                      child: status?.avatarUrl == null
                          ? (status?.isLoggedIn == true && status?.username != null && status!.username!.isNotEmpty
                              ? Text(
                                  status.username![0].toUpperCase(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : Icon(
                                  AppIcons.profile(iconPack),
                                  color: theme.colorScheme.onPrimaryContainer,
                                  size: 20,
                                ))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        status?.isLoggedIn == true
                            ? (status?.username ?? 'AniList')
                            : 'AniList',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight(iconPack),
                      size: 19,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── 3. PREFERENCIAS DE CONTENIDO Y MULTIMEDIA ─────
            SettingsSectionHeader(title: l10n.preferences),
            const SizedBox(height: 4),

            SettingsTile(
              icon: AppIcons.palette(iconPack),
              title: l10n.themeAndColors,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.theme,
              onTap: () => _onSelectCategory(SettingsCategory.theme, isWideScreen),
            ),
            SettingsTile(
              icon: AppIcons.appearance(iconPack),
              title: l10n.appearanceAndDisplay,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.appearance,
              onTap: () => _onSelectCategory(SettingsCategory.appearance, isWideScreen),
            ),
            SettingsTile(
              icon: AppIcons.extension(iconPack),
              title: l10n.extensionsTitle,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.extensions,
              onTap: () => _onSelectCategory(SettingsCategory.extensions, isWideScreen),
            ),
            SettingsTile(
              icon: AppIcons.playCircle(iconPack),
              title: l10n.videoPlayer,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.player,
              onTap: () => _onSelectCategory(SettingsCategory.player, isWideScreen),
            ),
            SettingsTile(
              icon: AppIcons.manga(iconPack),
              title: l10n.mangaReader,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.manga,
              onTap: () => _onSelectCategory(SettingsCategory.manga, isWideScreen),
            ),
            SettingsTile(
              icon: AppIcons.stream(iconPack),
              title: l10n.streamingSources,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.streaming,
              onTap: () => _onSelectCategory(SettingsCategory.streaming, isWideScreen),
            ),
            SettingsTile(
              icon: Icons.manage_history_rounded,
              title: l10n.downloadManager,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.downloadManager,
              onTap: () => _onSelectCategory(SettingsCategory.downloadManager, isWideScreen),
            ),
            SettingsTile(
              icon: AppIcons.downloadOffline(iconPack),
              title: l10n.downloads,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.downloads,
              onTap: () => _onSelectCategory(SettingsCategory.downloads, isWideScreen),
            ),

            const SizedBox(height: 20),

            // ─── 4. SISTEMA Y SERVIDOR ─────────────────────────────
            SettingsSectionHeader(title: l10n.system),
            const SizedBox(height: 4),

            SettingsTile(
              icon: AppIcons.server(iconPack),
              title: l10n.serverAndNetwork,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.server,
              onTap: () => _onSelectCategory(SettingsCategory.server, isWideScreen),
            ),

            const SizedBox(height: 20),

            // ─── 5. INFORMACIÓN ────────────────────────────────
            SettingsSectionHeader(title: l10n.info),
            const SizedBox(height: 4),

            SettingsTile(
              icon: AppIcons.info(iconPack),
              title: l10n.aboutApp,
              isSelected: isWideScreen && _selectedCategory == SettingsCategory.about,
              onTap: () => _onSelectCategory(SettingsCategory.about, isWideScreen),
            ),
            SettingsTile(
              icon: AppIcons.wavingHand(iconPack),
              title: l10n.welcomeDevPreview,
              isSelected: false,
              onTap: () {
                Navigator.of(context).push(
                  SlideRightToLeftPageRoute(
                    child: const WelcomeScreen(isDevPreview: true),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        );

        if (isWideScreen) {
          final sidebarWidth = ref.watch(settingsSidebarWidthProvider);

          // ─── MODO PANTALLA EXTENDIDA (DUAL-PANE MASTER-DETAIL) ─────
          return Scaffold(
            body: Row(
              children: [
                // Panel Izquierdo (Menú de opciones de Ajustes redimensionable y persistente)
                SizedBox(
                  width: sidebarWidth,
                  child: Scaffold(
                    appBar: AppBar(
                      titleSpacing: (ModalRoute.of(context)?.canPop ?? false) ? 0 : 16,
                      title: Text(
                        l10n.settingsTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    body: settingsListView,
                  ),
                ),

                // Separador vertical interactivo / redimensionable
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      ref
                          .read(settingsSidebarWidthProvider.notifier)
                          .setWidth(sidebarWidth + details.delta.dx);
                    },
                    child: Container(
                      width: 10,
                      color: Colors.transparent,
                      child: Center(
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),
                ),

                // Panel Derecho (Contenido de la subpantalla seleccionada)
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slideAnimation = Tween<Offset>(
                          begin: const Offset(0.04, 0.0),
                          end: Offset.zero,
                        ).animate(animation);

                        return SlideTransition(
                          position: slideAnimation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_selectedCategory),
                        child: _buildDetailView(_selectedCategory),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ─── MODO MÓVIL (PANTALLA ÚNICA CON NAVEGACIÓN PUSH) ─────────
        return Scaffold(
          appBar: AppBar(
            titleSpacing: (ModalRoute.of(context)?.canPop ?? false) ? 0 : 16,
            title: Text(
              l10n.settingsTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: settingsListView,
        );
      },
    );
  }
}
