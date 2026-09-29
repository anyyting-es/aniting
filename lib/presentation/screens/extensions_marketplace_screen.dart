import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/extensions/extension_code_modal.dart';
import 'package:seanime_app/presentation/widgets/extensions/installed_tab_view.dart';
import 'package:seanime_app/presentation/widgets/extensions/marketplace_tab_view.dart';
import 'package:seanime_app/presentation/widgets/extensions/repo_config_dialog.dart';

class ExtensionsMarketplaceScreen extends ConsumerStatefulWidget {
  const ExtensionsMarketplaceScreen({super.key});

  @override
  ConsumerState<ExtensionsMarketplaceScreen> createState() => _ExtensionsMarketplaceScreenState();
}

class _ExtensionsMarketplaceScreenState extends ConsumerState<ExtensionsMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  static const String _prefRepoKey = 'seanime_marketplace_repo_url';
  static const String defaultRepoUrl =
      'https://raw.githubusercontent.com/Bas1874/Seanime-Marketplace/refs/heads/main/Marketplace/Main.json';

  late final TabController _tabController;

  List<ExtensionItem> _installedExtensions = [];
  bool _isLoadingInstalled = true;
  String? _installedError;

  List<ExtensionItem> _marketplaceExtensions = [];
  bool _isLoadingMarketplace = true;
  String? _marketplaceError;
  String _currentRepoUrl = defaultRepoUrl;

  String? _installingExtensionId;
  bool _isCheckingUpdates = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _loadRepoUrlAndFetch();
    _loadInstalledExtensions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRepoUrlAndFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefRepoKey);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _currentRepoUrl = savedUrl.trim();
      }
    } catch (_) {}
    _loadMarketplaceExtensions();
  }

  Future<void> _loadInstalledExtensions() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInstalled = true;
      _installedError = null;
    });

    final repo = ref.read(repositoryProvider);
    try {
      final list = await repo.getAllExtensions();
      if (mounted) {
        setState(() {
          _installedExtensions = list;
          _isLoadingInstalled = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _installedError = 'Error: $e';
          _isLoadingInstalled = false;
        });
      }
    }
  }

  Future<void> _loadMarketplaceExtensions({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingMarketplace = true;
      _marketplaceError = null;
    });

    final repo = ref.read(repositoryProvider);
    try {
      final list = await repo.getMarketplaceExtensions(_currentRepoUrl, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _marketplaceExtensions = list.where((ext) => ext.type.toLowerCase() != 'plugin').toList();
          _isLoadingMarketplace = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _marketplaceError = 'Error: $e';
          _isLoadingMarketplace = false;
        });
      }
    }
  }

  Future<void> _installExtension(ExtensionItem ext) async {
    final l10n = ref.read(translationsProvider);

    if (ext.type.toLowerCase() == 'plugin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pluginExtensionsNotSupported),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (ext.manifestUri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invalidManifestUrl),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _installingExtensionId = ext.id);
    final repo = ref.read(repositoryProvider);
    final success = await repo.installExtension(ext.manifestUri);

    if (mounted) {
      setState(() => _installingExtensionId = null);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ext.name} ${l10n.extensionInstalledSuccessfully}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadInstalledExtensions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ext.name}: ${l10n.extensionInstallFailed}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleExtension(ExtensionItem ext, bool disable) async {
    final repo = ref.read(repositoryProvider);
    final success = await repo.setExtensionDisabled(ext.id, disable);
    if (success) {
      _loadInstalledExtensions();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error (${ext.name})'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ext.name} ${l10n.extensionUninstalled}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadInstalledExtensions();
        }
      }
    }
  }

  Future<void> _updateExtension(ExtensionItem ext) async {
    final l10n = ref.read(translationsProvider);

    if (ext.manifestUri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invalidManifestUrl),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _installingExtensionId = ext.id);
    final repo = ref.read(repositoryProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.extensionUpdating} ${ext.name}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final success = await repo.installExtension(ext.manifestUri);
    if (mounted) {
      setState(() => _installingExtensionId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '${ext.name} ${l10n.extensionUpdateSuccess}' : '${ext.name}: ${l10n.extensionUpdateFailed}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadInstalledExtensions();
    }
  }

  Future<void> _reloadAllExtensions() async {
    final l10n = ref.read(translationsProvider);
    final repo = ref.read(repositoryProvider);
    final success = await repo.reloadExtensions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.extensionsReloadSuccess : l10n.extensionsReloadFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadInstalledExtensions();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatesCount > 0
                ? '$updatesCount ${l10n.availableUpdatesCount}!'
                : l10n.allExtensionsUpToDateLong,
          ),
          behavior: SnackBarBehavior.floating,
        ),
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

  void _showChangeRepoDialog() {
    MarketplaceRepoConfigDialog.show(
      context,
      currentRepoUrl: _currentRepoUrl,
      defaultRepoUrl: defaultRepoUrl,
      onSaveRepoUrl: (newUrl) async {
        setState(() => _currentRepoUrl = newUrl);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefRepoKey, newUrl);
        } catch (_) {}
        _loadMarketplaceExtensions();
      },
      onInstallManifest: (manifestUri) async {
        final repo = ref.read(repositoryProvider);
        final ok = await repo.installExtension(manifestUri);
        if (ok && mounted) {
          _loadInstalledExtensions();
        }
        return ok;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final installedIds = _installedExtensions.map((e) => e.id.toLowerCase()).toSet();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(l10n.extensionsTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.layers_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('${l10n.installed} (${_installedExtensions.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storefront_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.marketplace),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const ClampingScrollPhysics(),
        children: [
          InstalledTabView(
            isLoading: _isLoadingInstalled,
            error: _installedError,
            installedExtensions: _installedExtensions,
            installingExtensionId: _installingExtensionId,
            isCheckingUpdates: _isCheckingUpdates,
            onRetry: _loadInstalledExtensions,
            onCheckForUpdates: _checkForUpdates,
            onReloadAll: _reloadAllExtensions,
            onToggle: _toggleExtension,
            onUninstall: _uninstallExtension,
            onUpdate: _updateExtension,
            onShowCode: _showExtensionCodeModal,
            onGoToMarketplace: () => _tabController.animateTo(1),
          ),
          MarketplaceTabView(
            isLoading: _isLoadingMarketplace,
            error: _marketplaceError,
            extensions: _marketplaceExtensions,
            installedIds: installedIds,
            installingExtensionId: _installingExtensionId,
            currentRepoUrl: _currentRepoUrl,
            onRefresh: _loadMarketplaceExtensions,
            onChangeRepo: _showChangeRepoDialog,
            onInstall: _installExtension,
          ),
        ],
      ),
    );
  }
}
