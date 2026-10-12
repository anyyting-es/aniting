import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/local_library_provider.dart';

class LocalLibraryPathsCard extends ConsumerWidget {
  final LocalLibraryState state;

  const LocalLibraryPathsCard({
    super.key,
    required this.state,
  });

  void _showAddFolderDialog(BuildContext context, WidgetRef ref, {bool isMain = false}) {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);
    final controller = TextEditingController(text: isMain ? state.mainPath : '');
    final repo = ref.read(repositoryProvider);
    List<String> suggestions = [];

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                isMain ? l10n.mainLibraryFolder : l10n.addLibraryFolder,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                        prefixIcon: const Icon(Icons.folder_open_rounded, size: 20),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (ctx, i) {
                            final sug = suggestions[i];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              leading: const Icon(Icons.subdirectory_arrow_right_rounded, size: 16),
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
                      success = await notifier.setMainPath(path);
                    } else {
                      success = await notifier.addAdditionalPath(path);
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? l10n.folderAddedSuccess : l10n.folderPathInvalid),
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  tooltip: l10n.addLibraryFolder,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showAddFolderDialog(context, ref, isMain: false),
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                    child: Icon(Icons.home_filled, size: 16, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mainLibraryFolder,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.mainPath.isNotEmpty ? state.mainPath : l10n.noFoldersConfigured,
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
                    onPressed: () => _showAddFolderDialog(context, ref, isMain: true),
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          path,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                        tooltip: l10n.removeFolder,
                        onPressed: () async {
                          final ok = await notifier.removeAdditionalPath(path);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.folderRemovedSuccess),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
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
}
