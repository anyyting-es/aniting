import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/presentation/widgets/extensions/extension_category_view.dart';

class ExtensionsDesktopLayout extends ConsumerStatefulWidget {
  final List<ExtensionItem> onlineExtensions;
  final List<ExtensionItem> torrentExtensions;
  final List<ExtensionItem> mangaExtensions;
  final Set<String> installedIds;
  final Map<String, ExtensionItem> installedMap;
  final String? installingExtensionId;
  final bool isCheckingUpdates;
  final VoidCallback onCheckForUpdates;
  final VoidCallback onReloadAll;
  final ValueChanged<ExtensionItem> onInstall;
  final void Function(ExtensionItem ext, bool disable) onToggle;
  final ValueChanged<ExtensionItem> onUninstall;
  final ValueChanged<ExtensionItem> onUpdate;
  final ValueChanged<ExtensionItem> onShowCode;
  final VoidCallback onRefresh;

  const ExtensionsDesktopLayout({
    super.key,
    required this.onlineExtensions,
    required this.torrentExtensions,
    required this.mangaExtensions,
    required this.installedIds,
    required this.installedMap,
    this.installingExtensionId,
    required this.isCheckingUpdates,
    required this.onCheckForUpdates,
    required this.onReloadAll,
    required this.onInstall,
    required this.onToggle,
    required this.onUninstall,
    required this.onUpdate,
    required this.onShowCode,
    required this.onRefresh,
  });

  @override
  ConsumerState<ExtensionsDesktopLayout> createState() => _ExtensionsDesktopLayoutState();
}

class _ExtensionsDesktopLayoutState extends ConsumerState<ExtensionsDesktopLayout> {
  int _activeCategory = 0; // 0 = Online, 1 = Torrents, 2 = Manga

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final canPop = Navigator.canPop(context);

    final currentExtensions = switch (_activeCategory) {
      0 => widget.onlineExtensions,
      1 => widget.torrentExtensions,
      2 => widget.mangaExtensions,
      _ => widget.onlineExtensions,
    };

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            children: [
              // ─── 1. Desktop Top Bar: Navigation + Category Switcher + Actions ───
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 42, 32, 16),
                child: Row(
                  children: [
                    if (canPop) ...[
                      IconButton(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          hoverColor: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : theme.colorScheme.surfaceContainerHighest,
                        ),
                        icon: Icon(
                          AppIcons.arrowLeft(iconPack),
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          size: 20,
                        ),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
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

                    // Centered Segmented Control ([Online] [Torrents] [Manga])
                    Container(
                      height: 42,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCategoryPill(
                            icon: Icons.play_circle_filled_rounded,
                            label: l10n.onlineStreamingTab,
                            index: 0,
                            theme: theme,
                          ),
                          _buildCategoryPill(
                            icon: Icons.cloud_download_rounded,
                            label: l10n.animeTorrents,
                            index: 1,
                            theme: theme,
                          ),
                          _buildCategoryPill(
                            icon: Icons.menu_book_rounded,
                            label: l10n.manga,
                            index: 2,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Action buttons: Check updates & Reload
                    IconButton(
                      icon: widget.isCheckingUpdates
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_alt_rounded, size: 20),
                      tooltip: l10n.checkUpdates,
                      onPressed: widget.isCheckingUpdates ? null : widget.onCheckForUpdates,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: l10n.extensionsReloadSuccess,
                      onPressed: widget.onReloadAll,
                    ),

                    if (canPop) const SizedBox(width: 40),
                  ],
                ),
              ),

              // ─── 2. Category Content View ───
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_activeCategory),
                    child: ExtensionCategoryView(
                      extensions: currentExtensions,
                      installedIds: widget.installedIds,
                      installedMap: widget.installedMap,
                      installingExtensionId: widget.installingExtensionId,
                      isUpdating: widget.isCheckingUpdates,
                      onInstall: widget.onInstall,
                      onToggle: widget.onToggle,
                      onUninstall: widget.onUninstall,
                      onUpdate: widget.onUpdate,
                      onShowCode: widget.onShowCode,
                      onRefresh: widget.onRefresh,
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

  Widget _buildCategoryPill({
    required IconData icon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isSelected = _activeCategory == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _activeCategory = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.onSurface
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
