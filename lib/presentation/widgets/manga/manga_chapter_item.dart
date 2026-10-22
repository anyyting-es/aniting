import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

/// Single chapter tile in the manga detail chapters list.
class MangaChapterItem extends ConsumerWidget {
  final MangaChapter chapter;
  final bool isRead;
  final bool isDownloaded;
  final bool isDownloading;
  final bool canDownload;
  final double borderRadius;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final bool isSelected;
  final VoidCallback? onToggleSelect;

  const MangaChapterItem({
    super.key,
    required this.chapter,
    required this.isRead,
    required this.isDownloaded,
    required this.isDownloading,
    required this.canDownload,
    required this.borderRadius,
    required this.onTap,
    this.onDownload,
    this.isSelected = false,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isDark = theme.brightness == Brightness.dark;

    final baseBg = isSelected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.04)
            : theme.colorScheme.surfaceContainerLow);

    final borderColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.6)
        : (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.25));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isRead ? 0.60 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggleSelect != null && isSelected ? onToggleSelect : onTap,
            onLongPress: onToggleSelect,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  // Checkbox if selected
                  if (isSelected) ...[
                    Icon(
                      AppIcons.checkCircleFilled(iconPack),
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Chapter number badge
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isRead
                          ? theme.colorScheme.primary.withValues(alpha: 0.10)
                          : theme.colorScheme.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      chapter.chapter,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Scanlator
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chapter.title.isNotEmpty ? chapter.title : '${l10n.chapter} ${chapter.chapter}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (isRead
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface),
                          ),
                        ),
                        if (chapter.scanlator != null && chapter.scanlator!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            chapter.scanlator!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Download status / action
                  if (isDownloaded)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message: l10n.downloadedInStorage,
                        child: Icon(
                          AppIcons.checkCircle(iconPack),
                          size: 19,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  else if (isDownloading)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (canDownload && onDownload != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(
                        AppIcons.download(iconPack),
                        size: 19,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                      tooltip: l10n.downloadChapter,
                      onPressed: onDownload,
                    ),

                  Icon(
                    AppIcons.chevronRight(iconPack),
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
