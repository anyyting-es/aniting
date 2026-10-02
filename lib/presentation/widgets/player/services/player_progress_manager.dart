import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';

/// Service responsible for managing video playback progress, periodic continuity updates,
/// LastSession persistence, and automatic AniList watched progress synchronization.
class PlayerProgressManager {
  final SeanimeRepository repository;
  final LastSessionNotifier lastSessionNotifier;
  final PlaybackProgressNotifier? playbackProgressNotifier;
  final int? mediaId;
  final String title;
  final ValueGetter<String?> getCoverImage;
  final ValueGetter<String?> getCharacterImage;
  final ValueGetter<int?> getEpisodeNumber;
  final ValueGetter<String?> getEpisodeTitle;
  final ValueGetter<String?>? getEpisodeThumbnail;
  final ValueGetter<String> getVideoUrl;
  final ValueGetter<Map<String, String>?> getHeaders;
  final ValueGetter<String?> getMimeType;
  final ValueGetter<String?> getVideoSource;
  final ValueGetter<Duration> getPosition;
  final ValueGetter<Duration> getDuration;
  final ValueGetter<bool> getIsPlaying;
  final ValueGetter<int?> getTotalEpisodes;
  final ValueGetter<String?>? getBannerImage;
  final ValueGetter<String?>? getCoverColor;
  final ValueGetter<List<String>?>? getGenres;
  final ValueGetter<double?>? getScore;
  final ValueGetter<String?>? getDescription;
  final ValueGetter<int?>? getYear;
  final ValueGetter<String?>? getFormat;
  final VoidCallback? onProgressSynced;
  final VoidCallback? onLocalWatchRecorded;

  Timer? _continuityTimer;
  bool _hasUpdatedAnimeProgress = false;

  PlayerProgressManager({
    required this.repository,
    required this.lastSessionNotifier,
    this.playbackProgressNotifier,
    required this.mediaId,
    required this.title,
    required this.getCoverImage,
    required this.getCharacterImage,
    required this.getEpisodeNumber,
    required this.getEpisodeTitle,
    this.getEpisodeThumbnail,
    required this.getVideoUrl,
    required this.getHeaders,
    required this.getMimeType,
    required this.getVideoSource,
    required this.getPosition,
    required this.getDuration,
    required this.getIsPlaying,
    required this.getTotalEpisodes,
    this.getBannerImage,
    this.getCoverColor,
    this.getGenres,
    this.getScore,
    this.getDescription,
    this.getYear,
    this.getFormat,
    this.onProgressSynced,
    this.onLocalWatchRecorded,
  });

  /// Starts periodic continuity tracking every 20 seconds while playing.
  void startTracking({Duration? initialPosition}) {
    if (mediaId == null) return;

    final initialSec = (initialPosition?.inSeconds ?? 0).toDouble();
    repository.updateContinuityItem(
      mediaId: mediaId!,
      episodeNumber: getEpisodeNumber() ?? 1,
      currentTime: initialSec,
      duration: 0.0,
    );

    savePlaybackProgress();

    _continuityTimer?.cancel();
    _continuityTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (getIsPlaying()) {
        savePlaybackProgress();
      }
    });
  }

  /// Resets the AniList watched sync latch for a newly switched episode.
  void resetEpisodeLatch() {
    _hasUpdatedAnimeProgress = false;
  }

  /// Saves the current playback progress both to the server continuity item
  /// and local LastSessionItem.
  void savePlaybackProgress() {
    if (mediaId == null) return;

    final pos = getPosition();
    final dur = getDuration();
    final epNum = getEpisodeNumber() ?? 1;

    try {
      repository.updateContinuityItem(
        mediaId: mediaId!,
        episodeNumber: epNum,
        currentTime: pos.inSeconds.toDouble(),
        duration: dur.inSeconds.toDouble(),
      );

      final sessionItem = LastSessionItem(
        mediaType: 'ANIME',
        mediaId: mediaId!,
        title: title,
        coverImage: getCoverImage(),
        characterImage: getCharacterImage(),
        episodeNumber: epNum,
        episodeTitle: getEpisodeTitle(),
        videoUrl: getVideoUrl(),
        headers: getHeaders(),
        mimeType: getMimeType(),
        videoSource: getVideoSource(),
        positionMs: pos.inMilliseconds,
        durationMs: dur.inMilliseconds,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      Future.microtask(() async {
        lastSessionNotifier.saveSession(sessionItem);
        playbackProgressNotifier?.saveProgress(
          mediaId: mediaId!,
          episodeNumber: epNum,
          positionMs: pos.inMilliseconds,
          durationMs: dur.inMilliseconds,
        );

        await OfflineLibraryService.instance.recordAnimeWatch(
          mediaId: mediaId!,
          title: title,
          episodeNumber: epNum,
          episodeTitle: getEpisodeTitle(),
          episodeThumbnail: getEpisodeThumbnail?.call(),
          coverImage: getCoverImage(),
          bannerImage: getBannerImage?.call(),
          characterImage: getCharacterImage(),
          totalEpisodes: getTotalEpisodes(),
          genres: getGenres?.call(),
          score: getScore?.call(),
          format: getFormat?.call(),
          description: getDescription?.call(),
          coverColor: getCoverColor?.call(),
          year: getYear?.call(),
        );

        onLocalWatchRecorded?.call();
      });
    } catch (e) {
      debugPrint('[PlayerProgressManager] Error saving progress: $e');
    }
  }

  /// Checks whether playback has passed the threshold to sync with AniList
  /// (~80% watched OR within 120s of end with >=120s watched).
  void syncAnimeProgressIfNeeded() {
    if (_hasUpdatedAnimeProgress) return;
    if (mediaId == null) return;

    final epNum = getEpisodeNumber();
    if (epNum == null || epNum < 1) return;

    final durSec = getDuration().inSeconds;
    final posSec = getPosition().inSeconds;
    if (durSec <= 0 || posSec <= 0) return;

    final fraction = posSec / durSec;
    final remaining = durSec - posSec;
    final isNearEnd = fraction >= 0.80 || (posSec >= 120 && remaining <= 120);

    if (!isNearEnd) return;

    _hasUpdatedAnimeProgress = true;

    OfflineLibraryService.instance.updateAnimeProgress(
      mediaId: mediaId!,
      episodeNumber: epNum,
      totalEpisodes: getTotalEpisodes(),
    );

    repository
        .updateAnimeProgress(
      mediaId: mediaId!,
      episodeNumber: epNum,
      totalEpisodes: getTotalEpisodes(),
    )
        .then((_) {
      onProgressSynced?.call();
    }).catchError((e) {
      debugPrint('[PlayerProgressManager] Error syncing AniList progress: $e');
      // Even if AniList remote sync fails, local progress succeeded
      onProgressSynced?.call();
    });
  }

  /// Disposes timers and performs final progress flush.
  void dispose() {
    _continuityTimer?.cancel();
    try {
      savePlaybackProgress();
    } catch (_) {}
    try {
      syncAnimeProgressIfNeeded();
    } catch (_) {}
  }
}
