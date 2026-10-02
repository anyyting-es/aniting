import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class DesktopMangaSidebar extends ConsumerWidget {
  final String? coverUrl;
  final String format;
  final String status;
  final int? year;
  final double? score;
  final int? totalChapters;
  final int? totalVolumes;
  final int progress;
  final VoidCallback onOpenEditModal;
  final bool showMetadata;
  final double width;

  const DesktopMangaSidebar({
    super.key,
    required this.coverUrl,
    required this.format,
    required this.status,
    this.year,
    this.score,
    this.totalChapters,
    this.totalVolumes,
    required this.progress,
    required this.onOpenEditModal,
    this.showMetadata = false,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Large Cover Poster ──
          Container(
            width: width,
            height: width * 1.46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: coverUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 440,
                    memCacheHeight: 640,
                    placeholder: (_, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  ),
          ),

          if (showMetadata) ...[
            const SizedBox(height: 18),

            // ── Progress & AniList Status Pill ──
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenEditModal,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.myProgress,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              totalChapters != null && totalChapters! > 0
                                  ? '$progress / $totalChapters ${l10n.chapters.toLowerCase()}'
                                  : '${l10n.chapter} $progress',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Metadata List Rows ──
            _buildInfoRow(theme, l10n.format, format.replaceAll('_', ' ')),
            _buildInfoRow(theme, l10n.status, l10n.formatStatus(status)),
            if (year != null) _buildInfoRow(theme, l10n.yearTitle, '$year'),
            if (totalChapters != null && totalChapters! > 0)
              _buildInfoRow(theme, l10n.chapters, '$totalChapters'),
            if (totalVolumes != null && totalVolumes! > 0)
              _buildInfoRow(theme, l10n.volumes, '$totalVolumes'),
            if (score != null && score! > 0)
              _buildInfoRow(theme, l10n.score, '★ ${score!.toStringAsFixed(1)} / 10'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
