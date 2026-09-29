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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Chapter number badge
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isRead
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular((borderRadius * 0.5).clamp(0.0, 8.0)),
              ),
              child: Text(
                chapter.chapter,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isRead
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Text(
                chapter.title.isNotEmpty ? chapter.title : '${l10n.chapter} ${chapter.chapter}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isRead
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Download status / action
            if (isDownloaded)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: 'Descargado en almacenamiento',
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
                tooltip: 'Descargar capítulo',
                onPressed: onDownload,
              ),

            Icon(
              AppIcons.chevronRight(iconPack),
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
