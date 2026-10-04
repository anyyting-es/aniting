import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

class DownloadHistoryItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? coverImage;
  final String size;
  final String type; // 'anime' | 'manga' | 'torrent'
  final DateTime completedAt;
  final String? filePath;
  final int? mediaId;

  const DownloadHistoryItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.coverImage,
    this.size = '',
    required this.type,
    required this.completedAt,
    this.filePath,
    this.mediaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'coverImage': coverImage,
      'size': size,
      'type': type,
      'completedAt': completedAt.toIso8601String(),
      'filePath': filePath,
      'mediaId': mediaId,
    };
  }

  factory DownloadHistoryItem.fromMap(Map<String, dynamic> map) {
    return DownloadHistoryItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      coverImage: map['coverImage'] as String?,
      size: map['size'] as String? ?? '',
      type: map['type'] as String? ?? 'torrent',
      completedAt: DateTime.tryParse(map['completedAt'] as String? ?? '') ?? DateTime.now(),
      filePath: map['filePath'] as String?,
      mediaId: (map['mediaId'] as num?)?.toInt(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DownloadHistoryItem.fromJson(String source) {
    return DownloadHistoryItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}

class DownloadHistoryNotifier extends Notifier<List<DownloadHistoryItem>> {
  static const _prefKey = 'download_history_items_v1';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  List<DownloadHistoryItem> build() {
    final cached = _cachedPrefs;
    if (cached != null) {
      final raw = cached.getStringList(_prefKey);
      if (raw != null) {
        return raw.map((s) => DownloadHistoryItem.fromJson(s)).toList();
      }
    }
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final raw = prefs.getStringList(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        state = raw.map((s) => DownloadHistoryItem.fromJson(s)).toList();
        return;
      }

      // If empty, auto-populate from existing downloaded offline anime and manga
      final items = <DownloadHistoryItem>[];
      final anime = ref.read(downloadedAnimeProvider).asData?.value ?? [];
      for (final a in anime) {
        final title = a.title;
        final epCount = a.mainFileCount > 0 ? a.mainFileCount : (a.totalEpisodes ?? 1);
        items.add(DownloadHistoryItem(
          id: 'anime_${a.mediaId}',
          title: title,
          subtitle: '$epCount ${epCount == 1 ? "episodio" : "episodios"} descargados',
          coverImage: a.coverImage,
          type: 'anime',
          completedAt: DateTime.now().subtract(const Duration(hours: 1)),
          mediaId: a.mediaId,
        ));
      }

      final manga = ref.read(downloadedMangaListProvider).asData?.value ?? [];
      for (final m in manga) {
        final title = m.title;
        final chCount = m.downloadedChaptersCount;
        items.add(DownloadHistoryItem(
          id: 'manga_${m.mediaId}',
          title: title,
          subtitle: '$chCount ${chCount == 1 ? "capítulo" : "capítulos"} descargados',
          coverImage: m.coverImage,
          size: '',
          type: 'manga',
          completedAt: DateTime.now().subtract(const Duration(hours: 2)),
          mediaId: m.mediaId,
        ));
      }

      if (items.isNotEmpty) {
        state = items;
        _save();
      }
    } catch (e) {
      debugPrint('[DownloadHistory] Error loading: $e');
    }
  }

  Future<void> addItem(DownloadHistoryItem item) async {
    // Avoid duplicate IDs; move to top if existing
    final current = state.where((i) => i.id != item.id).toList();
    state = [item, ...current];
    await _save();
  }

  Future<void> removeItem(String id) async {
    state = state.where((i) => i.id != id).toList();
    await _save();
  }

  Future<void> clearHistory() async {
    state = const [];
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.remove(_prefKey);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final raw = state.take(100).map((i) => i.toJson()).toList();
      await prefs.setStringList(_prefKey, raw);
    } catch (e) {
      debugPrint('[DownloadHistory] Error saving: $e');
    }
  }
}

final downloadHistoryProvider =
    NotifierProvider<DownloadHistoryNotifier, List<DownloadHistoryItem>>(
  DownloadHistoryNotifier.new,
);
