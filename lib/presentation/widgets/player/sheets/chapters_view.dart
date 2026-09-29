import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Subview for selecting and jumping to a specific chapter/section in the media.
class ChaptersView extends ConsumerWidget {
  final List<PlayerChapter> chapters;
  final Duration currentPosition;
  final ValueChanged<PlayerChapter> onChapterSelected;

  const ChaptersView({
    super.key,
    required this.chapters,
    required this.currentPosition,
    required this.onChapterSelected,
  });

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  IconData _getChapterIcon(PlayerChapter chapter, [AppIconPack? pack]) {
    if (chapter.isOpening) return AppIcons.music(pack);
    if (chapter.isEnding) return AppIcons.musicQueue(pack);
    if (chapter.isCredits) return AppIcons.movie(pack);
    if (chapter.isIntro) return AppIcons.fastForward(pack);
    return AppIcons.bookmark(pack);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    if (chapters.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151518),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Text(
            l10n.noChapters,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chapters.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            final isCurrent = currentPosition >= chapter.start &&
                (chapter.end == null || currentPosition < chapter.end!);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChapterSelected(chapter),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        _getChapterIcon(chapter, iconPack),
                        size: 18,
                        color: isCurrent ? primaryColor : Colors.white60,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          chapter.title,
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.white70,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isCurrent ? primaryColor : Colors.white)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatDuration(chapter.start),
                          style: TextStyle(
                            color: isCurrent ? primaryColor : Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

