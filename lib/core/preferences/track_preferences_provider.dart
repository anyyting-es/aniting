import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedTrackPreference {
  final String? audioTrackId;
  final String? audioLanguage;
  final String? subtitleTrackId;
  final String? subtitleLanguage;

  const SavedTrackPreference({
    this.audioTrackId,
    this.audioLanguage,
    this.subtitleTrackId,
    this.subtitleLanguage,
  });

  Map<String, dynamic> toJson() => {
        if (audioTrackId != null) 'audioTrackId': audioTrackId,
        if (audioLanguage != null) 'audioLanguage': audioLanguage,
        if (subtitleTrackId != null) 'subtitleTrackId': subtitleTrackId,
        if (subtitleLanguage != null) 'subtitleLanguage': subtitleLanguage,
      };

  factory SavedTrackPreference.fromJson(Map<String, dynamic> json) =>
      SavedTrackPreference(
        audioTrackId: json['audioTrackId'] as String?,
        audioLanguage: json['audioLanguage'] as String?,
        subtitleTrackId: json['subtitleTrackId'] as String?,
        subtitleLanguage: json['subtitleLanguage'] as String?,
      );

  SavedTrackPreference copyWith({
    String? audioTrackId,
    String? audioLanguage,
    String? subtitleTrackId,
    String? subtitleLanguage,
    bool clearSubtitle = false,
  }) {
    return SavedTrackPreference(
      audioTrackId: audioTrackId ?? this.audioTrackId,
      audioLanguage: audioLanguage ?? this.audioLanguage,
      subtitleTrackId: clearSubtitle ? 'off' : (subtitleTrackId ?? this.subtitleTrackId),
      subtitleLanguage: clearSubtitle ? null : (subtitleLanguage ?? this.subtitleLanguage),
    );
  }
}

class TrackPreferencesNotifier
    extends Notifier<Map<String, SavedTrackPreference>> {
  static const String _storageKey = 'local_video_track_preferences_v1';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  Map<String, SavedTrackPreference> build() {
    if (_cachedPrefs != null) {
      final raw = _cachedPrefs!.getString(_storageKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(
                  k.toString(),
                  SavedTrackPreference.fromJson(
                      Map<String, dynamic>.from(v as Map)),
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
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          state = decoded.map((k, v) => MapEntry(
                k.toString(),
                SavedTrackPreference.fromJson(
                    Map<String, dynamic>.from(v as Map)),
              ));
        }
      }
    } catch (e) {
      debugPrint('[TrackPreferences] Error loading prefs: $e');
    }
  }

  SavedTrackPreference? getPreference(String videoKey) {
    return state[videoKey];
  }

  Future<void> saveAudioTrack(
    String videoKey, {
    required String id,
    String? language,
  }) async {
    if (videoKey.isEmpty) return;
    final current = state[videoKey] ?? const SavedTrackPreference();
    final updated = current.copyWith(
      audioTrackId: id,
      audioLanguage: language,
    );
    final newState = Map<String, SavedTrackPreference>.from(state)..[videoKey] = updated;
    state = newState;
    await _persist();
  }

  Future<void> saveSubtitleTrack(
    String videoKey, {
    required String? id,
    String? language,
  }) async {
    if (videoKey.isEmpty) return;
    final current = state[videoKey] ?? const SavedTrackPreference();
    final updated = current.copyWith(
      subtitleTrackId: id ?? 'off',
      subtitleLanguage: language,
      clearSubtitle: id == null || id == 'off' || id == 'no',
    );
    final newState = Map<String, SavedTrackPreference>.from(state)..[videoKey] = updated;
    state = newState;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      final jsonMap = state.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_storageKey, jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('[TrackPreferences] Error persisting prefs: $e');
    }
  }
}

final trackPreferencesProvider =
    NotifierProvider<TrackPreferencesNotifier, Map<String, SavedTrackPreference>>(
  TrackPreferencesNotifier.new,
);
