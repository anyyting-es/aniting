import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/presentation/widgets/extensions/installed_extension_card.dart';

class InstalledTabView extends ConsumerWidget {
  final bool isLoading;
  final String? error;
  final List<ExtensionItem> installedExtensions;
  final String? installingExtensionId;
  final bool isCheckingUpdates;
  final VoidCallback onRetry;
  final VoidCallback onCheckForUpdates;
  final VoidCallback onReloadAll;
  final void Function(ExtensionItem, bool) onToggle;
  final void Function(ExtensionItem) onUninstall;
  final void Function(ExtensionItem) onUpdate;
  final void Function(ExtensionItem) onShowCode;
  final VoidCallback onGoToMarketplace;

  const InstalledTabView({
    super.key,
    required this.isLoading,
    this.error,
    required this.installedExtensions,
    this.installingExtensionId,
    required this.isCheckingUpdates,
    required this.onRetry,
    required this.onCheckForUpdates,
    required this.onReloadAll,
    required this.onToggle,
    required this.onUninstall,
    required this.onUpdate,
    required this.onShowCode,
    required this.onGoToMarketplace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (installedExtensions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.extension_off_rounded,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noInstalledExtensions,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.noInstalledExtensionsDesc,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onGoToMarketplace,
                icon: const Icon(Icons.storefront_rounded),
                label: Text(l10n.exploreMarketplace),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 650;
        final isCompact = constraints.maxWidth < 520;

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCompact) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.installed} (${installedExtensions.length})',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${installedExtensions.length} ${l10n.installed.toLowerCase()}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isCheckingUpdates ? null : onCheckForUpdates,
                      icon: isCheckingUpdates
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.system_update_alt_rounded, size: 16),
                      label: Text(
                        l10n.checkForUpdates,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReloadAll,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        l10n.reloadAll,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.installed} (${installedExtensions.length})',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${installedExtensions.length} ${l10n.installed.toLowerCase()}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isCheckingUpdates ? null : onCheckForUpdates,
                    icon: isCheckingUpdates
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.system_update_alt_rounded, size: 16),
                    label: Text(l10n.checkForUpdates),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onReloadAll,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.reloadAll),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        );

        if (isDesktop) {
          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                sliver: SliverToBoxAdapter(child: header),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 440,
                    mainAxisExtent: 172,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: installedExtensions.length,
                  itemBuilder: (context, index) {
                    final ext = installedExtensions[index];
                    return InstalledExtensionCard(
                      extension: ext,
                      isUpdating: installingExtensionId == ext.id,
                      onToggle: (val) => onToggle(ext, !val),
                      onUninstall: () => onUninstall(ext),
                      onUpdate: () => onUpdate(ext),
                      onShowCode: () => onShowCode(ext),
                    );
                  },
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: installedExtensions.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return header;
            final ext = installedExtensions[index - 1];
            return InstalledExtensionCard(
              extension: ext,
              isUpdating: installingExtensionId == ext.id,
              onToggle: (val) => onToggle(ext, !val),
              onUninstall: () => onUninstall(ext),
              onUpdate: () => onUpdate(ext),
              onShowCode: () => onShowCode(ext),
            );
          },
        );
      },
    );
  }
}
