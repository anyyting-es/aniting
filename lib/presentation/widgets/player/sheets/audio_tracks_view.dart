import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Subview for selecting the active audio track.
class AudioTracksView extends ConsumerWidget {
  final List<UiTrack> tracks;
  final String? selectedTrackId;
  final ValueChanged<UiTrack> onTrackSelected;

  const AudioTracksView({
    super.key,
    required this.tracks,
    required this.selectedTrackId,
    required this.onTrackSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    if (tracks.isEmpty) {
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
            l10n.noAudioTracks,
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
          itemCount: tracks.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isSelected = track.id == selectedTrackId;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTrackSelected(track),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.audio(iconPack),
                        size: 18,
                        color: isSelected ? primaryColor : Colors.white60,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            if (track.language.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  track.language.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? primaryColor : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(AppIcons.check(iconPack), color: primaryColor, size: 18),
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
