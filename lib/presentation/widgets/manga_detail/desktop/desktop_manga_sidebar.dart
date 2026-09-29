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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Large Cover Poster ──
          Container(
            width: 240,
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: coverUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    memCacheHeight: 700,
                    placeholder: (_, _) => Container(
                      color: const Color(0xFF14171B),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: const Color(0xFF14171B),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: Colors.white24,
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFF14171B),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 48,
                      color: Colors.white24,
                    ),
                  ),
          ),

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
                            'Mi Progreso',
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
          _buildInfoRow('Formato', format.replaceAll('_', ' ')),
          _buildInfoRow('Estado', l10n.formatStatus(status)),
          if (year != null) _buildInfoRow('Año', '$year'),
          if (totalChapters != null && totalChapters! > 0)
            _buildInfoRow('Capítulos', '$totalChapters'),
          if (totalVolumes != null && totalVolumes! > 0)
            _buildInfoRow('Volúmenes', '$totalVolumes'),
          if (score != null && score! > 0)
            _buildInfoRow('Puntuación', '★ ${score!.toStringAsFixed(1)} / 10'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
