import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

/// Top section for Manga Mobile Layout: Poster cover, title, metadata, and continue button
class MobileMangaHeader extends ConsumerWidget {
  final MangaEntry? resolved;
  final String title;
  final String? posterUrl;
  final int progress;
  final bool hasChapters;
  final VoidCallback onOpenEditModal;
  final VoidCallback onContinueReading;

  const MobileMangaHeader({
    super.key,
    required this.resolved,
    required this.title,
    required this.posterUrl,
    required this.progress,
    required this.hasChapters,
    required this.onOpenEditModal,
    required this.onContinueReading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    final iconColor = isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant;
    final textShadows = isDark
        ? [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4)]
        : null;

    final format = resolved?.format ?? 'MANGA';
    final year = resolved?.year;
    final status = resolved?.status ?? 'RELEASING';
    final score = resolved?.score;
    final totalChapters = resolved?.totalChapters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Poster Cover
              Container(
                width: 125,
                height: 185,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        memCacheHeight: 440,
                        errorWidget: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.menu_book_rounded, size: 40),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.menu_book_rounded, size: 40),
                      ),
              ),

              const SizedBox(width: 16),

              // Metadata Foot-aligned
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Title
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: textShadows,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Line 1: Year • Format • Status
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: iconColor, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (year != null) '$year',
                              format,
                              l10n.formatStatus(status),
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 11.5,
                              shadows: textShadows,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Line 2: Rating Score & Genres
                    Row(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          color: isDark ? iconColor : theme.colorScheme.primary,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            score != null && score > 0
                                ? '${score.toStringAsFixed(1)} • ${resolved?.genres.take(2).join(', ') ?? ""}'
                                : (resolved?.genres.take(2).join(', ') ?? 'Manga'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 11.5,
                              shadows: textShadows,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Line 3: Chapters Progress & Edit Status Chip
                    InkWell(
                      onTap: onOpenEditModal,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Icon(
                                Icons.edit_note_rounded,
                                size: 13,
                                color: isDark ? Colors.white : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                totalChapters != null && totalChapters > 0
                                    ? '$progress / $totalChapters ${l10n.chapters.toLowerCase()}'
                                    : '${l10n.chapter} $progress',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  shadows: textShadows,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Expressive Continue Reading Button
        if (progress > 0 && hasChapters) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: M3EButton.icon(
                style: M3EButtonStyle.filled,
                size: M3EButtonSize.md,
                shape: M3EButtonShape.round,
                icon: const Icon(Icons.menu_book_rounded, size: 20),
                label: Text(
                  l10n.continueChapterNumbered(progress + 1),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: onContinueReading,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
