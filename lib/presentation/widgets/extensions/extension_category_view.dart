import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/presentation/widgets/extensions/universal_extension_card.dart';

class ExtensionCategoryView extends ConsumerWidget {
  final List<ExtensionItem> extensions;
  final Set<String> installedIds;
  final Map<String, ExtensionItem> installedMap;
  final String? installingExtensionId;
  final bool isUpdating;
  final ValueChanged<ExtensionItem> onInstall;
  final void Function(ExtensionItem ext, bool disable) onToggle;
  final ValueChanged<ExtensionItem> onUninstall;
  final ValueChanged<ExtensionItem> onUpdate;
  final ValueChanged<ExtensionItem> onShowCode;
  final VoidCallback onRefresh;

  const ExtensionCategoryView({
    super.key,
    required this.extensions,
    required this.installedIds,
    required this.installedMap,
    this.installingExtensionId,
    this.isUpdating = false,
    required this.onInstall,
    required this.onToggle,
    required this.onUninstall,
    required this.onUpdate,
    required this.onShowCode,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    if (extensions.isEmpty) {
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
                l10n.noExtensionsFound,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noExtensionsFoundDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount;
    if (screenWidth >= 1200) {
      crossAxisCount = extensions.length == 1 ? 1 : 2;
    } else {
      crossAxisCount = 1;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: crossAxisCount == 1
                  ? Column(
                      children: extensions.map((ext) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildCard(ext),
                        );
                      }).toList(),
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: extensions.map((ext) {
                        return SizedBox(
                          width: (constraints.maxWidth.clamp(0.0, 1000.0) - 16) / 2,
                          child: _buildCard(ext),
                        );
                      }).toList(),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(ExtensionItem ext) {
    final lowerId = ext.id.toLowerCase();
    final isInstalled = installedIds.contains(lowerId);
    final activeExt = isInstalled && installedMap.containsKey(lowerId)
        ? installedMap[lowerId]!
        : ext;

    return UniversalExtensionCard(
      extension: activeExt,
      isInstalled: isInstalled,
      isInstalling: installingExtensionId == ext.id,
      isUpdating: isUpdating,
      onToggle: isInstalled ? (val) => onToggle(activeExt, !val) : null,
      onInstall: isInstalled ? null : () => onInstall(ext),
      onUninstall: isInstalled ? () => onUninstall(activeExt) : null,
      onUpdate: isInstalled ? () => onUpdate(activeExt) : null,
      onShowCode: () => onShowCode(activeExt),
    );
  }
}
