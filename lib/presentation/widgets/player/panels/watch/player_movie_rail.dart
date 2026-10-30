import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

/// Right-hand rail used for movies: instead of an episode list (which would be
/// empty) it shows the cast and related recommendations, so the column keeps
/// the same purpose and rhythm as the series view.
class PlayerMovieRail extends ConsumerWidget {
  final AnimeDetails? details;

  const PlayerMovieRail({super.key, this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    final isTmdb = details?.isTmdb ?? false;
    final cast = _resolveCast(details);
    final recommendations = _resolveRecommendations(details);

    if (cast.isEmpty && recommendations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.loading,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cast.isNotEmpty) ...[
          _SectionTitle(
            icon: AppIcons.profile(ref.watch(iconPackProvider)),
            label: isTmdb ? l10n.cast : l10n.characters,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < cast.length && i < 10; i++)
            _FadeSlideIn(index: i, child: _CastTile(member: cast[i])),
        ],
        if (recommendations.isNotEmpty) ...[
          if (cast.isNotEmpty) const SizedBox(height: 26),
          _SectionTitle(
            icon: AppIcons.grid(ref.watch(iconPackProvider)),
            label: l10n.recommendations,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < recommendations.length && i < 8; i++)
            _FadeSlideIn(
              index: i,
              child: _RecommendationTile(
                item: recommendations[i],
                isTmdb: isTmdb,
                onTap: recommendations[i].mediaId == null
                    ? null
                    : () => AnimeDetailScreen.navigate(
                        context,
                        mediaId: recommendations[i].mediaId!,
                        isTmdb: isTmdb,
                      ),
              ),
            ),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────── Model helpers

class _CastMember {
  final String name;
  final String? role;
  final String? imageUrl;

  const _CastMember({required this.name, this.role, this.imageUrl});
}

class _RecommendationItem {
  final int? mediaId;
  final String title;
  final String? imageUrl;
  final int? year;
  final double? score;

  const _RecommendationItem({
    this.mediaId,
    required this.title,
    this.imageUrl,
    this.year,
    this.score,
  });
}

List<_CastMember> _resolveCast(AnimeDetails? details) {
  if (details == null) return const [];

  final isTmdb = details.isTmdb;
  final raw = details.rawMedia;
  final credits = raw?['credits'];
  final tmdbCast = credits is Map ? (credits['cast'] as List?) : null;

  final source = isTmdb && (tmdbCast?.isNotEmpty ?? false)
      ? tmdbCast!
      : details.characters;

  final result = <_CastMember>[];
  for (final item in source) {
    if (item is! Map) continue;
    if (isTmdb && !item.containsKey('node')) {
      final name = (item['name'] ?? item['original_name'] ?? '') as String;
      if (name.isEmpty) continue;
      final profilePath = item['profile_path'] as String?;
      result.add(
        _CastMember(
          name: name,
          role: item['character'] as String?,
          imageUrl: profilePath == null || profilePath.isEmpty
              ? null
              : 'https://image.tmdb.org/t/p/w185$profilePath',
        ),
      );
      continue;
    }

    final node = item['node'];
    if (node is! Map) continue;
    final nameMap = node['name'];
    final name =
        (nameMap is Map
                ? (nameMap['userPreferred'] ?? nameMap['full'])
                : nameMap)
            ?.toString() ??
        '';
    if (name.isEmpty) continue;

    final role = (item['role'] as String?)?.toUpperCase();
    String? voiceActor;
    final voiceActors = item['voiceActors'];
    if (voiceActors is List && voiceActors.isNotEmpty) {
      final first = voiceActors.first;
      if (first is Map) {
        final vaName = first['name'];
        voiceActor = (vaName is Map
                ? (vaName['userPreferred'] ?? vaName['full'])
                : vaName)
            ?.toString();
      }
    }

    final imageMap = node['image'];
    final image =
        imageMap is Map ? (imageMap['large'] ?? imageMap['medium']) : null;

    result.add(
      _CastMember(
        name: name,
        role: voiceActor ?? (role == 'MAIN' ? 'Principal' : null),
        imageUrl: image is String && image.isNotEmpty ? image : null,
      ),
    );
  }
  return result;
}

List<_RecommendationItem> _resolveRecommendations(AnimeDetails? details) {
  final raw = details?.rawMedia;
  if (raw == null) return const [];

  final container = raw['recommendations'];
  List<dynamic> edges = const [];
  if (container is Map) {
    edges =
        (container['edges'] as List?) ??
        (container['results'] as List?) ??
        (container['nodes'] as List?) ??
        const [];
  } else if (container is List) {
    edges = container;
  }

  final result = <_RecommendationItem>[];
  for (final item in edges) {
    if (item is! Map) continue;

    final node = item['node'] is Map ? item['node'] as Map : item;
    final titleMap = node['title'];
    final title =
        (titleMap is Map
                ? (titleMap['userPreferred'] ??
                      titleMap['english'] ??
                      titleMap['romaji'])
                : (node['title'] ?? node['name'] ?? node['original_title']))
            ?.toString() ??
        '';
    if (title.isEmpty) continue;

    final coverMap = node['coverImage'];
    final posterPath = node['poster_path'] as String?;
    final image = coverMap is Map
        ? (coverMap['large'] ?? coverMap['medium'])
        : (posterPath != null && posterPath.isNotEmpty
              ? 'https://image.tmdb.org/t/p/w342$posterPath'
              : null);

    final yearRaw =
        node['seasonYear'] ?? node['release_date'] ?? node['first_air_date'];
    final year = yearRaw is int
        ? yearRaw
        : int.tryParse(yearRaw?.toString().split('-').first ?? '');

    final scoreRaw = node['averageScore'] ?? node['vote_average'];
    final score = scoreRaw is num ? scoreRaw.toDouble() : null;

    result.add(
      _RecommendationItem(
        mediaId: node['id'] is int ? node['id'] as int : null,
        title: title,
        imageUrl: image is String && image.isNotEmpty ? image : null,
        year: year,
        score: score,
      ),
    );
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────── Widgets

/// Staggered mount animation for the rail tiles: each item fades in and lifts
/// a few pixels, delayed by its index so the list "cascades" instead of
/// popping in all at once.
class _FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _FadeSlideIn({required this.index, required this.child});

  static const int _stepMs = 45;
  static const int _baseMs = 240;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 9)) * _stepMs;
    final total = _baseMs + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CastTile extends ConsumerWidget {
  final _CastMember member;

  const _CastTile({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final iconPack = ref.watch(iconPackProvider);
    final imageUrl = member.imageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 42,
              height: 42,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              child: imageUrl == null
                  ? Icon(
                      AppIcons.profile(iconPack),
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 120),
                      errorWidget: (_, _, _) => Icon(
                        AppIcons.profile(iconPack),
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (member.role != null && member.role!.isNotEmpty)
                  Text(
                    member.role!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends ConsumerStatefulWidget {
  final _RecommendationItem item;
  final bool isTmdb;
  final VoidCallback? onTap;

  const _RecommendationTile({
    required this.item,
    required this.isTmdb,
    this.onTap,
  });

  @override
  ConsumerState<_RecommendationTile> createState() =>
      _RecommendationTileState();
}

class _RecommendationTileState extends ConsumerState<_RecommendationTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconPack = ref.watch(iconPackProvider);
    final item = widget.item;
    final isTmdb = widget.isTmdb;
    final onTap = widget.onTap;
    final imageUrl = item.imageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedScale(
          scale: _hovering ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _hovering
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    )
                  : Colors.transparent,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                hoverColor: Colors.transparent,
                onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 68,
                    child: imageUrl == null
                        ? ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            child: Icon(
                              AppIcons.grid(iconPack),
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 120),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.year != null) '${item.year}',
                          if (item.score != null)
                            isTmdb
                                ? item.score!.toStringAsFixed(1)
                                : '${item.score!.round()}%',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
        ),
      ),
    );
  }
}
