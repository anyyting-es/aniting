import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EpisodePlaybackProgress {
  final int mediaId;
  final int episodeNumber;
  final int positionMs;
  final int durationMs;
  final int updatedAt;

  const EpisodePlaybackProgress({
    required this.mediaId,
    required this.episodeNumber,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  double get fraction {
    if (durationMs <= 0 || positionMs <= 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'episodeNumber': episodeNumber,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt,
      };

  factory EpisodePlaybackProgress.fromJson(Map<String, dynamic> json) =>
      EpisodePlaybackProgress(
        mediaId: json['mediaId'] as int? ?? 0,
        episodeNumber: json['episodeNumber'] as int? ?? 1,
        positionMs: json['positionMs'] as int? ?? 0,
        durationMs: json['durationMs'] as int? ?? 0,
        updatedAt: json['updatedAt'] as int? ?? 0,
      );
}

class PlaybackProgressNotifier
    extends Notifier<Map<String, EpisodePlaybackProgress>> {
  static const String _storageKey = 'local_episode_playback_progress_v1';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  Map<String, EpisodePlaybackProgress> build() {
    if (_cachedPrefs != null) {
      final raw = _cachedPrefs!.getString(_storageKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(
                  k.toString(),
                  EpisodePlaybackProgress.fromJson(
                      v as Map<String, dynamic>),
                ));
          }
        } catch (_) {}
      }
    }
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          state = decoded.map((k, v) => MapEntry(
                k.toString(),
                EpisodePlaybackProgress.fromJson(
                    Map<String, dynamic>.from(v as Map)),
              ));
        }
      }
    } catch (e) {
      debugPrint('[PlaybackProgress] Error loading prefs: $e');
    }
  }

  Future<void> saveProgress({
    required int mediaId,
    required int episodeNumber,
    required int positionMs,
    required int durationMs,
  }) async {
    if (mediaId <= 0 || episodeNumber < 1) return;

    final item = EpisodePlaybackProgress(
      mediaId: mediaId,
      episodeNumber: episodeNumber,
      positionMs: positionMs,
      durationMs: durationMs,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final key = '${mediaId}_$episodeNumber';
    final mediaKey = mediaId.toString();

    final next = Map<String, EpisodePlaybackProgress>.from(state);
    next[key] = item;
    next[mediaKey] = item;
    state = next;

    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      final jsonMap = next.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_storageKey, jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('[PlaybackProgress] Error saving progress: $e');
    }
  }

  EpisodePlaybackProgress? getProgress(int mediaId, int episodeNumber) {
    final epProgress = state['${mediaId}_$episodeNumber'];
    if (epProgress != null) return epProgress;
    final mediaProgress = state[mediaId.toString()];
    if (mediaProgress != null && mediaProgress.episodeNumber == episodeNumber) {
      return mediaProgress;
    }
    return null;
  }

  /// Synchronizes server continuity watch history items into the local progress map.
  /// Server items that are newer or not present locally will update the progress map.
  Future<void> syncWithServerContinuity(Map<int, dynamic> serverHistory) async {
    if (serverHistory.isEmpty) return;

    final next = Map<String, EpisodePlaybackProgress>.from(state);
    bool changed = false;

    serverHistory.forEach((mediaId, raw) {
      if (raw is Map) {
        final epNum = (raw['episodeNumber'] as num?)?.toInt() ?? 1;
        final curSec = (raw['currentTime'] as num?)?.toDouble() ?? 0.0;
        final durSec = (raw['duration'] as num?)?.toDouble() ?? 0.0;
        if (curSec > 0 && durSec > 0) {
          final posMs = (curSec * 1000).toInt();
          final durMs = (durSec * 1000).toInt();
          final updatedStr = raw['timeUpdated']?.toString();
          final serverTs = updatedStr != null
              ? DateTime.tryParse(updatedStr)?.millisecondsSinceEpoch ?? 0
              : 0;

          final key = '${mediaId}_$epNum';
          final existing = next[key];
          // Update if no local progress or server timestamp is newer or further along
          if (existing == null || serverTs >= existing.updatedAt || posMs > existing.positionMs) {
            final item = EpisodePlaybackProgress(
              mediaId: mediaId,
              episodeNumber: epNum,
              positionMs: posMs,
              durationMs: durMs,
              updatedAt: serverTs > 0 ? serverTs : DateTime.now().millisecondsSinceEpoch,
            );
            next[key] = item;
            next[mediaId.toString()] = item;
            changed = true;
          }
        }
      }
    });

    if (changed) {
      state = next;
      try {
        final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
        final jsonMap = next.map((k, v) => MapEntry(k, v.toJson()));
        await prefs.setString(_storageKey, jsonEncode(jsonMap));
      } catch (e) {
        debugPrint('[PlaybackProgress] Error syncing with server continuity: $e');
      }
    }
  }
}

final playbackProgressPreferencesProvider = NotifierProvider<
    PlaybackProgressNotifier, Map<String, EpisodePlaybackProgress>>(
  PlaybackProgressNotifier.new,
);
