import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';

class InstalledExtensionCard extends ConsumerWidget {
  final ExtensionItem extension;
  final bool isUpdating;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUninstall;
  final VoidCallback onUpdate;
  final VoidCallback onShowCode;

  const InstalledExtensionCard({
    super.key,
    required this.extension,
    required this.isUpdating,
    required this.onToggle,
    required this.onUninstall,
    required this.onUpdate,
    required this.onShowCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final ext = extension;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Icon, Name + Type Badge, and Switch toggle
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ext.typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ext.icon != null && ext.icon!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ext.icon!,
                            fit: BoxFit.cover,
                            memCacheWidth: 80,
                            memCacheHeight: 80,
                            maxWidthDiskCache: 120,
                            maxHeightDiskCache: 120,
                            fadeInDuration: const Duration(milliseconds: 150),
                            placeholder: (context, url) => Container(
                              color: ext.typeColor.withValues(alpha: 0.1),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              ext.typeIcon,
                              color: ext.typeColor,
                              size: 20,
                            ),
                          )
                        : Icon(ext.typeIcon, color: ext.typeColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            ext.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ext.typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ext.typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: ext.typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: !ext.disabled,
                      activeThumbColor: theme.colorScheme.primary,
                      onChanged: onToggle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Description
              Text(
                ext.description.isNotEmpty ? ext.description : l10n.noDescriptionAvailable,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Row 3: Version & author on the left, action buttons on the right
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          'v${ext.version}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '• ${l10n.byAuthor} ${ext.author}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ext.hasUpdate)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              l10n.updateAvailable,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (ext.hasUpdate) ...[
                    FilledButton.tonalIcon(
                      onPressed: isUpdating ? null : onUpdate,
                      icon: isUpdating
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upgrade_rounded, size: 14),
                      label: Text(l10n.update, style: const TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    tooltip: l10n.viewSourceCode,
                    icon: const Icon(Icons.code_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: onShowCode,
                  ),
                  if (!ext.isBuiltin) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: l10n.uninstall,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: onUninstall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
