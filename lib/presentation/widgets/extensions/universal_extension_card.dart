import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/extension_item.dart';

class UniversalExtensionCard extends ConsumerWidget {
  final ExtensionItem extension;
  final bool isInstalled;
  final bool isInstalling;
  final bool isUpdating;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onInstall;
  final VoidCallback? onUninstall;
  final VoidCallback? onUpdate;
  final VoidCallback? onShowCode;

  const UniversalExtensionCard({
    super.key,
    required this.extension,
    required this.isInstalled,
    this.isInstalling = false,
    this.isUpdating = false,
    this.onToggle,
    this.onInstall,
    this.onUninstall,
    this.onUpdate,
    this.onShowCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final ext = extension;
    final isOfficial = ext.id == 'aniting-universal' || ext.id == 'kawaii-animes' || ext.id == 'jkanime';
    final isNativeBuiltIn = isOfficial || ext.id == 'animetosho-new' || ext.id == 'mangadex';

    final Color statusColor = isInstalled
        ? (!ext.disabled ? theme.colorScheme.primary : theme.colorScheme.outline)
        : theme.colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOfficial
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isOfficial ? 1.5 : 1.0,
        ),
        boxShadow: isOfficial
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Icon, Titles, Badges, Switch ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Extension Icon (48x48)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ext.typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ext.typeColor.withValues(alpha: 0.25),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ext.icon != null && ext.icon!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: ext.icon!,
                        fit: BoxFit.cover,
                        memCacheWidth: 96,
                        memCacheHeight: 96,
                        maxWidthDiskCache: 140,
                        maxHeightDiskCache: 140,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (context, url) => Container(
                          color: ext.typeColor.withValues(alpha: 0.08),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          ext.typeIcon,
                          color: ext.typeColor,
                          size: 24,
                        ),
                      )
                    : Icon(ext.typeIcon, color: ext.typeColor, size: 24),
              ),
              const SizedBox(width: 12),

              // Title, Version, Author, Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ext.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOfficial) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.tertiary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.officialBadge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v${ext.version}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          '${l10n.byAuthor} ${ext.author}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Active / Inactive switch (when installed)
              if (isInstalled && onToggle != null) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.85,
                      child: Switch.adaptive(
                        value: !ext.disabled,
                        activeColor: theme.colorScheme.primary,
                        onChanged: onToggle,
                      ),
                    ),
                    Text(
                      !ext.disabled ? l10n.enabled : l10n.disabled,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // ─── Description ───
          if (ext.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              ext.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.75),
          const SizedBox(height: 12),

          // ─── Bottom Action Bar ───
          Row(
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isInstalled
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isInstalled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 13,
                      color: isInstalled ? theme.colorScheme.primary : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isInstalled ? l10n.installed : l10n.notInstalled,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isInstalled ? theme.colorScheme.primary : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Installed actions: View Code, Update, Uninstall
              if (isInstalled) ...[
                if (onShowCode != null && ext.manifestUri.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(AppIcons.code(iconPack), size: 18),
                    tooltip: l10n.viewSourceCode,
                    visualDensity: VisualDensity.compact,
                    onPressed: onShowCode,
                  ),
                ],
                if (ext.hasUpdate && onUpdate != null) ...[
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    onPressed: isUpdating ? null : onUpdate,
                    icon: isUpdating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt_rounded, size: 16),
                    label: Text(l10n.updateAvailable, style: const TextStyle(fontSize: 12)),
                  ),
                ],
                if (!isNativeBuiltIn && onUninstall != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      AppIcons.delete(iconPack),
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: l10n.uninstall,
                    visualDensity: VisualDensity.compact,
                    onPressed: onUninstall,
                  ),
                ],
              ] else ...[
                // Not Installed Action: Install Button
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  onPressed: isInstalling ? null : onInstall,
                  icon: isInstalling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    l10n.install,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
