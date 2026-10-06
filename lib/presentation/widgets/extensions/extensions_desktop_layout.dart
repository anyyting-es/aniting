import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/presentation/widgets/extensions/installed_tab_view.dart';
import 'package:seanime_app/presentation/widgets/extensions/marketplace_tab_view.dart';

/// Modern Seanime-style desktop layout for the Extensions Marketplace.
///
/// Features:
/// - Safe 42dp desktop top clearance below the custom titlebar.
/// - Centered segmented pill switcher ([Installed] / [Marketplace]) with live badges.
/// - Sleek desktop header with repo source, action buttons, category filters, and search.
/// - Responsive 3-to-4 column desktop card grid matching the Seanime desktop interface.
class ExtensionsDesktopLayout extends ConsumerStatefulWidget {
  final List<ExtensionItem> installedExtensions;
  final List<ExtensionItem> marketplaceExtensions;
  final Set<String> installedIds;
  final String? installingExtensionId;
  final bool isLoadingInstalled;
  final bool isLoadingMarketplace;
  final bool isCheckingUpdates;
  final String? installedError;
  final String? marketplaceError;
  final String currentRepoUrl;
  final VoidCallback onRetryInstalled;
  final VoidCallback onCheckForUpdates;
  final VoidCallback onReloadAll;
  final void Function(ExtensionItem, bool) onToggle;
  final void Function(ExtensionItem) onUninstall;
  final void Function(ExtensionItem) onUpdate;
  final void Function(ExtensionItem) onShowCode;
  final Future<void> Function({bool forceRefresh}) onRefreshMarketplace;
  final VoidCallback onChangeRepo;
  final void Function(ExtensionItem) onInstall;

  const ExtensionsDesktopLayout({
    super.key,
    required this.installedExtensions,
    required this.marketplaceExtensions,
    required this.installedIds,
    this.installingExtensionId,
    required this.isLoadingInstalled,
    required this.isLoadingMarketplace,
    required this.isCheckingUpdates,
    this.installedError,
    this.marketplaceError,
    required this.currentRepoUrl,
    required this.onRetryInstalled,
    required this.onCheckForUpdates,
    required this.onReloadAll,
    required this.onToggle,
    required this.onUninstall,
    required this.onUpdate,
    required this.onShowCode,
    required this.onRefreshMarketplace,
    required this.onChangeRepo,
    required this.onInstall,
  });

  @override
  ConsumerState<ExtensionsDesktopLayout> createState() => _ExtensionsDesktopLayoutState();
}

class _ExtensionsDesktopLayoutState extends ConsumerState<ExtensionsDesktopLayout> {
  int _activeTab = 1; // 0 = Installed, 1 = Marketplace (default to Marketplace on desktop)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Column(
            children: [
              // ─── 1. TOP BAR: Back Navigation + Centered Segmented Pill ───
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 42, 36, 12),
                child: Row(
                  children: [
                    // Back button (if screen is pushed)
                    if (canPop) ...[
                      IconButton(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          hoverColor: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : theme.colorScheme.surfaceContainerHighest,
                          highlightColor: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : theme.colorScheme.surfaceContainerHigh,
                        ),
                        icon: Icon(
                          AppIcons.arrowLeft(iconPack),
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          size: 22,
                        ),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                    ],

                    Text(
                      l10n.extensionsTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const Spacer(),

                    // Centered Segmented Pill Switcher ([Installed] [Marketplace])
                    Container(
                      height: 40,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSegmentPill(
                            icon: Icons.layers_outlined,
                            label: '${l10n.installed} (${widget.installedExtensions.length})',
                            isSelected: _activeTab == 0,
                            onTap: () => setState(() => _activeTab = 0),
                            theme: theme,
                          ),
                          _buildSegmentPill(
                            icon: Icons.storefront_outlined,
                            label: l10n.marketplace,
                            isSelected: _activeTab == 1,
                            onTap: () => setState(() => _activeTab = 1),
                            theme: theme,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Balancer spacer matching back button width
                    if (canPop) const SizedBox(width: 48),
                  ],
                ),
              ),

              // ─── 2. CONTENT AREA ───
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: KeyedSubtree(
                    key: ValueKey(_activeTab),
                    child: _activeTab == 0
                        ? InstalledTabView(
                            isLoading: widget.isLoadingInstalled,
                            error: widget.installedError,
                            installedExtensions: widget.installedExtensions,
                            installingExtensionId: widget.installingExtensionId,
                            isCheckingUpdates: widget.isCheckingUpdates,
                            onRetry: widget.onRetryInstalled,
                            onCheckForUpdates: widget.onCheckForUpdates,
                            onReloadAll: widget.onReloadAll,
                            onToggle: widget.onToggle,
                            onUninstall: widget.onUninstall,
                            onUpdate: widget.onUpdate,
                            onShowCode: widget.onShowCode,
                            onGoToMarketplace: () => setState(() => _activeTab = 1),
                          )
                        : MarketplaceTabView(
                            isLoading: widget.isLoadingMarketplace,
                            error: widget.marketplaceError,
                            extensions: widget.marketplaceExtensions,
                            installedIds: widget.installedIds,
                            installingExtensionId: widget.installingExtensionId,
                            currentRepoUrl: widget.currentRepoUrl,
                            onRefresh: widget.onRefreshMarketplace,
                            onChangeRepo: widget.onChangeRepo,
                            onInstall: widget.onInstall,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentPill({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
