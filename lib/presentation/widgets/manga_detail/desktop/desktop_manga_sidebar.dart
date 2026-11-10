import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DesktopMangaSidebar extends ConsumerWidget {
  final int mediaId;
  final String title;
  final int? idMal;
  final String? coverUrl;
  final String format;
  final String status;
  final int? year;
  final double? score;
  final int? totalChapters;
  final int? totalVolumes;
  final int progress;
  final VoidCallback onOpenEditModal;
  final VoidCallback? onBatchDownload;
  final bool showMetadata;
  final double width;

  const DesktopMangaSidebar({
    super.key,
    required this.mediaId,
    required this.title,
    this.idMal,
    required this.coverUrl,
    required this.format,
    required this.status,
    this.year,
    this.score,
    this.totalChapters,
    this.totalVolumes,
    required this.progress,
    required this.onOpenEditModal,
    this.onBatchDownload,
    this.showMetadata = false,
    this.width = 210,
  });

  Future<void> _launchAnilist(int mediaId) async {
    try {
      await launchUrlString(
        'https://anilist.co/manga/$mediaId',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _launchMal(int idMal) async {
    try {
      await launchUrlString(
        'https://myanimelist.net/manga/$idMal',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _shareManga(BuildContext context, String message) {
    Clipboard.setData(ClipboardData(text: 'https://anilist.co/manga/$mediaId'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
            height: width * 1.45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: coverUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 420,
                    memCacheHeight: 620,
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

          const SizedBox(height: 10),

          // ── Two Circular/Rounded Buttons Below Poster: [ ⋮ ] and [ 👤 ] ──
          Row(
            children: [
              // More options [ ⋮ ]
              GlassMenuAnchor(
                width: 200,
                items: [
                  GlassMenuItem(
                    label: 'AniList',
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    onPressed: () => _launchAnilist(mediaId),
                  ),
                  if (idMal != null)
                    GlassMenuItem(
                      label: 'MyAnimeList',
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      onPressed: () => _launchMal(idMal!),
                    ),
                  GlassMenuItem(
                    label: l10n.share,
                    icon: const Icon(Icons.share_rounded, size: 16),
                    onPressed: () => _shareManga(context, l10n.linkCopied),
                  ),
                  if (onBatchDownload != null)
                    GlassMenuItem(
                      label: l10n.batchDownload,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      onPressed: onBatchDownload!,
                    ),
                ],
                builder: (context, controller) {
                  return Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                      ),
                      tooltip: l10n.moreOptions,
                      onPressed: controller.open,
                    ),
                  );
                },
              ),

              const SizedBox(width: 8),

              // Edit List Entry / Profile [ 👤 ]
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                  tooltip: l10n.editStatus,
                  onPressed: onOpenEditModal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
