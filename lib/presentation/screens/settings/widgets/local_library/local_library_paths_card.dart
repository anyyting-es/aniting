import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/local_library_provider.dart';

class LocalLibraryPathsCard extends ConsumerWidget {
  final LocalLibraryState state;

  const LocalLibraryPathsCard({super.key, required this.state});

  void _showAddFolderDialog(
    BuildContext context,
    WidgetRef ref, {
    bool isMain = false,
  }) {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);
    final controller = TextEditingController(
      text: isMain ? state.mainPath : '',
    );
    final repo = ref.read(repositoryProvider);
    List<String> suggestions = [];
    String selectedType = isMain
        ? (state.folderTypes[state.mainPath] ?? 'anime')
        : 'anime';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void onInputChanged(String val) async {
              if (val.trim().length >= 2) {
                final res = await repo.getDirectorySuggestions(val.trim());
                if (res != null && res['suggestions'] is List) {
                  final list = (res['suggestions'] as List)
                      .map((s) => s is Map ? s['fullPath'] as String? : null)
                      .whereType<String>()
                      .toList();
                  setDialogState(() => suggestions = list);
                }
              } else {
                setDialogState(() => suggestions = []);
              }
            }

            return AlertDialog(
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                isMain ? l10n.mainLibraryFolder : l10n.addLibraryFolder,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: onInputChanged,
                      decoration: InputDecoration(
                        labelText: l10n.folderPathLabel,
                        hintText: l10n.enterFolderPathHint,
                        prefixIcon: const Icon(
                          Icons.folder_open_rounded,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.folderTypeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(
                            l10n.folderTypeAnime,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selectedType == 'anime',
                          onSelected: (_) =>
                              setDialogState(() => selectedType = 'anime'),
                        ),
                        ChoiceChip(
                          label: Text(
                            l10n.folderTypeTv,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selectedType == 'tv',
                          onSelected: (_) =>
                              setDialogState(() => selectedType = 'tv'),
                        ),
                        ChoiceChip(
                          label: Text(
                            l10n.folderTypeMovie,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selectedType == 'movie',
                          onSelected: (_) =>
                              setDialogState(() => selectedType = 'movie'),
                        ),
                        ChoiceChip(
                          label: Text(
                            l10n.folderTypeMixed,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selectedType == 'mixed',
                          onSelected: (_) =>
                              setDialogState(() => selectedType = 'mixed'),
                        ),
                      ],
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (ctx, i) {
                            final sug = suggestions[i];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              leading: const Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 16,
                              ),
                              title: Text(
                                sug,
                                style: const TextStyle(fontSize: 12.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                controller.text = sug;
                                setDialogState(() => suggestions = []);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                FilledButton(
                  onPressed: () async {
                    final path = controller.text.trim();
                    if (path.isEmpty) return;

                    final notifier = ref.read(localLibraryProvider.notifier);
                    Navigator.of(dialogCtx).pop();

                    bool success;
                    if (isMain) {
                      success = await notifier.setMainPath(
                        path,
                        type: selectedType,
                      );
                    } else {
                      success = await notifier.addAdditionalPath(
                        path,
                        type: selectedType,
                      );
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? l10n.folderAddedSuccess
                                : l10n.folderPathInvalid,
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(l10n.saveFolder),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final notifier = ref.read(localLibraryProvider.notifier);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.folder_special_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.libraryFoldersSection,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                if (state.mainPath.isNotEmpty ||
                    state.additionalPaths.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.link_off_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: l10n.unlinkAllFoldersAction,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmUnlinkAllFolders(context, ref),
                  ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  tooltip: l10n.addLibraryFolder,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      _showAddFolderDialog(context, ref, isMain: false),
                ),
              ],
            ),
          ),

          // Main folder tile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.home_filled,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.mainLibraryFolder,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (state.mainPath.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _FolderTypeBadge(
                                type:
                                    state.folderTypes[state.mainPath] ??
                                    'anime',
                                onSelectType: (type) => notifier.setFolderType(
                                  state.mainPath,
                                  type,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          state.mainPath.isNotEmpty
                              ? state.mainPath
                              : l10n.noFoldersConfigured,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: state.mainPath.isNotEmpty
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: l10n.mainLibraryFolder,
                    onPressed: () =>
                        _showAddFolderDialog(context, ref, isMain: true),
                  ),
                  if (state.mainPath.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.link_off_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: l10n.unlinkFolderAction,
                      onPressed: () => _confirmUnlinkMainFolder(context, ref),
                    ),
                ],
              ),
            ),
          ),

          // Additional folders list
          if (state.additionalPaths.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text(
                l10n.additionalLibraryFolders,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...state.additionalPaths.map((path) {
              final folderType = state.folderTypes[path] ?? 'anime';
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              path,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            _FolderTypeBadge(
                              type: folderType,
                              onSelectType: (t) =>
                                  notifier.setFolderType(path, t),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.link_off_rounded,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        tooltip: l10n.unlinkFolderAction,
                        onPressed: () =>
                            _confirmRemoveAdditionalFolder(context, ref, path),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _confirmUnlinkAllFolders(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.unlinkAllFoldersConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          l10n.unlinkAllFoldersConfirmMessage,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final ok = await ref
                  .read(localLibraryProvider.notifier)
                  .unlinkAllFolders();
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.allFoldersUnlinkedSuccess),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(l10n.unlinkAllFoldersAction),
          ),
        ],
      ),
    );
  }

  void _confirmUnlinkMainFolder(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.unlinkMainFolderConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          l10n.unlinkMainFolderConfirmMessage,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final ok = await ref
                  .read(localLibraryProvider.notifier)
                  .setMainPath('');
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.folderRemovedSuccess),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(l10n.unlinkFolderAction),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveAdditionalFolder(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.unlinkFolderConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          l10n.unlinkFolderConfirmMessage,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final ok = await ref
                  .read(localLibraryProvider.notifier)
                  .removeAdditionalPath(path);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.folderRemovedSuccess),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(l10n.unlinkFolderAction),
          ),
        ],
      ),
    );
  }
}

class _FolderTypeBadge extends ConsumerWidget {
  final String type;
  final ValueChanged<String> onSelectType;

  const _FolderTypeBadge({required this.type, required this.onSelectType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    String label;
    Color color;
    IconData icon;

    switch (type) {
      case 'tv':
        label = l10n.folderTypeTv;
        color = const Color(0xFF6366F1);
        icon = Icons.tv_rounded;
        break;
      case 'movie':
        label = l10n.folderTypeMovie;
        color = const Color(0xFFEC4899);
        icon = Icons.movie_creation_outlined;
        break;
      case 'mixed':
        label = l10n.folderTypeMixed;
        color = const Color(0xFFF59E0B);
        icon = Icons.auto_awesome_rounded;
        break;
      case 'anime':
      default:
        label = l10n.folderTypeAnime;
        color = theme.colorScheme.primary;
        icon = Icons.animation_rounded;
        break;
    }

    return PopupMenuButton<String>(
      tooltip: l10n.folderTypeLabel,
      onSelected: onSelectType,
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'anime', child: Text(l10n.folderTypeAnime)),
        PopupMenuItem(value: 'tv', child: Text(l10n.folderTypeTv)),
        PopupMenuItem(value: 'movie', child: Text(l10n.folderTypeMovie)),
        PopupMenuItem(value: 'mixed', child: Text(l10n.folderTypeMixed)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
