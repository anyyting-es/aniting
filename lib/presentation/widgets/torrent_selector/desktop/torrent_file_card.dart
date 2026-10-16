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
  final VoidCallback? onDownload;
  final VoidCallback? onExternalPlayer;

  const TorrentFileCard({
    super.key,
    required this.torrent,
    required this.isStarting,
    required this.onTap,
    this.onDownload,
    this.onExternalPlayer,
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
        ? (_isHovered
            ? const Color(0xFF1C1D21).withValues(alpha: 0.82)
            : const Color(0xFF131416).withValues(alpha: 0.68))
        : (_isHovered
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.85)
            : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.72));

    final borderColor = isBest
        ? Colors.amber.withValues(alpha: _isHovered ? 0.7 : 0.35)
        : (_isHovered
            ? theme.colorScheme.primary.withValues(alpha: 0.35)
            : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.35)));

    final leftBoxBg = isDark
        ? const Color(0xFF18191D).withValues(alpha: 0.75)
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;

              if (isCompact) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.isStarting ? null : widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Group, Res, Episode, Star, Actions
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: leftBoxBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                group,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.16) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                res,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (isBest) ...[
                              const SizedBox(width: 6),
                              Icon(AppIcons.star(iconPack), size: 14, color: Colors.amber),
                            ],
                            const Spacer(),
                            if (widget.isStarting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Row 2: Filename
                        Text(
                          torrent.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
                          ),
                        ),

                        // Row 3: Tech tags
                        if (parsedTags.videoCodec != null ||
                            parsedTags.is10Bit ||
                            parsedTags.audioCodec != null ||
                            parsedTags.isDualAudio ||
                            parsedTags.isMultiSubs) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (parsedTags.videoCodec != null)
                                _buildPillTag(theme, isDark, parsedTags.videoCodec!),
                              if (parsedTags.is10Bit) _buildPillTag(theme, isDark, '10bit'),
                              if (parsedTags.audioCodec != null)
                                _buildPillTag(theme, isDark, parsedTags.audioCodec!),
                              if (parsedTags.isDualAudio)
                                _buildIconPillTag(
                                  theme,
                                  isDark,
                                  AppIcons.mic(iconPack),
                                  l10n.originalPlusDub,
                                ),
                              if (parsedTags.isMultiSubs)
                                _buildIconPillTag(
                                  theme,
                                  isDark,
                                  AppIcons.chatBubble(iconPack),
                                  l10n.multiSubs,
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 6),

                        // Row 4: Seeders, Size, Date & Play cue
                        Row(
                          children: [
                            Icon(
                              AppIcons.sensors(iconPack),
                              size: 13,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${torrent.seeders} ${l10n.sortSeeders.toLowerCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                              ),
                            ),
                            _buildBullet(theme),
                            Text(
                              torrent.formattedSize,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (relativeDate.isNotEmpty) ...[
                              _buildBullet(theme),
                              Text(
                                relativeDate,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return InkWell(
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
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFE2E8F0) : theme.colorScheme.onSurface,
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
                            // Row 1: Full filename & Starting spinner
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    torrent.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (widget.isStarting) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ],
                              ],
                            ),

                            // Row 2: Tech tags (if any)
                            if (parsedTags.videoCodec != null ||
                                parsedTags.is10Bit ||
                                parsedTags.audioCodec != null ||
                                parsedTags.isDualAudio ||
                                parsedTags.isMultiSubs) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (parsedTags.videoCodec != null) ...[
                                    _buildPillTag(theme, isDark, parsedTags.videoCodec!),
                                    const SizedBox(width: 5),
                                  ],

                                  if (parsedTags.is10Bit) ...[
                                    _buildPillTag(theme, isDark, '10bit'),
                                    const SizedBox(width: 5),
                                  ],

                                  if (parsedTags.audioCodec != null) ...[
                                    _buildPillTag(theme, isDark, parsedTags.audioCodec!),
                                    const SizedBox(width: 5),
                                  ],

                                  if (parsedTags.isDualAudio) ...[
                                    _buildIconPillTag(
                                      theme,
                                      isDark,
                                      AppIcons.mic(iconPack),
                                      l10n.originalPlusDub,
                                    ),
                                    const SizedBox(width: 5),
                                  ],

                                  if (parsedTags.isMultiSubs) ...[
                                    _buildIconPillTag(
                                      theme,
                                      isDark,
                                      AppIcons.chatBubble(iconPack),
                                      l10n.multiSubs,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                ],
                              ),
                            ],

                            const SizedBox(height: 4),

                            // Row 3: Seeders, Size, Date
                            Row(
                              children: [
                                Icon(
                                  AppIcons.sensors(iconPack),
                                  size: 13,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${torrent.seeders} ${l10n.sortSeeders.toLowerCase()}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                  ),
                                ),

                                _buildBullet(theme),

                                Text(
                                  torrent.formattedSize,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),

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

                                if (isBest) ...[
                                  _buildBullet(theme),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(AppIcons.star(iconPack), size: 13, color: Colors.amber),
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
              );
            },
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
