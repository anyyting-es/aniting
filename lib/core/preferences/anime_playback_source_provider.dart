import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents the persisted playback source configuration for a specific anime/media.
/// Remembers whether the user was watching via Local Library, Torrent Stream, or an
/// Online Stream provider (with provider id, sub/dub preference, and server).
class SavedPlaybackSource {
  final int mediaId;
  final String sourceType; // 'local', 'torrent', 'online'
  final String? onlineStreamProvider; // e.g. 'gogoanime', 'animepahe'
  final bool? onlineStreamDubbed;
  final String? onlineStreamServer;
  final String? videoSource; // e.g. "Gogoanime • HD", "Local • file.mkv"
  final String? videoUrl;
  final Map<String, String>? headers;
  final String? mimeType;
  final int? episodeNumber;
  final int updatedAt;

  const SavedPlaybackSource({
    required this.mediaId,
    required this.sourceType,
    this.onlineStreamProvider,
    this.onlineStreamDubbed,
    this.onlineStreamServer,
    this.videoSource,
    this.videoUrl,
    this.headers,
    this.mimeType,
    this.episodeNumber,
    required this.updatedAt,
  });

  bool get isLocal => sourceType == 'local';
  bool get isTorrent => sourceType == 'torrent';
  bool get isOnline => sourceType == 'online';

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'sourceType': sourceType,
        'onlineStreamProvider': onlineStreamProvider,
        'onlineStreamDubbed': onlineStreamDubbed,
        'onlineStreamServer': onlineStreamServer,
        'videoSource': videoSource,
        'videoUrl': videoUrl,
        'headers': headers,
        'mimeType': mimeType,
        'episodeNumber': episodeNumber,
        'updatedAt': updatedAt,
      };

  factory SavedPlaybackSource.fromJson(Map<String, dynamic> json) =>
      SavedPlaybackSource(
        mediaId: json['mediaId'] as int? ?? 0,
        sourceType: json['sourceType'] as String? ?? 'online',
        onlineStreamProvider: json['onlineStreamProvider'] as String?,
        onlineStreamDubbed: json['onlineStreamDubbed'] as bool?,
        onlineStreamServer: json['onlineStreamServer'] as String?,
        videoSource: json['videoSource'] as String?,
        videoUrl: json['videoUrl'] as String?,
        headers: (json['headers'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())),
        mimeType: json['mimeType'] as String?,
        episodeNumber: json['episodeNumber'] as int?,
        updatedAt: json['updatedAt'] as int? ?? 0,
      );
}

class AnimePlaybackSourceNotifier
    extends Notifier<Map<int, SavedPlaybackSource>> {
  static const String _storageKey = 'anime_saved_playback_sources_v1';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  Map<int, SavedPlaybackSource> build() {
    if (_cachedPrefs != null) {
      final raw = _cachedPrefs!.getString(_storageKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(
                  int.tryParse(k.toString()) ?? 0,
                  SavedPlaybackSource.fromJson(
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
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          state = decoded.map((k, v) => MapEntry(
                int.tryParse(k.toString()) ?? 0,
                SavedPlaybackSource.fromJson(
                    Map<String, dynamic>.from(v as Map)),
              ));
        }
      }
    } catch (e) {
      debugPrint('[AnimePlaybackSource] Error loading: $e');
    }
  }

  Future<void> saveSource({
    required int mediaId,
    required String sourceType,
    String? onlineStreamProvider,
    bool? onlineStreamDubbed,
    String? onlineStreamServer,
    String? videoSource,
    String? videoUrl,
    Map<String, String>? headers,
    String? mimeType,
    int? episodeNumber,
  }) async {
    if (mediaId <= 0) return;

    final item = SavedPlaybackSource(
      mediaId: mediaId,
      sourceType: sourceType,
      onlineStreamProvider: onlineStreamProvider,
      onlineStreamDubbed: onlineStreamDubbed,
      onlineStreamServer: onlineStreamServer,
      videoSource: videoSource,
      videoUrl: videoUrl,
      headers: headers,
      mimeType: mimeType,
      episodeNumber: episodeNumber,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final next = Map<int, SavedPlaybackSource>.from(state);
    next[mediaId] = item;
    state = next;

    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      final jsonMap = next.map((k, v) => MapEntry(k.toString(), v.toJson()));
      await prefs.setString(_storageKey, jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('[AnimePlaybackSource] Error saving: $e');
    }
  }

  SavedPlaybackSource? getSource(int mediaId) {
    return state[mediaId];
  }
}

final animePlaybackSourceProvider = NotifierProvider<
    AnimePlaybackSourceNotifier, Map<int, SavedPlaybackSource>>(
  AnimePlaybackSourceNotifier.new,
);
