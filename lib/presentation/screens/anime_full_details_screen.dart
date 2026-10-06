import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';

class AnimeFullDetailsScreen extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeDetails? animeDetails;

  const AnimeFullDetailsScreen({
    super.key,
    required this.mediaId,
    this.animeDetails,
  });

  @override
  ConsumerState<AnimeFullDetailsScreen> createState() => _AnimeFullDetailsScreenState();
}

class _AnimeFullDetailsScreenState extends ConsumerState<AnimeFullDetailsScreen> {
  AnimeDetails? _details;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _details = widget.animeDetails;
    if (_details == null) {
      _loadDetails();
    }
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final details = await repo.getAnimeDetails(widget.mediaId);
      if (mounted) setState(() => _details = details);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
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
          appBarTheme: baseTheme.appBarTheme.copyWith(
            backgroundColor: isOled ? Colors.black : colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
          ),
        );
      }
    }

    return Theme(
      data: effectiveTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colors = context.themeColors;
          final borderRadius = colors.borderRadius;
          final titleLang = ref.watch(titleLanguageProvider);
          final l10n = ref.watch(translationsProvider);

          final title = _details?.displayTitle(titleLang) ?? l10n.animeDetails;
          final coverUrl = _details?.coverImage;
          final bannerUrl = _details?.bannerImage ?? coverUrl;
          final description = _cleanHtml(_details?.description);

          final raw = _details?.rawMedia ?? {};
          final charactersEdges = (raw['characters']?['edges'] as List?) ?? [];
          final relationsEdges = (raw['relations']?['edges'] as List?) ?? [];
          final staffEdges = (raw['staff']?['edges'] as List?) ?? [];
          final rankings = (raw['rankings'] as List?) ?? [];
          final duration = _details?.rawMedia?['duration'] as int?;
          final meanScore = _details?.rawMedia?['meanScore'] as int?;

          return Scaffold(
            appBar: DesktopSafeAppBar(
              child: AppBar(
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
      body: _isLoading && _details == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // Banner & Poster Header
                Stack(
                  children: [
                    // Banner Image
                    if (bannerUrl != null)
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          memCacheWidth: 800, memCacheHeight: 400, maxWidthDiskCache: 1200, maxHeightDiskCache: 600,
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              Container(color: theme.colorScheme.surfaceContainerHighest),
                        ),
                      )
                    else
                      Container(
                        height: 180,
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                    // Gradient Fade
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                              theme.scaffoldBackgroundColor,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Poster + Titles
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (coverUrl != null)
                            Container(
                              width: 100,
                              height: 145,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(borderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CachedNetworkImage(
                                memCacheWidth: 250, memCacheHeight: 360, maxWidthDiskCache: 400, maxHeightDiskCache: 580,
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
                                    fontSize: 17,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_details?.romajiTitle != null && _details!.romajiTitle != title) ...[
                                  const SizedBox(height: 2),
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
                                if (_details?.nativeTitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _details!.nativeTitle!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (_details?.studio != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${l10n.studio}: ${_details!.studio!}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Key Info & Stats Badges
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceAround,
                        children: [
                          if (_details?.score != null && _details!.score! > 0)
                            _buildStatItem(
                              theme,
                              icon: Icons.star_rounded,
                              iconColor: Colors.amber,
                              label: l10n.averageScore,
                              value: '${_details!.score!.toStringAsFixed(0)}%',
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
                              value: l10n.formatStatus(_details!.status!),
                            ),
                          if (_details?.season != null || _details?.seasonYear != null)
                            _buildStatItem(
                              theme,
                              icon: Icons.calendar_month_rounded,
                              iconColor: theme.colorScheme.primary,
                              label: l10n.season,
                              value: '${l10n.formatSeason(_details?.season)} ${_details?.seasonYear ?? ""}'.trim(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Genres
                if (_details?.genres.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _details!.genres.map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            g,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 16),

                // Synopsis
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.synopsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Rankings (if available)
                if (rankings.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.rankings,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...rankings.take(4).map((r) {
                          if (r is! Map<String, dynamic>) return const SizedBox.shrink();
                          final rank = r['rank'] ?? '';
                          final contextStr = r['context'] ?? '';
                          final year = r['year'] != null ? ' (${r['year']})' : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, size: 16, color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '#$rank $contextStr$year',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                // Relations (Sequels, Prequels, Spin-offs, etc.)
                if (relationsEdges.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.relations,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 170,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: relationsEdges.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) {
                        final edge = relationsEdges[i] as Map<String, dynamic>?;
                        if (edge == null) return const SizedBox.shrink();
                        final relationType = l10n.formatRelationType(edge['relationType'] as String?);
                        final node = edge['node'] as Map<String, dynamic>?;
                        if (node == null) return const SizedBox.shrink();

                        final relId = node['id'] as int? ?? 0;
                        final relTitleMap = node['title'] as Map<String, dynamic>?;
                        final relTitle = relTitleMap?['userPreferred'] ??
                            relTitleMap?['romaji'] ??
                            relTitleMap?['english'] ??
                            l10n.noTitle;
                        final relCover = (node['coverImage'] as Map<String, dynamic>?)?['large'] ??
                            (node['coverImage'] as Map<String, dynamic>?)?['medium'];
                        final relFormat = node['format'] as String? ?? '';

                        return InkWell(
                          borderRadius: BorderRadius.circular(borderRadius),
                          onTap: relId > 0
                              ? () {
                                  AnimeDetailScreen.navigate(context, mediaId: relId);
                                }
                              : null,
                          child: SizedBox(
                            width: 100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(borderRadius),
                                      child: SizedBox(
                                        width: 100,
                                        height: 120,
                                        child: relCover != null
                                            ? CachedNetworkImage(
                                                memCacheWidth: 250, memCacheHeight: 300, maxWidthDiskCache: 400, maxHeightDiskCache: 480,
                                                imageUrl: relCover as String,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(color: theme.colorScheme.surfaceContainerHighest),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          relationType,
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimary,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (relFormat.isNotEmpty)
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.75),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            relFormat,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  relTitle as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Characters & Seiyuus (Voice Actors)
                if (charactersEdges.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.characters,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: charactersEdges.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) {
                        final edge = charactersEdges[i] as Map<String, dynamic>?;
                        if (edge == null) return const SizedBox.shrink();
                        final role = edge['role'] as String? ?? '';
                        final node = edge['node'] as Map<String, dynamic>?;
                        if (node == null) return const SizedBox.shrink();

                        final nameMap = node['name'] as Map<String, dynamic>?;
                        final charName = nameMap?['full'] ?? l10n.character;
                        final charImage = (node['image'] as Map<String, dynamic>?)?['large'];

                        return SizedBox(
                          width: 90,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(borderRadius),
                                child: SizedBox(
                                  width: 80,
                                  height: 105,
                                  child: charImage != null
                                      ? CachedNetworkImage(
                                          memCacheWidth: 200, memCacheHeight: 260, maxWidthDiskCache: 320, maxHeightDiskCache: 420,
                                          imageUrl: charImage as String,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(color: theme.colorScheme.surfaceContainerHighest),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                charName as String,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              if (role.isNotEmpty)
                                Text(
                                  role == 'MAIN' ? l10n.mainRole : l10n.supportingRole,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: role == 'MAIN'
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: role == 'MAIN' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Key Staff (Director, Music, Creator, etc.)
                if (staffEdges.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.staff,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: staffEdges.take(10).map((s) {
                        if (s is! Map<String, dynamic>) return const SizedBox.shrink();
                        final role = s['role'] as String? ?? 'Staff';
                        final node = s['node'] as Map<String, dynamic>?;
                        final staffName = (node?['name'] as Map<String, dynamic>?)?['full'] ?? '';
                        if (staffName.isEmpty) return const SizedBox.shrink();

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                role,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                staffName,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
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
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
