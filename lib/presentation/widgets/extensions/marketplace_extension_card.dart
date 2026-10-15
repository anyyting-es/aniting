import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';

class MarketplaceExtensionCard extends ConsumerWidget {
  final ExtensionItem extension;
  final bool isInstalled;
  final bool isInstalling;
  final VoidCallback onInstall;

  const MarketplaceExtensionCard({
    super.key,
    required this.extension,
    required this.isInstalled,
    required this.isInstalling,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final ext = extension;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Icon + Title/ID + Download Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon 42x42
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ext.typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: ext.icon != null && ext.icon!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: ext.icon!,
                        fit: BoxFit.cover,
                        memCacheWidth: 84,
                        memCacheHeight: 84,
                        maxWidthDiskCache: 120,
                        maxHeightDiskCache: 120,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (context, url) => Container(
                          color: ext.typeColor.withValues(alpha: 0.1),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          ext.typeIcon,
                          color: ext.typeColor,
                          size: 22,
                        ),
                      )
                    : Icon(ext.typeIcon, color: ext.typeColor, size: 22),
              ),
              const SizedBox(width: 10),

              // Title & ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ext.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ext.id,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Download / Installed action button
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: isInstalling
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isInstalled
                        ? Tooltip(
                            message: l10n.installedCardLabel,
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: '${l10n.install} ${ext.name}',
                            icon: const Icon(
                              Icons.file_download_outlined,
                              size: 18,
                            ),
                            onPressed: onInstall,
                          ),
              ),
            ],
          ),

          // Middle: Description
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              ext.description.isNotEmpty ? ext.description : l10n.noDescriptionAvailable,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Bottom: Badges (Version, Author, Language, Type)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Version badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  ext.version,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // Author badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  ext.author,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Language badge (if specific)
              if (ext.lang.isNotEmpty && ext.lang.toLowerCase() != 'multi')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    ext.lang.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.lightBlueAccent,
                    ),
                  ),
                ),

              // Code language (e.g. Typescript, Javascript)
              if (ext.language.isNotEmpty)
                Text(
                  ext.language[0].toUpperCase() + ext.language.substring(1),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
