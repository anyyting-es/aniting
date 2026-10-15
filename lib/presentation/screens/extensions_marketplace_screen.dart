import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';
import 'package:seanime_app/presentation/widgets/extensions/extension_category_view.dart';
import 'package:seanime_app/presentation/widgets/extensions/extension_code_modal.dart';
import 'package:seanime_app/presentation/widgets/extensions/extensions_desktop_layout.dart';

class ExtensionsMarketplaceScreen extends ConsumerStatefulWidget {
  const ExtensionsMarketplaceScreen({super.key});

  @override
  ConsumerState<ExtensionsMarketplaceScreen> createState() => _ExtensionsMarketplaceScreenState();
}

class _ExtensionsMarketplaceScreenState extends ConsumerState<ExtensionsMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  static const String defaultRepoUrl =
      'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/marketplace.json';

  static const ExtensionItem _defaultUniversalExtension = ExtensionItem(
    id: 'aniting-universal',
    name: 'Aniting Universal',
    version: '1.0.0',
    author: 'Aniting',
    description:
        'Proveedor nativo oficial: Transmisiones 1080p HLS, Multi-Audio (Latino, Castellano, Japonés, Inglés) y Multi-Subtítulos integrados.',
    type: 'onlinestream-provider',
    language: 'dart',
    lang: 'multi',
    icon: 'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/icons/icon.png',
    manifestUri: '',
    payloadUri: '',
  );

  static const ExtensionItem _defaultKawaiiExtension = ExtensionItem(
    id: 'kawaii-animes',
    name: 'Kawaii Animes',
    version: '1.0.0',
    author: 'Aniting / Kawaii',
    description:
        'Proveedor nativo oficial: Audio Latino, Audio Castellano y Subtitulado en español con servidores de alta velocidad.',
    type: 'onlinestream-provider',
    language: 'dart',
    lang: 'es',
    icon: 'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/icons/icon.png',
    manifestUri: '',
    payloadUri: '',
  );

  static const ExtensionItem _defaultJkAnimeExtension = ExtensionItem(
    id: 'jkanime',
    name: 'JKAnime',
    version: '1.0.0',
    author: 'Aniting / JKAnime',
    description:
        'Proveedor nativo oficial: Catálogo completo de anime subtitulado al español con múltiples servidores (StreamWish, VOE).',
    type: 'onlinestream-provider',
    language: 'dart',
    lang: 'es',
    icon: 'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/icons/icon.png',
    manifestUri: '',
    payloadUri: '',
  );

  static const ExtensionItem _defaultAnimeToshoExtension = ExtensionItem(
    id: 'animetosho-new',
    name: 'AnimeTosho (NEW)',
    version: '2.5.1',
    author: 'Faddix, Island',
    description:
        'Proveedor de torrents oficial para Anime Tosho (búsquedas inteligentes, lotes y episodios individuales).',
    type: 'anime-torrent-provider',
    language: 'typescript',
    lang: 'multi',
    icon: 'https://raw.githubusercontent.com/faddix/seanime-animetosho-new/main/src/animetosho-new-logo.png',
    manifestUri:
        'https://raw.githubusercontent.com/faddix/seanime-animetosho-new/main/animetosho-new.json',
    payloadUri:
        'https://raw.githubusercontent.com/faddix/seanime-animetosho-new/main/animetosho-new.ts',
  );

  static const ExtensionItem _defaultMangaDexExtension = ExtensionItem(
    id: 'mangadex',
    name: 'MangaDex',
    version: '1.0.0',
    author: 'kiko',
    description:
        'Proveedor oficial de manga para leer mangas y cómics en múltiples idiomas desde MangaDex.',
    type: 'manga-provider',
    language: 'typescript',
    lang: 'multi',
    icon: 'https://raw.githubusercontent.com/5rahim/hibike/main/icons/mangadex.png',
    manifestUri:
        'https://raw.githubusercontent.com/HyperKiko/seanime-extensions/main/src/mangadex/mangadex.json',
    payloadUri:
        'https://raw.githubusercontent.com/HyperKiko/seanime-extensions/main/src/mangadex/mangadex.ts',
  );

  late final TabController _tabController;

  List<ExtensionItem> _installedExtensions = [];
  bool _isLoadingInstalled = true;

  List<ExtensionItem> _marketplaceExtensions = [];
  bool _isLoadingMarketplace = true;

  String? _installingExtensionId;
  bool _isCheckingUpdates = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadInstalledExtensions(),
      _loadMarketplaceExtensions(),
    ]);
  }

  Future<void> _loadInstalledExtensions() async {
    if (!mounted) return;
    setState(() => _isLoadingInstalled = true);

    final repo = ref.read(repositoryProvider);
    try {
      final list = await repo.getAllExtensions();
      if (mounted) {
        setState(() {
          _installedExtensions = list;
          _isLoadingInstalled = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInstalled = false);
    }
  }

  Future<void> _loadMarketplaceExtensions({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoadingMarketplace = true);

    final repo = ref.read(repositoryProvider);
    try {
      final list = await repo.getMarketplaceExtensions(defaultRepoUrl, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _marketplaceExtensions = list.where((ext) => ext.type.toLowerCase() != 'plugin').toList();
          _isLoadingMarketplace = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMarketplace = false);
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _installExtension(ExtensionItem ext) async {
    final l10n = ref.read(translationsProvider);

    if (ext.manifestUri.isEmpty) {
      _showFeedback(l10n.invalidManifestUrl, isError: true);
      return;
    }

    setState(() => _installingExtensionId = ext.id);
    final repo = ref.read(repositoryProvider);
    final success = await repo.installExtension(ext.manifestUri);

    if (mounted) {
      setState(() => _installingExtensionId = null);
      if (success) {
        _showFeedback('${ext.name} ${l10n.extensionInstalledSuccessfully}');
        _loadInstalledExtensions();
      } else {
        _showFeedback('${ext.name}: ${l10n.extensionInstallFailed}', isError: true);
      }
    }
  }

  Future<void> _toggleExtension(ExtensionItem ext, bool disable) async {
    final repo = ref.read(repositoryProvider);
    final success = await repo.setExtensionDisabled(ext.id, disable);
    if (success) {
      _loadInstalledExtensions();
    } else if (mounted) {
      _showFeedback('Error (${ext.name})', isError: true);
    }
  }

  Future<void> _uninstallExtension(ExtensionItem ext) async {
    final l10n = ref.read(translationsProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.extensionUninstallTitle),
        content: Text('${l10n.extensionUninstallConfirm} "${ext.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.uninstall),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(repositoryProvider);
      final success = await repo.uninstallExtension(ext.id);
      if (mounted && success) {
        _showFeedback('${ext.name} ${l10n.extensionUninstalled}');
        _loadInstalledExtensions();
      }
    }
  }

  Future<void> _updateExtension(ExtensionItem ext) async {
    final l10n = ref.read(translationsProvider);
    if (ext.manifestUri.isEmpty) {
      _showFeedback(l10n.invalidManifestUrl, isError: true);
      return;
    }

    setState(() => _installingExtensionId = ext.id);
    final repo = ref.read(repositoryProvider);
    _showFeedback('${l10n.extensionUpdating} ${ext.name}...');

    final success = await repo.installExtension(ext.manifestUri);
    if (mounted) {
      setState(() => _installingExtensionId = null);
      _showFeedback(
        success ? '${ext.name} ${l10n.extensionUpdateSuccess}' : '${ext.name}: ${l10n.extensionUpdateFailed}',
        isError: !success,
      );
      _loadInstalledExtensions();
    }
  }

  Future<void> _reloadAllExtensions() async {
    final l10n = ref.read(translationsProvider);
    final repo = ref.read(repositoryProvider);
    final success = await repo.reloadExtensions();
    if (mounted) {
      _showFeedback(
        success ? l10n.extensionsReloadSuccess : l10n.extensionsReloadFailed,
        isError: !success,
      );
      _loadAll();
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdates) return;
    setState(() => _isCheckingUpdates = true);

    await _loadInstalledExtensions();

    if (mounted) {
      final l10n = ref.read(translationsProvider);
      setState(() => _isCheckingUpdates = false);
      final updatesCount = _installedExtensions.where((e) => e.hasUpdate).length;
      _showFeedback(
        updatesCount > 0
            ? '$updatesCount ${l10n.availableUpdatesCount}'
            : l10n.allExtensionsUpToDateLong,
      );
    }
  }

  void _showExtensionCodeModal(ExtensionItem ext) {
    ExtensionCodeModal.show(
      context,
      extension: ext,
      repository: ref.read(repositoryProvider),
    );
  }

  List<ExtensionItem> _getCategoryExtensions(int categoryIndex) {
    final seenIds = <String>{};
    final result = <ExtensionItem>[];

    // Priority to marketplace items, then installed items
    final allCandidates = <ExtensionItem>[
      ..._marketplaceExtensions,
      ..._installedExtensions,
    ];

    for (final ext in allCandidates) {
      final id = ext.id.toLowerCase();
      if (seenIds.contains(id)) continue;

      if (categoryIndex == 0) {
        // Online: Native providers
        if (id == 'aniting-universal' || id == 'kawaii-animes' || id == 'jkanime') {
          seenIds.add(id);
          result.add(ext);
        }
      } else if (categoryIndex == 1) {
        // Torrents
        if (ext.type == 'anime-torrent-provider') {
          seenIds.add(id);
          result.add(ext);
        }
      } else if (categoryIndex == 2) {
        // Manga
        if (ext.type == 'manga-provider') {
          seenIds.add(id);
          result.add(ext);
        }
      }
    }

    // Default fallbacks to guarantee rich experience
    if (categoryIndex == 0) {
      if (!seenIds.contains('aniting-universal')) result.add(_defaultUniversalExtension);
      if (!seenIds.contains('kawaii-animes')) result.add(_defaultKawaiiExtension);
      if (!seenIds.contains('jkanime')) result.add(_defaultJkAnimeExtension);
    } else if (categoryIndex == 1 && result.isEmpty) {
      result.add(_defaultAnimeToshoExtension);
    } else if (categoryIndex == 2 && result.isEmpty) {
      result.add(_defaultMangaDexExtension);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    final installedIds = {
      ..._installedExtensions.map((e) => e.id.toLowerCase()),
      'aniting-universal',
      'kawaii-animes',
      'jkanime',
      'animetosho-new',
      'mangadex',
    };
    final installedMap = {
      for (final ext in _installedExtensions) ext.id.toLowerCase(): ext,
      'aniting-universal': _defaultUniversalExtension,
      'kawaii-animes': _defaultKawaiiExtension,
      'jkanime': _defaultJkAnimeExtension,
      'animetosho-new': _defaultAnimeToshoExtension,
      'mangadex': _defaultMangaDexExtension,
    };

    final onlineExtensions = _getCategoryExtensions(0);
    final torrentExtensions = _getCategoryExtensions(1);
    final mangaExtensions = _getCategoryExtensions(2);

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final isLoading = (_isLoadingInstalled || _isLoadingMarketplace) &&
        _installedExtensions.isEmpty &&
        _marketplaceExtensions.isEmpty;

    if (isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: DesktopSafeAppBar(
          child: AppBar(
            title: Text(l10n.extensionsTitle),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (isDesktop) {
      return ExtensionsDesktopLayout(
        onlineExtensions: onlineExtensions,
        torrentExtensions: torrentExtensions,
        mangaExtensions: mangaExtensions,
        installedIds: installedIds,
        installedMap: installedMap,
        installingExtensionId: _installingExtensionId,
        isCheckingUpdates: _isCheckingUpdates,
        onCheckForUpdates: _checkForUpdates,
        onReloadAll: _reloadAllExtensions,
        onInstall: _installExtension,
        onToggle: _toggleExtension,
        onUninstall: _uninstallExtension,
        onUpdate: _updateExtension,
        onShowCode: _showExtensionCodeModal,
        onRefresh: _loadAll,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: DesktopSafeAppBar(
        child: AppBar(
          title: Text(l10n.extensionsTitle),
          actions: [
            IconButton(
              icon: _isCheckingUpdates
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt_rounded),
              tooltip: l10n.checkUpdates,
              onPressed: _isCheckingUpdates ? null : _checkForUpdates,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: l10n.extensionsReloadSuccess,
              onPressed: _reloadAllExtensions,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(
                icon: const Icon(Icons.play_circle_filled_rounded, size: 20),
                text: l10n.onlineStreamingTab,
              ),
              Tab(
                icon: const Icon(Icons.cloud_download_rounded, size: 20),
                text: l10n.animeTorrents,
              ),
              Tab(
                icon: const Icon(Icons.menu_book_rounded, size: 20),
                text: l10n.manga,
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const ClampingScrollPhysics(),
        children: [
          ExtensionCategoryView(
            extensions: onlineExtensions,
            installedIds: installedIds,
            installedMap: installedMap,
            installingExtensionId: _installingExtensionId,
            isUpdating: _isCheckingUpdates,
            onInstall: _installExtension,
            onToggle: _toggleExtension,
            onUninstall: _uninstallExtension,
            onUpdate: _updateExtension,
            onShowCode: _showExtensionCodeModal,
            onRefresh: _loadAll,
          ),
          ExtensionCategoryView(
            extensions: torrentExtensions,
            installedIds: installedIds,
            installedMap: installedMap,
            installingExtensionId: _installingExtensionId,
            isUpdating: _isCheckingUpdates,
            onInstall: _installExtension,
            onToggle: _toggleExtension,
            onUninstall: _uninstallExtension,
            onUpdate: _updateExtension,
            onShowCode: _showExtensionCodeModal,
            onRefresh: _loadAll,
          ),
          ExtensionCategoryView(
            extensions: mangaExtensions,
            installedIds: installedIds,
            installedMap: installedMap,
            installingExtensionId: _installingExtensionId,
            isUpdating: _isCheckingUpdates,
            onInstall: _installExtension,
            onToggle: _toggleExtension,
            onUninstall: _uninstallExtension,
            onUpdate: _updateExtension,
            onShowCode: _showExtensionCodeModal,
            onRefresh: _loadAll,
          ),
        ],
      ),
    );
  }
}
