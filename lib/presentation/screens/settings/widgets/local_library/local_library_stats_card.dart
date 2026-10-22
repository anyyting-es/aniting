import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/providers/local_library_provider.dart';

class LocalLibraryStatsCard extends ConsumerWidget {
  final LocalLibraryState state;

  const LocalLibraryStatsCard({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder_copy_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.libraryStatsSection,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              isCompact
                  ? Column(
                      children: [
                        _StatItem(
                          icon: Icons.movie_outlined,
                          label: l10n.matchedShowsCount,
                          value: '${state.matchedShowsCount}',
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        _StatItem(
                          icon: Icons.video_file_outlined,
                          label: l10n.localEpisodesCount,
                          value: '${state.localEpisodesCount}',
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 10),
                        _StatItem(
                          icon: Icons.help_outline_rounded,
                          label: l10n.unmatchedFilesCount,
                          value: '${state.unmatchedFilesCount}',
                          color: state.unmatchedFilesCount > 0
                              ? const Color(0xFFF59E0B)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            icon: Icons.movie_outlined,
                            label: l10n.matchedShowsCount,
                            value: '${state.matchedShowsCount}',
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Container(
                          height: 38,
                          width: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.video_file_outlined,
                            label: l10n.localEpisodesCount,
                            value: '${state.localEpisodesCount}',
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        Container(
                          height: 38,
                          width: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.help_outline_rounded,
                            label: l10n.unmatchedFilesCount,
                            value: '${state.unmatchedFilesCount}',
                            color: state.unmatchedFilesCount > 0
                                ? const Color(0xFFF59E0B)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
              if (state.tvShowsCount > 0 || state.moviesCount > 0) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _BreakdownChip(
                      icon: Icons.animation_rounded,
                      label: 'Anime: ${state.animeCount}',
                      color: theme.colorScheme.primary,
                    ),
                    _BreakdownChip(
                      icon: Icons.tv_rounded,
                      label: 'TV: ${state.tvShowsCount}',
                      color: const Color(0xFF6366F1),
                    ),
                    _BreakdownChip(
                      icon: Icons.movie_creation_outlined,
                      label: 'Movies: ${state.moviesCount}',
                      color: const Color(0xFFEC4899),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BreakdownChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
