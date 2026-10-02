import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/extension_item.dart';
import 'welcome_marketplace_sheet.dart';

class WelcomeStepExtensions extends ConsumerStatefulWidget {
  final List<ExtensionItem> marketplaceExtensions;
  final bool isLoading;
  final Set<String> selectedExtensionIds;
  final Set<String> installedExtensionIds;
  final Set<String> installingExtensionIds;
  final void Function(ExtensionItem ext) onToggleSelect;
  final Future<void> Function() onInstallSelected;
  final Future<void> Function(ExtensionItem ext) onInstallSingle;
  final List<ExtensionItem> Function(AppLanguage lang) getRecommendedExtensions;

  const WelcomeStepExtensions({
    super.key,
    required this.marketplaceExtensions,
    required this.isLoading,
    required this.selectedExtensionIds,
    required this.installedExtensionIds,
    required this.installingExtensionIds,
    required this.onToggleSelect,
    required this.onInstallSelected,
    required this.onInstallSingle,
    required this.getRecommendedExtensions,
  });

  @override
  ConsumerState<WelcomeStepExtensions> createState() => _WelcomeStepExtensionsState();
}

class _WelcomeStepExtensionsState extends ConsumerState<WelcomeStepExtensions> {
  int _extensionsFilterIndex = 0; // 0: Todas, 1: Torrents, 2: Streaming, 3: Manga

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final currentLang = ref.watch(appLanguageProvider);
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colors = context.themeColors;

    final allRecs = widget.getRecommendedExtensions(currentLang);
    final List<ExtensionItem> filteredRecs;
    if (_extensionsFilterIndex == 1) {
      filteredRecs = allRecs.where((e) => e.type == 'anime-torrent-provider').toList();
    } else if (_extensionsFilterIndex == 2) {
      filteredRecs = allRecs.where((e) => e.type == 'onlinestream-provider').toList();
    } else if (_extensionsFilterIndex == 3) {
      filteredRecs = allRecs.where((e) => e.type == 'manga-provider').toList();
    } else {
      filteredRecs = allRecs;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.extension_rounded, size: 24, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.welcomeStepExtensions,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.welcomeExtensionsPrompt,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          if (widget.marketplaceExtensions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.welcomeExtensionsEmptyHint,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Filter Pills Row (Todas, Torrents, Streaming, Manga)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildExtFilterChip(
                    label: l10n.allRecommended,
                    isSelected: _extensionsFilterIndex == 0,
                    theme: theme,
                    colors: colors,
                    onTap: () => setState(() => _extensionsFilterIndex = 0),
                  ),
                  const SizedBox(width: 6),
                  _buildExtFilterChip(
                    label: 'Torrents',
                    isSelected: _extensionsFilterIndex == 1,
                    theme: theme,
                    colors: colors,
                    onTap: () => setState(() => _extensionsFilterIndex = 1),
                  ),
                  const SizedBox(width: 6),
                  _buildExtFilterChip(
                    label: 'Streaming',
                    isSelected: _extensionsFilterIndex == 2,
                    theme: theme,
                    colors: colors,
                    onTap: () => setState(() => _extensionsFilterIndex = 2),
                  ),
                  const SizedBox(width: 6),
                  _buildExtFilterChip(
                    label: 'Manga',
                    isSelected: _extensionsFilterIndex == 3,
                    theme: theme,
                    colors: colors,
                    onTap: () => setState(() => _extensionsFilterIndex = 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Counter & Actions Bar
            Row(
              children: [
                Text(
                  '${widget.installedExtensionIds.length} ${l10n.welcomeInstalledCount}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onInstallSelected,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(l10n.welcomeInstallAll),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Recommended extensions cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredRecs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final ext = filteredRecs[idx];
                final isInstalled = widget.installedExtensionIds.contains(ext.id);
                final isInstalling = widget.installingExtensionIds.contains(ext.id);
                final isSelected = widget.selectedExtensionIds.contains(ext.id);

                return InkWell(
                  onTap: isInstalled ? null : () => widget.onToggleSelect(ext),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isInstalled
                          ? Colors.green.withValues(alpha: 0.08)
                          : isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.10)
                              : colors.surfaceElevated.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isInstalled
                            ? Colors.green.withValues(alpha: 0.45)
                            : isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                                : colors.border.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isInstalled || isSelected,
                          activeColor: isInstalled ? Colors.green : theme.colorScheme.primary,
                          onChanged: isInstalled ? null : (_) => widget.onToggleSelect(ext),
                        ),
                        const SizedBox(width: 4),
                        // Extension icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: ext.typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ext.icon != null && ext.icon!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: ext.icon!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 72,
                                  memCacheHeight: 72,
                                  fadeInDuration: const Duration(milliseconds: 150),
                                  placeholder: (_, _) => Container(color: ext.typeColor.withValues(alpha: 0.1)),
                                  errorWidget: (_, _, _) => Icon(ext.typeIcon, color: ext.typeColor, size: 18),
                                )
                              : Icon(ext.typeIcon, color: ext.typeColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      ext.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: ext.typeColor.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      ext.typeLabel,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: ext.typeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ext.description.isNotEmpty ? ext.description : 'v${ext.version} • ${ext.author}',
                                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isInstalling)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (isInstalled)
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                        else
                          IconButton(
                            icon: const Icon(Icons.download_rounded, size: 20),
                            tooltip: 'Instalar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => widget.onInstallSingle(ext),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            // Explore Full Marketplace Button
            InkWell(
              onTap: () {
                WelcomeMarketplaceSheet.show(
                  context,
                  marketplaceExtensions: widget.marketplaceExtensions,
                  installedExtensionIds: widget.installedExtensionIds,
                  installingExtensionIds: widget.installingExtensionIds,
                  onInstallExtension: widget.onInstallSingle,
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.storefront_rounded, size: 20, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.exploreAllMarketplace,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Explora el catálogo completo con más de ${widget.marketplaceExtensions.length} extensiones',
                            style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtFilterChip({
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.16)
              : colors.surfaceElevated.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.5) : colors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
