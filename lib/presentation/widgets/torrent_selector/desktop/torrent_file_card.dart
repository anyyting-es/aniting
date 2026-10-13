import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/models/torrent_selector_helpers.dart';

class TorrentFileCard extends ConsumerStatefulWidget {
  final TorrentItem torrent;
  final bool isStarting;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onExternalPlayer;

  const TorrentFileCard({
    super.key,
    required this.torrent,
    required this.isStarting,
    required this.onTap,
    required this.onDownload,
    required this.onExternalPlayer,
  });

  @override
  ConsumerState<TorrentFileCard> createState() => _TorrentFileCardState();
}

class _TorrentFileCardState extends ConsumerState<TorrentFileCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final torrent = widget.torrent;
    final isBatch = isBatchTorrent(torrent);
    final isBest = torrent.isBestRelease;
    final health = TorrentHealthInfo.resolve(torrent.seeders, l10n);
    final group = TorrentNameParser.extractReleaseGroup(torrent);
    final cleanTitle = TorrentNameParser.cleanDisplayTitle(torrent.name);

    // Styling
    final bgColor = isDark
        ? (_isHovered
            ? const Color(0xFF1E222D)
            : const Color(0xFF13161F))
        : (_isHovered
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerLow);

    final borderColor = isBest
        ? Colors.amber.withValues(alpha: _isHovered ? 0.8 : 0.5)
        : (_isHovered
            ? theme.colorScheme.primary.withValues(alpha: 0.5)
            : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4)));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isBest ? 1.4 : 1.0),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: (isBest ? Colors.amber : theme.colorScheme.primary)
                        .withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.isStarting ? null : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP ROW: Tags (Group, Quality, Best, Batch, Provider) ---
                  Row(
                    children: [
                      // Release Group tag
                      if (group != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            group,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Resolution tag
                      if (torrent.resolution != null && torrent.resolution!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            torrent.resolution!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Best Release Badge
                      if (isBest) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                l10n.bestRelease,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Batch Badge
                      if (isBatch) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_zip_rounded, size: 13, color: Colors.purpleAccent),
                              const SizedBox(width: 4),
                              Text(
                                l10n.batchReleaseLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purpleAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      const Spacer(),

                      // Provider Name
                      if (torrent.provider != null && torrent.provider!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            torrent.provider!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // --- TITLE ROW ---
                  Text(
                    cleanTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // --- BOTTOM SPECS & ACTIONS ROW ---
                  Row(
                    children: [
                      // Health & Seeders pill (Very clear and understandable!)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: health.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: health.color.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: health.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.seedsCount(torrent.seeders),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: health.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• ${health.label}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: health.color.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // File Size Pill
                      if (torrent.formattedSize.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.folder(iconPack),
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                torrent.formattedSize,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const Spacer(),

                      // --- ACTION BUTTONS ---
                      if (widget.isStarting) ...[
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ] else ...[
                        // External Player Icon Button
                        IconButton(
                          tooltip: l10n.openInExternalPlayer,
                          onPressed: widget.onExternalPlayer,
                          icon: Icon(
                            AppIcons.openInNew(iconPack),
                            size: 19,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(36, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Download Button
                        IconButton(
                          tooltip: l10n.downloadWithTorrentClient,
                          onPressed: widget.onDownload,
                          icon: Icon(
                            AppIcons.download(iconPack),
                            size: 19,
                            color: theme.colorScheme.primary,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(36, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Primary Stream Action Pill
                        FilledButton.icon(
                          onPressed: widget.onTap,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            l10n.streamEpisodeAction,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ],
                    ],
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
