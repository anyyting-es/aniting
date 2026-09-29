import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_full_details_screen.dart';

class AnimeDetailsModalSheet extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeDetails? animeDetails;

  const AnimeDetailsModalSheet({
    super.key,
    required this.mediaId,
    this.animeDetails,
  });

  static Future<void> show({
    required BuildContext context,
    required int mediaId,
    AnimeDetails? animeDetails,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimeDetailsModalSheet(
        mediaId: mediaId,
        animeDetails: animeDetails,
      ),
    );
  }

  @override
  ConsumerState<AnimeDetailsModalSheet> createState() =>
      _AnimeDetailsModalSheetState();
}

class _AnimeDetailsModalSheetState extends ConsumerState<AnimeDetailsModalSheet> {
  AnimeDetails? _details;
  bool _isLoading = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _details = widget.animeDetails;
    if (_details == null || _details?.rawMedia == null) {
      _fetchDetails();
    }
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    final repo = ref.read(repositoryProvider);
    final result = await repo.getAnimeDetails(widget.mediaId);
    if (mounted) {
      setState(() {
        _details = result ?? _details;
        _isLoading = false;
      });
    }
  }

  String _cleanHtml(String? text) {
    if (text == null) return '';
    return text
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final hexColor = _details?.coverColor;

    final baseTheme = Theme.of(context);
    ThemeData effectiveTheme = baseTheme;
    if (themeSettings.animeDynamicTheme && hexColor != null) {
      final parsedColor = parseHexColor(hexColor);
      if (parsedColor != null) {
        final isDark = baseTheme.brightness == Brightness.dark;
        final isOled = themeSettings.isOled && isDark;
        final colorScheme = ColorScheme.fromSeed(
          seedColor: parsedColor,
          brightness: baseTheme.brightness,
          surface: isOled ? Colors.black : null,
        );
        effectiveTheme = baseTheme.copyWith(
          colorScheme: colorScheme,
          scaffoldBackgroundColor: isOled ? Colors.black : colorScheme.surface,
        );
      }
    }

    return Theme(
      data: effectiveTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final titleLang = ref.watch(titleLanguageProvider);
          final l10n = ref.watch(translationsProvider);
          final screenHeight = MediaQuery.of(context).size.height;

          final targetHeight = _isFullScreen ? screenHeight : (screenHeight * 0.80);
          final title = _details?.displayTitle(titleLang) ?? l10n.animeDetails;
          final coverUrl = _details?.coverImage;
          final description = _cleanHtml(_details?.description);

          final raw = _details?.rawMedia ?? {};
          final charactersEdges = (raw['characters']?['edges'] as List?) ?? [];
          final relationsEdges = (raw['relations']?['edges'] as List?) ?? [];
          final staffEdges = (raw['staff']?['edges'] as List?) ?? [];
          final rankings = (raw['rankings'] as List?) ?? [];
          final duration = raw['duration'] as int?;
          final meanScore = raw['meanScore'] as int?;

          return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      height: targetHeight,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_isFullScreen ? 0 : 22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        top: _isFullScreen,
        bottom: false,
        child: Column(
          children: [
            // Top Drag Handle (when not fullscreen)
            if (!_isFullScreen)
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Modal Header with Title, Fullscreen Toggle, and Close
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFullScreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      size: 24,
                    ),
                    tooltip: _isFullScreen
                        ? l10n.reduceToModal
                        : l10n.fullScreen,
                    onPressed: () {
                      setState(() {
                        _isFullScreen = !_isFullScreen;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: _isLoading && _details == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                      children: [
                        // Poster + Header Details Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (coverUrl != null)
                              Container(
                                width: 90,
                                height: 130,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: CachedNetworkImage(
                                  memCacheWidth: 175, memCacheHeight: 250, maxWidthDiskCache: 280, maxHeightDiskCache: 400,
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_details?.romajiTitle != null &&
                                      _details!.romajiTitle != title) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      _details!.romajiTitle!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (_details?.studio != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${l10n.studio}: ${_details!.studio!}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  // Open in Full Details Page Button
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 15),
                                    label: Text(l10n.viewExtendedDetails,
                                        style: const TextStyle(fontSize: 11.5)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AnimeFullDetailsScreen(
                                            mediaId: widget.mediaId,
                                            animeDetails: _details,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Key Info Badges Card
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              alignment: WrapAlignment.spaceAround,
                              children: [
                                if (_details?.score != null &&
                                    _details!.score! > 0)
                                  _buildStatItem(
                                    theme,
                                    icon: Icons.star_rounded,
                                    iconColor: theme.colorScheme.primary,
                                    label: l10n.averageScore,
                                    value:
                                        '${_details!.score!.toStringAsFixed(0)}%',
                                  ),
                                if (meanScore != null && meanScore > 0)
                                  _buildStatItem(
                                    theme,
                                    icon: Icons.analytics_outlined,
                                    iconColor: theme.colorScheme.primary,
                                    label: l10n.anilistMean,
                                    value: '$meanScore%',
                                  ),
                                if (_details?.format != null)
                                  _buildStatItem(
                                    theme,
                                    icon: Icons.tv_rounded,
                                    iconColor: theme.colorScheme.primary,
                                    label: l10n.format,
                                    value: _details!.format!,
                                  ),
                                if (_details?.totalEpisodes != null)
                                  _buildStatItem(
                                    theme,
                                    icon: Icons.video_collection_outlined,
                                    iconColor: theme.colorScheme.primary,
                                    label: l10n.episodes,
                                    value: '${_details!.totalEpisodes}',
                                  ),
                                if (duration != null && duration > 0)
                                  _buildStatItem(
                                    theme,
                                    icon: Icons.schedule_rounded,
                                    iconColor: theme.colorScheme.primary,
                                    label: l10n.durationPerEp,
                                    value: '$duration min',
                                  ),
                                if (_details?.status != null)
                                  _buildStatItem(
                                    theme,
                                    icon: Icons.info_outline_rounded,
                                    iconColor: theme.colorScheme.primary,
                                    label: l10n.status,
                                    value: l10n.formatStatus(_details!.status),
                                  ),
                                if (_details?.season != null ||
                                    _details?.seasonYear != null)
                                  _buildStatItem(
                                    theme,
                                    icon: Icons.calendar_month_rounded,
                                    iconColor: theme.colorScheme.primary,
                                    label: l10n.season,
                                    value:
                                        '${l10n.formatSeason(_details?.season)} ${_details?.seasonYear ?? ""}'
                                            .trim(),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Genres
                        if (_details?.genres.isNotEmpty == true) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _details!.genres.map((g) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  g,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Synopsis
                        if (description.isNotEmpty) ...[
                          Text(
                            l10n.synopsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Rankings & Stats
                        if (rankings.isNotEmpty) ...[
                          Text(
                            l10n.rankings,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...rankings.take(4).map((r) {
                            if (r is! Map<String, dynamic>) {
                              return const SizedBox.shrink();
                            }
                            final rank = r['rank'] ?? '';
                            final contextStr = r['context'] ?? '';
                            final year =
                                r['year'] != null ? ' (${r['year']})' : '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.emoji_events_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '#$rank $contextStr$year',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 20),
                        ],

                        // Relations / Connected Works
                        if (relationsEdges.isNotEmpty) ...[
                          Text(
                            l10n.relations,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 155,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: relationsEdges.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final edge = relationsEdges[index];
                                final node = edge['node'] as Map<String, dynamic>? ?? {};
                                final relType = edge['relationType'] as String?;
                                final relTitle =
                                    node['title']?['userPreferred'] ??
                                    node['title']?['romaji'] ??
                                    l10n.noTitle;
                                final relCover =
                                    node['coverImage']?['large'] ??
                                    node['coverImage']?['medium'];

                                return SizedBox(
                                  width: 95,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: relCover != null
                                            ? CachedNetworkImage(
                                                memCacheWidth: 240, memCacheHeight: 260, maxWidthDiskCache: 380, maxHeightDiskCache: 420,
                                                imageUrl: relCover,
                                                height: 105,
                                                width: 95,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                height: 105,
                                                width: 95,
                                                color: theme.colorScheme
                                                    .surfaceContainerHighest,
                                                child: const Icon(
                                                    Icons.movie_outlined),
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.formatRelationType(relType),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        relTitle,
                                        style: const TextStyle(fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Characters and Cast
                        if (charactersEdges.isNotEmpty) ...[
                          Text(
                            l10n.characters,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 140,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: charactersEdges.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final edge = charactersEdges[index];
                                final charNode = edge['node'] as Map<String, dynamic>? ?? {};
                                final charName =
                                    charNode['name']?['full'] ??
                                    charNode['name']?['userPreferred'] ??
                                    l10n.character;
                                final charImage =
                                    charNode['image']?['medium'] ??
                                    charNode['image']?['large'];
                                final role = edge['role'] as String?;

                                return SizedBox(
                                  width: 80,
                                  child: Column(
                                    children: [
                                      ClipOval(
                                        child: charImage != null
                                            ? CachedNetworkImage(
                                                memCacheWidth: 150, memCacheHeight: 150, maxWidthDiskCache: 240, maxHeightDiskCache: 240,
                                                imageUrl: charImage,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                width: 60,
                                                height: 60,
                                                color: theme.colorScheme
                                                    .surfaceContainerHighest,
                                                child: const Icon(
                                                    Icons.person_rounded),
                                              ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        charName,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        role == 'MAIN'
                                            ? l10n.mainRole
                                            : l10n.supportingRole,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Staff
                        if (staffEdges.isNotEmpty) ...[
                          Text(
                            l10n.staff,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...staffEdges.take(6).map((edge) {
                            if (edge is! Map<String, dynamic>) {
                              return const SizedBox.shrink();
                            }
                            final staffNode = edge['node'] as Map<String, dynamic>? ?? {};
                            final staffName =
                                staffNode['name']?['full'] ??
                                staffNode['name']?['userPreferred'] ??
                                '';
                            final role = edge['role'] ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.badge_outlined,
                                      size: 15,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$staffName ($role)',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
        },
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
