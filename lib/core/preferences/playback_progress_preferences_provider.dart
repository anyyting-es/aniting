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
    return state['${mediaId}_$episodeNumber'] ?? state[mediaId.toString()];
  }
}

final playbackProgressPreferencesProvider = NotifierProvider<
    PlaybackProgressNotifier, Map<String, EpisodePlaybackProgress>>(
  PlaybackProgressNotifier.new,
);
