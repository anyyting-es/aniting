import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
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

    final torrent = widget.torrent;
    final isBest = torrent.isBestRelease;
    final group = TorrentNameParser.extractReleaseGroup(torrent) ?? 'Release';
    final parsedTags = TorrentNameParser.parseTags(torrent);
    final relativeDate = TorrentNameParser.formatRelativeDate(torrent.date);

    // Resolution badge: prefer torrent.resolution, fallback to parsed or 1080p
    final res = (torrent.resolution != null && torrent.resolution!.isNotEmpty)
        ? torrent.resolution!
        : (torrent.name.toLowerCase().contains('720')
            ? '720p'
            : (torrent.name.toLowerCase().contains('2160') || torrent.name.toLowerCase().contains('4k')
                ? '4K'
                : '1080p'));

    final bgColor = isDark
        ? (_isHovered ? const Color(0xFF1A1E29) : const Color(0xFF12151E))
        : (_isHovered
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerLow);

    final borderColor = isBest
        ? Colors.amber.withValues(alpha: _isHovered ? 0.7 : 0.35)
        : (_isHovered
            ? theme.colorScheme.primary.withValues(alpha: 0.4)
            : (isDark
                ? Colors.white.withValues(alpha: 0.07)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.35)));

    final leftBoxBg = isDark
        ? const Color(0xFF1B1E2B)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isBest ? 1.2 : 1.0),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.isStarting ? null : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- LEFT BOX: Release group and resolution ---
                  Container(
                    width: 92,
                    height: 66,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: leftBoxBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          res,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF38BDF8), // Cyan
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // --- RIGHT BODY: Details & Tags ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Row 1: Episode label & checkmark + Tech badges + Actions
                        Row(
                          children: [
                            // Episode label + checkmark
                            Text(
                              parsedTags.episode != null
                                  ? '${l10n.episode} ${parsedTags.episode}'
                                  : (isBatchTorrent(torrent)
                                      ? l10n.batches
                                      : l10n.singleEpisodeRelease),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Color(0xFF10B981), // Emerald checkmark
                            ),

                            const SizedBox(width: 8),

                            // Video Codec Badge (H.264 / HEVC / AVC)
                            if (parsedTags.videoCodec != null) ...[
                              _buildPillTag(theme, isDark, parsedTags.videoCodec!),
                              const SizedBox(width: 5),
                            ],

                            // 10-bit Badge
                            if (parsedTags.is10Bit) ...[
                              _buildPillTag(theme, isDark, '10bit'),
                              const SizedBox(width: 5),
                            ],

                            // Audio Codec Badge (AAC2.0 / FLAC / etc)
                            if (parsedTags.audioCodec != null) ...[
                              _buildPillTag(theme, isDark, parsedTags.audioCodec!),
                              const SizedBox(width: 5),
                            ],

                            // Dual Audio / Dub badge
                            if (parsedTags.isDualAudio) ...[
                              _buildIconPillTag(
                                theme,
                                isDark,
                                Icons.mic_none_rounded,
                                l10n.originalPlusDub,
                              ),
                              const SizedBox(width: 5),
                            ],

                            // Multi Subs badge
                            if (parsedTags.isMultiSubs) ...[
                              _buildIconPillTag(
                                theme,
                                isDark,
                                Icons.chat_bubble_outline_rounded,
                                l10n.multiSubs,
                              ),
                              const SizedBox(width: 5),
                            ],

                            const Spacer(),

                            // Right actions: starting indicator or action icons
                            if (widget.isStarting) ...[
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                            ] else ...[
                              // Download icon button
                              Tooltip(
                                message: l10n.downloadInBackground,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: widget.onDownload,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.download_rounded,
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // External player icon button
                              Tooltip(
                                message: l10n.openInExternalPlayer,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: widget.onExternalPlayer,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.open_in_new_rounded,
                                      size: 15,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 3),

                        // Row 2: Full filename / release name
                        Text(
                          torrent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Row 3: Signal icon + Seeders • Size • Relative date
                        Row(
                          children: [
                            // Seeders
                            const Icon(
                              Icons.sensors_rounded,
                              size: 13,
                              color: Color(0xFF38BDF8), // Cyan
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${torrent.seeders} ${l10n.sortSeeders.toLowerCase()}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF38BDF8),
                              ),
                            ),

                            // Bullet separator
                            _buildBullet(theme),

                            // Size
                            Text(
                              torrent.formattedSize,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),

                            // Bullet separator & date
                            if (relativeDate.isNotEmpty) ...[
                              _buildBullet(theme),
                              Text(
                                relativeDate,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ],

                            // Best Release tag if present
                            if (isBest) ...[
                              _buildBullet(theme),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                                  const SizedBox(width: 2),
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
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '•',
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildPillTag(ThemeData theme, bool isDark, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildIconPillTag(ThemeData theme, bool isDark, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
