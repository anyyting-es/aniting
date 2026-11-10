import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/track_preferences_provider.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';

/// Helper utility for matching and auto-selecting saved and preferred audio/subtitle tracks.
class PlayerTrackMatcher {
  /// Builds a unique persistent key for the current video item.
  static String makeVideoKey({
    required int? mediaId,
    required int? episodeNumber,
    required String videoUrl,
  }) {
    if (mediaId != null && episodeNumber != null) {
      return '${mediaId}_$episodeNumber';
    }
    if (videoUrl.isNotEmpty) {
      return 'url_${videoUrl.hashCode}';
    }
    return '';
  }

  /// Finds preferred or saved audio track from preference or language.
  static UiTrack? matchAudioTrack({
    required List<UiTrack> audioList,
    required SavedTrackPreference? preference,
  }) {
    if (preference?.audioTrackId != null) {
      return audioList.where((t) => t.id == preference!.audioTrackId).firstOrNull ??
          (preference?.audioLanguage != null
              ? audioList
                  .where(
                    (t) =>
                        t.language.toLowerCase() ==
                        preference!.audioLanguage!.toLowerCase(),
                  )
                  .firstOrNull
              : null);
    }
    return null;
  }

  /// Determines which subtitle track should be selected, or null if subtitles should be turned off.
  static ({bool shouldChange, UiTrack? track}) matchSubtitleTrack({
    required List<UiTrack> subList,
    required SavedTrackPreference? preference,
    required String? currentSelectedSubtitleId,
    required AppLanguage appLanguage,
  }) {
    if (preference?.subtitleTrackId != null) {
      if (preference!.subtitleTrackId == 'off' || preference.subtitleTrackId == 'no') {
        return (shouldChange: true, track: null);
      }
      final target = subList.where((t) => t.id == preference.subtitleTrackId).firstOrNull ??
          (preference.subtitleLanguage != null
              ? subList
                  .where(
                    (t) =>
                        t.language.toLowerCase() ==
                        preference.subtitleLanguage!.toLowerCase(),
                  )
                  .firstOrNull
              : null);
      if (target != null && target.id != currentSelectedSubtitleId) {
        return (shouldChange: true, track: target);
      }
      return (shouldChange: false, track: null);
    }

    if (subList.isNotEmpty && currentSelectedSubtitleId == null) {
      final isSpanish = appLanguage == AppLanguage.es;
      UiTrack? matchedSub;
      if (isSpanish) {
        matchedSub = subList.where((t) {
          final l = t.language.toLowerCase();
          final title = t.title.toLowerCase();
          return l.contains('es') ||
              l.contains('spa') ||
              title.contains('esp') ||
              title.contains('spanish') ||
              title.contains('castellano') ||
              title.contains('latino') ||
              title.contains('español');
        }).firstOrNull;
      } else {
        matchedSub = subList.where((t) {
          final l = t.language.toLowerCase();
          final title = t.title.toLowerCase();
          return l.contains('en') ||
              l.contains('eng') ||
              title.contains('english');
        }).firstOrNull;
      }

      matchedSub ??= subList.first;
      return (shouldChange: true, track: matchedSub);
    }

    return (shouldChange: false, track: null);
  }
}
