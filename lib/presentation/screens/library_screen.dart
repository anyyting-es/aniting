import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/downloads_screen.dart';
import 'package:seanime_app/presentation/screens/my_lists_screen.dart';
import 'package:seanime_app/presentation/screens/settings/settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/theme_settings_screen.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';
import 'package:seanime_app/presentation/widgets/anilist_auth_sheet.dart';
import 'package:seanime_app/presentation/widgets/top_status_bar_glass.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSettings;

  const LibraryScreen({super.key, this.onOpenSettings});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = _scrollController.hasClients && _scrollController.offset > 10;
    if (scrolled != _isScrolledNotifier.value) {
      _isScrolledNotifier.value = scrolled;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _isScrolledNotifier.dispose();
    super.dispose();
  }

  Future<void> _triggerScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    final repo = ref.read(repositoryProvider);
    final l10n = ref.read(translationsProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final ok = await repo.scanLibrary();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.scanStarted : l10n.scanFailed),
          duration: const Duration(seconds: 2),
        ),
      );
      if (ok) {
        ref.invalidate(animeCollectionProvider);
      }
    } catch (_) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.scanFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _navigateToSettings() {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
    } else {
      Navigator.push(
        context,
        SlideRightToLeftPageRoute(child: const SettingsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final serverState = ref.watch(serverNotifierProvider);
    final collectionAsync = ref.watch(animeCollectionProvider);
    final mangaAsync = ref.watch(mangaCollectionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;
    final topPadding = MediaQuery.of(context).padding.top;

    final allEntries = collectionAsync.value ?? [];
    final mangaEntries = mangaAsync.value ?? [];

    int watchingCount = 0, completedCount = 0, planningCount = 0, droppedCount = 0, pausedCount = 0;
    for (final e in allEntries) {
      switch (e.status) {
        case 'CURRENT' || 'WATCHING':
          watchingCount++;
        case 'COMPLETED':
          completedCount++;
        case 'PLANNING':
          planningCount++;
        case 'DROPPED':
          droppedCount++;
        case 'PAUSED':
          pausedCount++;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(animeCollectionProvider);
              ref.invalidate(mangaCollectionProvider);
            },
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 100),
                  children: [
                // 1. Profile Header & Stats Card
                _buildProfileCard(
                  context,
                  theme: theme,
                  isDark: isDark,
                  isLoggedIn: isLoggedIn,
                  serverState: serverState,
                  l10n: l10n,
                  iconPack: iconPack,
                  watchingCount: watchingCount,
                  completedCount: completedCount,
                  planningCount: planningCount,
                  droppedCount: droppedCount,
                  pausedCount: pausedCount,
                  totalAnime: allEntries.length,
                  totalManga: mangaEntries.length,
                ),

                const SizedBox(height: 20),

                // 2. Section: Colección y Navegación Principal
                _buildSectionHeader('Mi Colección'),
                const SizedBox(height: 4),

                _buildNavigationTile(
                  context,
                  theme: theme,
                  icon: AppIcons.bookmarks(iconPack),
                  iconPack: iconPack,
                  title: l10n.myLists,
                  onTap: () {
                    Navigator.push(
                      context,
                      SlideRightToLeftPageRoute(child: const MyListsScreen()),
                    );
                  },
                ),

                _buildNavigationTile(
                  context,
                  theme: theme,
                  icon: AppIcons.downloadOffline(iconPack),
                  iconPack: iconPack,
                  title: l10n.animeDownloads,
                  onTap: () {
                    Navigator.push(
                      context,
                      SlideRightToLeftPageRoute(child: const DownloadsScreen(initialTabIndex: 0)),
                    );
                  },
                ),

                _buildNavigationTile(
                  context,
                  theme: theme,
                  icon: AppIcons.manga(iconPack),
                  iconPack: iconPack,
                  title: l10n.mangaDownloads,
                  onTap: () {
                    Navigator.push(
                      context,
                      SlideRightToLeftPageRoute(child: const DownloadsScreen(initialTabIndex: 1)),
                    );
                  },
                ),

                _buildNavigationTile(
                  context,
                  theme: theme,
                  icon: AppIcons.extension(iconPack),
                  iconPack: iconPack,
                  title: l10n.extensionsTitle,
                  onTap: () {
                    Navigator.push(
                      context,
                      SlideRightToLeftPageRoute(child: const ExtensionsMarketplaceScreen()),
                    );
                  },
                ),

                _buildNavigationTile(
                  context,
                  theme: theme,
                  icon: AppIcons.settings(iconPack),
                  iconPack: iconPack,
                  title: l10n.settingsTitle,
                  onTap: _navigateToSettings,
                ),

                const SizedBox(height: 20),

                // 3. Section: Configuraciones Rápidas
                _buildSectionHeader(l10n.quickSettings),
                const SizedBox(height: 4),

                _buildQuickSettingsCard(
                  context,
                  theme: theme,
                  iconPack: iconPack,
                  l10n: l10n,
                  isDark: isDark,
                  serverState: serverState,
                ),
              ],
            ),
          ),
        ),
      ),

          // Pinned smooth status bar vignette overlay on scroll
          ValueListenableBuilder<bool>(
            valueListenable: _isScrolledNotifier,
            builder: (context, isScrolled, child) {
              return TopStatusBarGlass(isVisible: isScrolled);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required ThemeData theme,
    required bool isDark,
    required bool isLoggedIn,
    required dynamic serverState,
    required dynamic l10n,
    required int watchingCount,
    required int completedCount,
    required int planningCount,
    required int droppedCount,
    required int pausedCount,
    required int totalAnime,
    required int totalManga,
    required AppIconPack iconPack,
  }) {
    final avatarUrl = serverState.status?.avatarUrl;
    final username = isLoggedIn
        ? (serverState.status?.username ?? l10n.user)
        : 'Usuario Local';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar (Tap to open AniList Auth)
              GestureDetector(
                onTap: () => AnilistAuthSheet.show(context),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Icon(AppIcons.profile(iconPack), color: theme.colorScheme.onSurfaceVariant, size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isLoggedIn) ...[
                      const SizedBox(height: 2),
                      Text(
                        'AniList Conectado',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stats Counters Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCounter(
                theme,
                label: l10n.statusWatching,
                count: watchingCount,
              ),
              _buildStatCounter(
                theme,
                label: l10n.statusCompleted,
                count: completedCount,
              ),
              _buildStatCounter(
                theme,
                label: l10n.statusPlanning,
                count: planningCount,
              ),
              _buildStatCounter(
                theme,
                label: l10n.statusDropped,
                count: droppedCount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCounter(
    ThemeData theme, {
    required String label,
    required int count,
  }) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationTile(
    BuildContext context, {
    required ThemeData theme,
    required IconData icon,
    required AppIconPack iconPack,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSettingsCard(
    BuildContext context, {
    required ThemeData theme,
    required dynamic l10n,
    required bool isDark,
    required dynamic serverState,
    required AppIconPack iconPack,
  }) {
    return Column(
      children: [
        // Sincronizar Biblioteca Local
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              _isScanning
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(AppIcons.sync(iconPack), color: theme.colorScheme.onSurfaceVariant, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.scanLocalFolder,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              OutlinedButton(
                onPressed: _isScanning ? null : _triggerScan,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Escanear'),
              ),
            ],
          ),
        ),

        // Cambiar Tema Rápido (sin flechita)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                SlideRightToLeftPageRoute(child: const ThemeSettingsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  Icon(AppIcons.palette(iconPack), color: theme.colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.themeAndColors,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Estado del Servidor
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(
                serverState.isOnline ? AppIcons.server(iconPack) : AppIcons.serverOff(iconPack),
                color: serverState.isOnline ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  serverState.isOnline ? l10n.serverConnected : l10n.serverNotConnected,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: serverState.isOnline ? const Color(0xFF4CAF50) : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 12, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          fontSize: 13.5,
        ),
      ),
    );
  }
}
