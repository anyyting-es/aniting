import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';

/// Tipo de acción pendiente de sincronización offline.
enum OfflineSyncType {
  animeProgress,
  mangaProgress,
  listEntry,
}

/// Representa una acción diferida registrada mientras el usuario no tenía conexión.
class OfflineSyncItem {
  final String id;
  final int mediaId;
  final OfflineSyncType type;
  final int? progress;
  final int? totalCount;
  final String? status;
  final double? score;
  final String? title;
  final int timestamp;

  const OfflineSyncItem({
    required this.id,
    required this.mediaId,
    required this.type,
    this.progress,
    this.totalCount,
    this.status,
    this.score,
    this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaId': mediaId,
        'type': type.name,
        'progress': progress,
        'totalCount': totalCount,
        'status': status,
        'score': score,
        'title': title,
        'timestamp': timestamp,
      };

  factory OfflineSyncItem.fromJson(Map<String, dynamic> json) {
    return OfflineSyncItem(
      id: json['id'] as String? ?? '',
      mediaId: json['mediaId'] as int? ?? 0,
      type: OfflineSyncType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => OfflineSyncType.animeProgress,
      ),
      progress: json['progress'] as int?,
      totalCount: json['totalCount'] as int?,
      status: json['status'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      title: json['title'] as String?,
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }
}

/// Servicio que gestiona la cola de sincronización offline.
/// Cuando el usuario ve episodios o lee capítulos sin conexión,
/// las acciones se encolan de forma persistente y se sincronizan
/// automáticamente con AniList/Seanime en cuanto se restablece la conexión.
class OfflineSyncService {
  static OfflineSyncService? _instance;
  static SharedPreferences? _cachedPrefs;
  static const String _kPendingQueueKey = 'offline_pending_sync_queue_v1';

  static OfflineSyncService get instance => _instance ??= OfflineSyncService._();

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
    if (_instance != null) {
      _instance!._loadFromPrefs(prefs);
    }
  }

  final Map<String, OfflineSyncItem> _queue = {};
  bool _isLoaded = false;
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  SeanimeRepository? _repository;

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  void Function(int count)? onSyncCompleted;

  OfflineSyncService._() {
    if (_cachedPrefs != null) {
      _loadFromPrefs(_cachedPrefs!);
    } else {
      _initAsync();
    }
    _startPeriodicTimer();
  }

  bool get isLoaded => _isLoaded;
  int get pendingCount => _queue.length;
  List<OfflineSyncItem> get pendingItems => _queue.values.toList();

  void attachRepository(SeanimeRepository repository) {
    _repository = repository;
  }

  void _startPeriodicTimer() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_queue.isNotEmpty && !_isSyncing) {
        syncPending();
      }
    });
  }

  Future<void> _initAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _loadFromPrefs(prefs);
    } catch (e) {
      debugPrint('[OfflineSyncService] Error in async init: $e');
    }
  }

  void _loadFromPrefs(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_kPendingQueueKey);
      _queue.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final syncItem = OfflineSyncItem.fromJson(item);
              if (syncItem.mediaId > 0 && syncItem.id.isNotEmpty) {
                _queue[syncItem.id] = syncItem;
              }
            }
          }
        }
      }
      _isLoaded = true;
      pendingCountNotifier.value = _queue.length;
    } catch (e) {
      debugPrint('[OfflineSyncService] Error loading pending queue: $e');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      final list = _queue.values.map((e) => e.toJson()).toList();
      await prefs.setString(_kPendingQueueKey, jsonEncode(list));
      pendingCountNotifier.value = _queue.length;
    } catch (e) {
      debugPrint('[OfflineSyncService] Error persisting queue: $e');
    }
  }

  /// Encola el progreso de un anime visto sin conexión.
  /// Si ya existía un progreso menor pendiente para la misma serie, se colapsa
  /// de forma inteligente al mayor progreso.
  Future<void> enqueueAnimeProgress({
    required int mediaId,
    required int episodeNumber,
    int? totalEpisodes,
    String? title,
  }) async {
    if (mediaId <= 0) return;
    final id = 'anime_$mediaId';
    final existing = _queue[id];

    final finalProgress = (existing != null && (existing.progress ?? 0) > episodeNumber)
        ? existing.progress!
        : episodeNumber;

    _queue[id] = OfflineSyncItem(
      id: id,
      mediaId: mediaId,
      type: OfflineSyncType.animeProgress,
      progress: finalProgress,
      totalCount: totalEpisodes ?? existing?.totalCount,
      title: title ?? existing?.title,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await _persistQueue();
    debugPrint('[OfflineSyncService] Enqueued anime progress: mediaId=$mediaId, ep=$finalProgress (Pending: ${_queue.length})');

    // Intentar sincronización inmediata por si la red volvió
    unawaited(syncPending());
  }

  /// Encola el progreso de un capítulo de manga leído sin conexión.
  Future<void> enqueueMangaProgress({
    required int mediaId,
    required double chapterNumber,
    int? totalChapters,
    String? title,
  }) async {
    if (mediaId <= 0) return;
    final id = 'manga_$mediaId';
    final existing = _queue[id];
    final chInt = chapterNumber.floor();

    final finalProgress = (existing != null && (existing.progress ?? 0) > chInt)
        ? existing.progress!
        : chInt;

    _queue[id] = OfflineSyncItem(
      id: id,
      mediaId: mediaId,
      type: OfflineSyncType.mangaProgress,
      progress: finalProgress,
      totalCount: totalChapters ?? existing?.totalCount,
      title: title ?? existing?.title,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await _persistQueue();
    debugPrint('[OfflineSyncService] Enqueued manga progress: mediaId=$mediaId, ch=$finalProgress (Pending: ${_queue.length})');

    unawaited(syncPending());
  }

  /// Encola la edición de lista offline (p. ej. cambio de estado o puntuación).
  Future<void> enqueueListEdit({
    required int mediaId,
    required String type, // 'anime' | 'manga'
    required String status,
    double? score,
    int? progress,
    int? totalCount,
    String? title,
  }) async {
    if (mediaId <= 0) return;
    final id = 'edit_${type}_$mediaId';
    _queue[id] = OfflineSyncItem(
      id: id,
      mediaId: mediaId,
      type: OfflineSyncType.listEntry,
      status: status,
      score: score,
      progress: progress,
      totalCount: totalCount,
      title: title,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await _persistQueue();
    debugPrint('[OfflineSyncService] Enqueued list edit: mediaId=$mediaId, type=$type, status=$status');

    unawaited(syncPending());
  }

  /// Procesa todas las acciones pendientes en la cola.
  /// Si una llamada falla (indicando que aún no hay conexión), se interrumpe el ciclo
  /// conservando los items restantes para el próximo intento automático.
  Future<int> syncPending({SeanimeRepository? repository}) async {
    final repo = repository ?? _repository;
    if (repo == null || _isSyncing || _queue.isEmpty) return 0;

    _isSyncing = true;
    isSyncingNotifier.value = true;
    int syncedCount = 0;

    try {
      final itemsToProcess = _queue.values.toList();
      itemsToProcess.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (final item in itemsToProcess) {
        bool success = false;
        try {
          switch (item.type) {
            case OfflineSyncType.animeProgress:
              success = await repo.updateAnimeProgress(
                mediaId: item.mediaId,
                episodeNumber: item.progress ?? 1,
                totalEpisodes: item.totalCount,
              );
              break;
            case OfflineSyncType.mangaProgress:
              success = await repo.updateMangaProgress(
                mediaId: item.mediaId,
                chapterNumber: item.progress ?? 1,
                totalChapters: item.totalCount,
              );
              break;
            case OfflineSyncType.listEntry:
              final isManga = item.id.startsWith('edit_manga');
              success = await repo.editAnilistListEntry(
                mediaId: item.mediaId,
                type: isManga ? 'manga' : 'anime',
                status: item.status,
                score: item.score?.toInt(),
                progress: item.progress,
              );
              break;
          }
        } catch (e) {
          debugPrint('[OfflineSyncService] Network/sync error processing item ${item.id}: $e');
          success = false;
        }

        if (success) {
          _queue.remove(item.id);
          syncedCount++;
          debugPrint('[OfflineSyncService] Successfully synced offline item ${item.id}');
        } else {
          // Si falló, asumimos que seguimos sin conexión o el servidor no responde
          debugPrint('[OfflineSyncService] Pausing queue: item ${item.id} failed, will retry later.');
          break;
        }
      }

      if (syncedCount > 0) {
        await _persistQueue();
        onSyncCompleted?.call(syncedCount);
      }
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }

    return syncedCount;
  }

  void dispose() {
    _periodicSyncTimer?.cancel();
  }
}
