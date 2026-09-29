import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../data/models/extension_item.dart';

class WelcomeMarketplaceSheet extends ConsumerStatefulWidget {
  final List<ExtensionItem> marketplaceExtensions;
  final Set<String> installedExtensionIds;
  final Set<String> installingExtensionIds;
  final Future<void> Function(ExtensionItem ext) onInstallExtension;

  const WelcomeMarketplaceSheet({
    super.key,
    required this.marketplaceExtensions,
    required this.installedExtensionIds,
    required this.installingExtensionIds,
    required this.onInstallExtension,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ExtensionItem> marketplaceExtensions,
    required Set<String> installedExtensionIds,
    required Set<String> installingExtensionIds,
    required Future<void> Function(ExtensionItem ext) onInstallExtension,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 700),
      builder: (sheetContext) => WelcomeMarketplaceSheet(
        marketplaceExtensions: marketplaceExtensions,
        installedExtensionIds: installedExtensionIds,
        installingExtensionIds: installingExtensionIds,
        onInstallExtension: onInstallExtension,
      ),
    );
  }

  @override
  ConsumerState<WelcomeMarketplaceSheet> createState() => _WelcomeMarketplaceSheetState();
}

class _WelcomeMarketplaceSheetState extends ConsumerState<WelcomeMarketplaceSheet> {
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colors = context.themeColors;

    final filtered = widget.marketplaceExtensions.where((ext) {
      if (_selectedCategory != 'all' && ext.type != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = ext.name.toLowerCase().contains(query);
        final matchDesc = ext.description.toLowerCase().contains(query);
        final matchAuthor = ext.author.toLowerCase().contains(query);
        if (!matchName && !matchDesc && !matchAuthor) return false;
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: theme.colorScheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.exploreAllMarketplace,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.searchExtensionsPrompt,
                    hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: colors.surfaceElevated.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildSheetFilterChip(
                      label: l10n.allTypes,
                      isSelected: _selectedCategory == 'all',
                      theme: theme,
                      colors: colors,
                      onTap: () => setState(() => _selectedCategory = 'all'),
                    ),
                    const SizedBox(width: 6),
                    _buildSheetFilterChip(
                      label: 'Torrents',
                      isSelected: _selectedCategory == 'anime-torrent-provider',
                      theme: theme,
                      colors: colors,
                      onTap: () => setState(() => _selectedCategory = 'anime-torrent-provider'),
                    ),
                    const SizedBox(width: 6),
                    _buildSheetFilterChip(
                      label: 'Streaming',
                      isSelected: _selectedCategory == 'onlinestream-provider',
                      theme: theme,
                      colors: colors,
                      onTap: () => setState(() => _selectedCategory = 'onlinestream-provider'),
                    ),
                    const SizedBox(width: 6),
                    _buildSheetFilterChip(
                      label: 'Manga',
                      isSelected: _selectedCategory == 'manga-provider',
                      theme: theme,
                      colors: colors,
                      onTap: () => setState(() => _selectedCategory = 'manga-provider'),
                    ),
                    const SizedBox(width: 6),
                    _buildSheetFilterChip(
                      label: 'Custom Sources',
                      isSelected: _selectedCategory == 'custom-source',
                      theme: theme,
                      colors: colors,
                      onTap: () => setState(() => _selectedCategory = 'custom-source'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),

              // List of extensions
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron extensiones',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final ext = filtered[idx];
                          final isInstalled = widget.installedExtensionIds.contains(ext.id);
                          final isInstalling = widget.installingExtensionIds.contains(ext.id);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isInstalled
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : colors.surfaceElevated.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isInstalled
                                    ? Colors.green.withValues(alpha: 0.4)
                                    : colors.border.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
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
                                          placeholder: (_, _) =>
                                              Container(color: ext.typeColor.withValues(alpha: 0.1)),
                                          errorWidget: (_, _, _) =>
                                              Icon(ext.typeIcon, color: ext.typeColor, size: 18),
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
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
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
                                        ext.description.isNotEmpty
                                            ? ext.description
                                            : 'v${ext.version} • ${ext.author}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isInstalling)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else if (isInstalled)
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
                                else
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      await widget.onInstallExtension(ext);
                                      if (mounted) setState(() {});
                                    },
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    child: const Text('Instalar', style: TextStyle(fontSize: 11.5)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetFilterChip({
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
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
