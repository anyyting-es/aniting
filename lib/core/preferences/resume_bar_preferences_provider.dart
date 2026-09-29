import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LastSessionItem {
  final String mediaType; // 'ANIME' or 'MANGA'
  final int mediaId;
  final String title;
  final String? subtitle;
  final String? coverImage;
  final String? characterImage;
  final int? episodeNumber;
  final String? episodeTitle;
  final double? chapterNumber;
  final String? chapterId;
  final String? mangaProvider;
  final int? page;
  final int? positionMs;
  final int? durationMs;
  final String? videoUrl;
  final Map<String, String>? headers;
  final String? mimeType;
  final String? videoSource;
  final int updatedAt;

  const LastSessionItem({
    required this.mediaType,
    required this.mediaId,
    required this.title,
    this.subtitle,
    this.coverImage,
    this.characterImage,
    this.episodeNumber,
    this.episodeTitle,
    this.chapterNumber,
    this.chapterId,
    this.mangaProvider,
    this.page,
    this.positionMs,
    this.durationMs,
    this.videoUrl,
    this.headers,
    this.mimeType,
    this.videoSource,
    required this.updatedAt,
  });

  bool get isAnime => mediaType == 'ANIME';
  bool get isManga => mediaType == 'MANGA';

  /// Preferred image to display: Main Character (MC) image if available, else cover image
  String? get displayImage {
    if (characterImage != null && characterImage!.isNotEmpty) {
      return characterImage;
    }
    if (coverImage != null && coverImage!.isNotEmpty) {
      return coverImage;
    }
    return null;
  }

  double get progressRatio {
    if (isAnime && positionMs != null && durationMs != null && durationMs! > 0) {
      return (positionMs! / durationMs!).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  LastSessionItem copyWith({
    String? mediaType,
    int? mediaId,
    String? title,
    String? subtitle,
    String? coverImage,
    String? characterImage,
    int? episodeNumber,
    String? episodeTitle,
    double? chapterNumber,
    String? chapterId,
    String? mangaProvider,
    int? page,
    int? positionMs,
    int? durationMs,
    String? videoUrl,
    Map<String, String>? headers,
    String? mimeType,
    String? videoSource,
    int? updatedAt,
  }) {
    return LastSessionItem(
      mediaType: mediaType ?? this.mediaType,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      coverImage: coverImage ?? this.coverImage,
      characterImage: characterImage ?? this.characterImage,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      chapterId: chapterId ?? this.chapterId,
      mangaProvider: mangaProvider ?? this.mangaProvider,
      page: page ?? this.page,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      videoUrl: videoUrl ?? this.videoUrl,
      headers: headers ?? this.headers,
      mimeType: mimeType ?? this.mimeType,
      videoSource: videoSource ?? this.videoSource,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'mediaType': mediaType,
        'mediaId': mediaId,
        'title': title,
        'subtitle': subtitle,
        'coverImage': coverImage,
        'characterImage': characterImage,
        'episodeNumber': episodeNumber,
        'episodeTitle': episodeTitle,
        'chapterNumber': chapterNumber,
        'chapterId': chapterId,
        'mangaProvider': mangaProvider,
        'page': page,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'videoUrl': videoUrl,
        'headers': headers,
        'mimeType': mimeType,
        'videoSource': videoSource,
        'updatedAt': updatedAt,
      };

  factory LastSessionItem.fromJson(Map<String, dynamic> json) {
    return LastSessionItem(
      mediaType: json['mediaType']?.toString() ?? 'ANIME',
      mediaId: json['mediaId'] is int ? json['mediaId'] : 0,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      coverImage: json['coverImage']?.toString(),
      characterImage: json['characterImage']?.toString(),
      episodeNumber: json['episodeNumber'] is int ? json['episodeNumber'] : null,
      episodeTitle: json['episodeTitle']?.toString(),
      chapterNumber: (json['chapterNumber'] as num?)?.toDouble(),
      chapterId: json['chapterId']?.toString(),
      mangaProvider: json['mangaProvider']?.toString(),
      page: json['page'] is int ? json['page'] : null,
      positionMs: json['positionMs'] is int ? json['positionMs'] : null,
      durationMs: json['durationMs'] is int ? json['durationMs'] : null,
      videoUrl: json['videoUrl']?.toString(),
      headers: (json['headers'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())),
      mimeType: json['mimeType']?.toString(),
      videoSource: json['videoSource']?.toString(),
      updatedAt: json['updatedAt'] is int ? json['updatedAt'] : 0,
    );
  }
}

class LastSessionNotifier extends Notifier<LastSessionItem?> {
  static const String _storageKey = 'last_playback_session_v1';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  LastSessionItem? build() {
    if (_cachedPrefs != null) {
      final raw = _cachedPrefs!.getString(_storageKey);
      if (raw != null) {
        try {
          return LastSessionItem.fromJson(jsonDecode(raw));
        } catch (_) {}
      }
    }
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          state = LastSessionItem.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('Error loading last session: $e');
    }
  }

  Future<void> saveSession(LastSessionItem item) async {
    state = item;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(item.toJson()));
    } catch (e) {
      debugPrint('Error saving last session: $e');
    }
  }

  Future<void> clearSession() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('Error clearing last session: $e');
    }
  }
}

final lastSessionProvider =
    NotifierProvider<LastSessionNotifier, LastSessionItem?>(LastSessionNotifier.new);

class ResumeBarEnabledNotifier extends Notifier<bool> {
  static const String _key = 'resume_bar_enabled';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  bool build() {
    if (_cachedPrefs != null) {
      return _cachedPrefs!.getBool(_key) ?? true;
    }
    _loadFromPrefs();
    return true;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final resumeBarEnabledProvider =
    NotifierProvider<ResumeBarEnabledNotifier, bool>(ResumeBarEnabledNotifier.new);
