import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/api/api_endpoints.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/data/models/torrent_models.dart';

class SeanimeRepository {
  final ApiClient _apiClient;
  final Map<int, AniZipData> _aniZipCache = {};
  final Dio _externalDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 SeanimeApp/1.0',
      },
    ),
  );

  static const String _kLocalWatchHistoryKey = 'pref_local_watch_history';

  SeanimeRepository(this._apiClient);

  Future<Map<int, int>> getLocalWatchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocalWatchHistoryKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final result = <int, int>{};
          decoded.forEach((k, v) {
            final id = int.tryParse(k.toString());
            final ts = (v as num?)?.toInt();
            if (id != null && ts != null) result[id] = ts;
          });
          return result;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> recordLocalWatchHistory(int mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getLocalWatchHistory();
      history[mediaId] = DateTime.now().millisecondsSinceEpoch;
      final encoded = jsonEncode(history.map((k, v) => MapEntry(k.toString(), v)));
      await prefs.setString(_kLocalWatchHistoryKey, encoded);
    } catch (_) {}
  }

  Future<Map<int, dynamic>> getContinuityWatchHistory() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.continuityHistory);
      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final map = rawData is Map<String, dynamic> && rawData['data'] != null
            ? rawData['data']
            : rawData;
        if (map is Map) {
          final result = <int, dynamic>{};
          map.forEach((k, v) {
            final id = int.tryParse(k.toString());
            if (id != null && v is Map) {
              result[id] = v;
            }
          });
          return result;
        }
      }
    } catch (e) {
      debugPrint('Error fetching continuity history: $e');
    }
    return {};
  }

  Future<void> updateContinuityItem({
    required int mediaId,
    required int episodeNumber,
    double? currentTime,
    double? duration,
  }) async {
    await recordLocalWatchHistory(mediaId);
    try {
      await _apiClient.patch(
        ApiEndpoints.continuityItem,
        data: {
          'options': {
            'mediaId': mediaId,
            'episodeNumber': episodeNumber,
            'currentTime': currentTime ?? 0.0,
            'duration': duration ?? 0.0,
          },
        },
      );
    } catch (e) {
      debugPrint('Error updating continuity item: $e');
    }
  }

  /// Updates anime episode progress on AniList via the Seanime backend.
  /// Mirrors updateMangaProgress — sends the episode number and total episodes
  /// to the server, which calls UpdateEntryProgress on AniList and refreshes
  /// the anime collection cache.
  Future<bool> updateAnimeProgress({
    required int mediaId,
    required int episodeNumber,
    int? totalEpisodes,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.animeUpdateProgress,
        data: {
          'mediaId': mediaId,
          'episodeNumber': episodeNumber,
          'totalEpisodes': totalEpisodes ?? 0,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating anime progress: $e');
      return false;
    }
  }

  /// Updates an anime or manga entry on AniList via the Seanime backend.
  /// Calls POST /api/v1/anilist/list-entry, which performs the AniList GraphQL
  /// mutation and automatically refreshes the backend collection.
  Future<bool> editAnilistListEntry({
    required int mediaId,
    required String type, // 'anime' | 'manga'
    String? status,
    int? score,
    int? progress,
    Map<String, int>? startedAt,
    Map<String, int>? completedAt,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.anilistListEntry,
        data: {
          'mediaId': mediaId,
          'type': type,
          'status': status ?? 'PLANNING',
          'score': score ?? 0,
          'progress': progress ?? 0,
          'startedAt': ?startedAt,
          'completedAt': ?completedAt,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error editing AniList list entry: ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      debugPrint('Error editing AniList list entry: $e');
      return false;
    }
  }

  /// Deletes an entry from the user's AniList list via Seanime backend.
  /// Calls DELETE /api/v1/anilist/list-entry.
  Future<bool> deleteAnilistListEntry({
    required int mediaId,
    required String type, // 'anime' | 'manga'
  }) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.anilistListEntry,
        data: {
          'mediaId': mediaId,
          'type': type,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting AniList list entry: $e');
      return false;
    }
  }

  /// Updates the repeat (rewatches) count for an anime entry on AniList.
  Future<bool> updateAnimeRepeat({
    required int mediaId,
    required int repeat,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.animeUpdateRepeat,
        data: {
          'mediaId': mediaId,
          'repeat': repeat,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating anime repeat: $e');
      return false;
    }
  }

  /// Fetches the raw listData for an anime or manga entry from the Seanime backend.
  /// Returns a map with progress, score, status, repeat, startedAt, completedAt.
  Future<Map<String, dynamic>?> getAnilistEntryListData({
    required int mediaId,
    required String type, // 'anime' | 'manga'
  }) async {
    try {
      if (type == 'anime') {
        final resp = await _apiClient.get('${ApiEndpoints.animeEntry}/$mediaId');
        if (resp.statusCode == 200 && resp.data != null) {
          final raw = resp.data is Map ? resp.data['data'] : null;
          if (raw is Map<String, dynamic>) {
            return raw['listData'] as Map<String, dynamic>?;
          }
        }
      } else {
        final resp = await _apiClient.get('/manga/entry/$mediaId');
        if (resp.statusCode == 200 && resp.data != null) {
          final raw = resp.data is Map ? resp.data['data'] : null;
          if (raw is Map<String, dynamic>) {
            return raw['listData'] as Map<String, dynamic>?;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching AniList entry listData: $e');
    }
    return null;
  }

  Future<AniZipData?> getAniZipData(int mediaId) async {
    if (_aniZipCache.containsKey(mediaId)) {
      return _aniZipCache[mediaId];
    }
    try {
      final response = await _externalDio.get('https://api.ani.zip/v1/episodes?anilist_id=$mediaId');
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        final map = raw is String ? jsonDecode(raw) : raw;
        if (map is Map<String, dynamic>) {
          final data = AniZipData.fromJson(map);
          _aniZipCache[mediaId] = data;
          return data;
        }
      }
    } catch (e) {
      debugPrint('Error fetching AniZip data for media $mediaId: $e');
    }
    return null;
  }

  Future<ServerStatus?> getStatus() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.status);
      if (response.statusCode == 200 && response.data != null) {
        return ServerStatus.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error fetching status: $e');
    }
    return null;
  }

  Future<ServerStatus?> loginWithAnilistToken(String token) async {
    try {
      final cleanToken = _sanitizeToken(token);
      final response = await _apiClient.post(
        '/auth/login',
        data: {'token': cleanToken},
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return ServerStatus.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      debugPrint('Error logging in to AniList: $e');
      if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionTimeout) {
        throw Exception('AniList o el servidor tardaron en responder (posible límite de peticiones de AniList). Por favor espera 1 minuto y vuelve a presionar Vincular Cuenta.');
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 429) {
        throw Exception('AniList tiene activo un límite temporal de peticiones (rate limit). Por favor espera 60 segundos antes de volver a intentarlo.');
      }
      final errorData = e.response?.data;
      if (errorData is Map && errorData['error'] != null) {
        final serverErr = errorData['error'].toString();
        if (serverErr.toLowerCase().contains('invalid token') ||
            serverErr.toLowerCase().contains('could not authenticate') ||
            serverErr.toLowerCase().contains('unauthorized')) {
          throw Exception('El token de AniList no es válido o ha expirado. Asegúrate de copiar el token completo (o la URL entera) y vuelve a intentarlo.');
        }
        if (serverErr.toLowerCase().contains('rate limit')) {
          throw Exception('AniList tiene activo un límite temporal de peticiones (rate limit). Por favor espera 60 segundos antes de reintentar.');
        }
        throw Exception(serverErr);
      }
      throw Exception('No se pudo conectar con el servidor o AniList. Verifica tu conexión e inténtalo de nuevo.');
    } catch (e) {
      debugPrint('Error logging in to AniList: $e');
      rethrow;
    }
    return null;
  }

  Future<ServerStatus?> logoutFromAnilist() async {
    try {
      final response = await _apiClient.post('/auth/logout');
      if (response.statusCode == 200 && response.data != null) {
        return ServerStatus.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error logging out from AniList: $e');
      rethrow;
    }
    return null;
  }

  String _sanitizeToken(String input) {
    var trimmed = input.trim().replaceAll('"', '').replaceAll("'", '');
    if (trimmed.contains('access_token=')) {
      final match = RegExp(r'access_token=([^&#\s]+)').firstMatch(trimmed);
      if (match != null) {
        trimmed = match.group(1)!;
      }
    }
    return trimmed.replaceAll(RegExp(r'\s+'), '');
  }

  Future<List<AnimeEntry>> getLibraryCollection() async {
    try {
      final list = <AnimeEntry>[];
      final seenMediaIds = <int>{};

      void addEntriesFromLists(List? rawLists) {
        if (rawLists == null) return;
        for (final l in rawLists) {
          if (l is Map<String, dynamic> && l['entries'] is List) {
            final listStatus = l['status'] as String? ?? (l['name'] == 'Watching' ? 'CURRENT' : null);
            for (final entry in l['entries'] as List) {
              if (entry is Map<String, dynamic>) {
                final entryMap = Map<String, dynamic>.from(entry);
                if (listStatus != null && (entryMap['status'] == null || entryMap['status'] == '')) {
                  entryMap['status'] = listStatus;
                }
                if (entryMap['media'] is Map) {
                  final m = entryMap['media'] as Map;
                  entryMap['mediaId'] ??= m['id'];
                }
                final animeEntry = AnimeEntry.fromJson(entryMap);
                if (animeEntry.mediaId > 0 && !seenMediaIds.contains(animeEntry.mediaId)) {
                  seenMediaIds.add(animeEntry.mediaId);
                  list.add(animeEntry);
                }
              }
            }
          }
        }
      }

      // 1. Primary: Fetch user's AniList anime collection from /anilist/collection
      try {
        final anilistRes = await _apiClient.get('/anilist/collection');
        if (anilistRes.statusCode == 200 && anilistRes.data != null) {
          final aData = anilistRes.data;
          Map<String, dynamic>? aRoot;
          if (aData is Map<String, dynamic>) {
            aRoot = aData['data'] is Map<String, dynamic> ? aData['data'] as Map<String, dynamic> : aData;
          }
          final aLists = (aRoot?['lists'] ?? aRoot?['MediaListCollection']?['lists']) as List?;
          addEntriesFromLists(aLists);
        }
      } catch (e) {
        debugPrint('Error fetching anilist collection in library: $e');
      }

      // 2. Secondary: If any local files exist in /library/collection, merge any missing entries
      try {
        final response = await _apiClient.get(ApiEndpoints.libraryCollection);
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          Map<String, dynamic>? root;
          if (data is Map<String, dynamic>) {
            root = data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : data;
          }
          final rawLists = (root?['lists'] ?? root?['MediaListCollection']?['lists']) as List?;
          addEntriesFromLists(rawLists);
        }
      } catch (e) {
        debugPrint('Error fetching library collection: $e');
      }

      return list;
    } catch (e) {
      debugPrint('Error fetching library: $e');
    }
    return [];
  }

  Future<void> refreshAnilistCollection() async {
    try {
      await _apiClient.post(
        '/anilist/collection',
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
    } catch (e) {
      debugPrint('Error refreshing AniList collection: $e');
    }
  }

  Future<List<AnimeEntry>> getContinueWatching() async {
    try {
      final historyFuture = getContinuityWatchHistory();
      final localHistoryFuture = getLocalWatchHistory();
      final libraryFuture = _apiClient
          .get(ApiEndpoints.libraryCollection)
          .then<Response<dynamic>?>((r) => r)
          .catchError((_) => null);
      final anilistFuture = _apiClient
          .get('/anilist/collection')
          .then<Response<dynamic>?>((r) => r)
          .catchError((_) => null);

      final results = await Future.wait([libraryFuture, historyFuture, localHistoryFuture, anilistFuture]);
      final libraryResponse = results[0] as Response?;
      final serverHistory = results[1] as Map<int, dynamic>;
      final localHistory = results[2] as Map<int, int>;
      final anilistResponse = results[3] as Response?;

      final list = <AnimeEntry>[];
      final seenMediaIds = <int>{};

      // Helper to enrich and parse an episode entry
      void addEpisode(Map<String, dynamic> item) {
        final base = item['baseAnime'] as Map<String, dynamic>?;
        final media = item['media'] as Map<String, dynamic>?;
        final mediaId = (base?['id'] as num?)?.toInt() ??
            (item['mediaId'] as num?)?.toInt() ??
            (media?['id'] as num?)?.toInt() ??
            (item['id'] as num?)?.toInt() ??
            0;
        if (mediaId <= 0 || seenMediaIds.contains(mediaId)) return;
        seenMediaIds.add(mediaId);

        int? lastWatchedMs;
        if (localHistory.containsKey(mediaId)) {
          lastWatchedMs = localHistory[mediaId];
        }
        if (serverHistory.containsKey(mediaId)) {
          final sItem = serverHistory[mediaId];
          if (sItem is Map && sItem['timeUpdated'] != null) {
            final parsed = DateTime.tryParse(sItem['timeUpdated'].toString())?.millisecondsSinceEpoch;
            if (parsed != null) {
              lastWatchedMs = lastWatchedMs != null ? math.max(lastWatchedMs, parsed) : parsed;
            }
          }
        }

        final enrichedItem = Map<String, dynamic>.from(item);
        if (lastWatchedMs != null) {
          enrichedItem['lastWatchedTime'] = lastWatchedMs;
          enrichedItem['updatedAt'] = lastWatchedMs;
        }

        final entry = AnimeEntry.fromJson(enrichedItem);
        // Only include in Continue Watching if not already finished
        if (entry.totalEpisodes != null && entry.totalEpisodes! > 0 && entry.progress >= entry.totalEpisodes!) {
          return;
        }
        list.add(entry);
      }

      // 1. Seanime dedicated continueWatchingList (Local library files)
      if (libraryResponse?.statusCode == 200 && libraryResponse?.data != null) {
        final data = libraryResponse!.data;
        Map<String, dynamic>? root;
        if (data is Map<String, dynamic>) {
          root = data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : data;
        }
        final localCw = root?['continueWatchingList'] as List?;
        if (localCw != null) {
          for (final item in localCw) {
            if (item is Map<String, dynamic>) {
              addEpisode(item);
            }
          }
        }

        // 2. Seanime stream continueWatchingList (Torrent / Online streaming)
        final streamCw = (root?['stream'] is Map && (root!['stream'] as Map)['continueWatchingList'] is List)
            ? (root['stream'] as Map)['continueWatchingList'] as List
            : null;
        if (streamCw != null) {
          for (final item in streamCw) {
            if (item is Map<String, dynamic>) {
              addEpisode(item);
            }
          }
        }
      }

      // 3. User's CURRENT (Watching) list from AniList collection
      if (anilistResponse?.statusCode == 200 && anilistResponse?.data != null) {
        final aData = anilistResponse!.data;
        Map<String, dynamic>? aRoot;
        if (aData is Map<String, dynamic>) {
          aRoot = aData['data'] is Map<String, dynamic> ? aData['data'] as Map<String, dynamic> : aData;
        }
        final aLists = (aRoot?['lists'] ?? aRoot?['MediaListCollection']?['lists']) as List?;
        if (aLists != null) {
          for (final l in aLists) {
            if (l is Map<String, dynamic>) {
              final status = (l['status'] as String?)?.toUpperCase() ?? (l['name'] == 'Watching' ? 'CURRENT' : '');
              if (status == 'CURRENT' || status == 'WATCHING' || status == 'REPEATING') {
                final entries = l['entries'] as List?;
                if (entries != null) {
                  for (final e in entries) {
                    if (e is Map<String, dynamic>) {
                      final eMap = Map<String, dynamic>.from(e);
                      if (eMap['media'] is Map) {
                        final m = eMap['media'] as Map;
                        eMap['mediaId'] ??= m['id'];
                      }
                      eMap['status'] ??= 'CURRENT';
                      addEpisode(eMap);
                    }
                  }
                }
              }
            }
          }
        }
      }

      // 4. Filtrar animes donde el siguiente episodio NO ha salido aún o ya se vieron todos
      final validEntries = list.where((e) => e.hasNextEpisodeAired).toList();

      // 5. Enriquecer con AniZip: carátula 16:9 real, título oficial y fecha de emisión exacta
      final enrichedList = (await Future.wait(validEntries.map((entry) async {
        final mediaId = entry.mediaId;
        final epNum = entry.episodeNumber ?? (entry.progress + 1);
        if (mediaId > 0 && epNum > 0) {
          try {
            final aniZip = await getAniZipData(mediaId);
            if (aniZip != null) {
              final aniEp = aniZip.getEpisode(epNum);
              if (aniEp != null) {
                // Si la fecha de emisión de AniZip está en el futuro, descartar
                if (aniEp.airDate != null && aniEp.airDate!.isNotEmpty) {
                  final epAirDate = DateTime.tryParse(aniEp.airDate!);
                  if (epAirDate != null && epAirDate.isAfter(DateTime.now())) {
                    return null;
                  }
                }

                final String? thumb = (aniEp.image != null && aniEp.image!.trim().isNotEmpty)
                    ? aniEp.image!.trim()
                    : null;
                final String? title = aniEp.displayTitle.trim().isNotEmpty
                    ? aniEp.displayTitle.trim()
                    : null;
                return entry.copyWith(
                  episodeThumbnail: thumb ?? entry.episodeThumbnail,
                  episodeTitle: (title != null && !title.startsWith('Episodio')) ? title : entry.episodeTitle,
                  airDate: aniEp.airDate ?? entry.airDate,
                );
              }
            }
          } catch (_) {}
        }
        return entry;
      }))).whereType<AnimeEntry>().toList();

      return enrichedList;
    } catch (e) {
      debugPrint('Error fetching continue watching: $e');
    }
    return [];
  }

  Future<List<AnimeEntry>> getTrendingAnime({int page = 1, int perPage = 12}) async {
    try {
      final response = await _apiClient.post(
        '/anilist/list-anime',
        data: {
          'page': page,
          'perPage': perPage,
          'sort': ['TRENDING_DESC'],
        },
      );
      return _parseMediaPage(response.data);
    } catch (e) {
      debugPrint('Error fetching trending anime: $e');
      return [];
    }
  }

  Future<List<AnimeEntry>> getPopularAnime({int page = 1, int perPage = 12}) async {
    try {
      final response = await _apiClient.post(
        '/anilist/list-anime',
        data: {
          'page': page,
          'perPage': perPage,
          'sort': ['POPULARITY_DESC'],
        },
      );
      return _parseMediaPage(response.data);
    } catch (e) {
      debugPrint('Error fetching popular anime: $e');
      return [];
    }
  }

  Future<List<AnimeEntry>> getRecentAiringAnime({int page = 1, int perPage = 20}) async {
    try {
      final response = await _apiClient.post(
        '/anilist/list-recent-anime',
        data: {
          'page': page,
          'perPage': perPage,
        },
      );
      return _parseMediaPage(response.data);
    } catch (e) {
      debugPrint('Error fetching recent anime: $e');
      return [];
    }
  }

  Future<List<AnimeEntry>> getMissedSequels() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.missedSequels);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final list = <AnimeEntry>[];
        List? rawList;
        if (data is Map<String, dynamic> && data['data'] is List) {
          rawList = data['data'] as List;
        } else if (data is List) {
          rawList = data;
        }
        if (rawList != null) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              list.add(AnimeEntry.fromJson(item));
            }
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('Error fetching missed sequels: $e');
    }
    return [];
  }

  Future<AnimeDetails?> getAnimeDetails(int mediaId, {AnimeEntry? initialEntry}) async {
    try {
      // 1. Fetch AniList extended details, Seanime library entry (has full BaseAnime media), and AniZip metadata in parallel
      final results = await Future.wait([
        _apiClient.get('/anilist/media-details/$mediaId').then<dynamic>((r) => r).catchError((_) => null),
        _apiClient.get('${ApiEndpoints.animeEntry}/$mediaId').then<dynamic>((r) => r).catchError((_) => null),
        getAniZipData(mediaId).then<dynamic>((r) => r).catchError((_) => null),
      ]);

      final mediaDetailsResp = results[0];
      final libraryEntryResp = results[1];
      final AniZipData? aniZipData = results[2] as AniZipData?;

      List<AnimeEpisode> episodes = [];
      try {
        final epResponse = await _apiClient.get('/anime/episode-collection/$mediaId');
        if (epResponse.statusCode == 200 && epResponse.data != null) {
          final data = epResponse.data;
          dynamic epList;
          if (data is Map<String, dynamic>) {
            final innerData = data['data'];
            if (innerData is Map<String, dynamic>) {
              epList = innerData['episodes'];
            } else if (innerData is List) {
              epList = innerData;
            } else {
              epList = data['episodes'];
            }
          } else if (data is List) {
            epList = data;
          }
          if (epList is List) {
            episodes = epList
                .whereType<Map<String, dynamic>>()
                .map(AnimeEpisode.fromJson)
                .toList();
          }
        }
      } catch (_) {
        // Continue
      }

      // Merge base anime media info (title, coverImage, bannerImage, score, format, status)
      // with extended details (description, studios, characters, etc.)
      final Map<String, dynamic> mergedData = {};

      if (libraryEntryResp != null && libraryEntryResp.statusCode == 200 && libraryEntryResp.data != null) {
        final raw = libraryEntryResp.data;
        if (raw is Map<String, dynamic>) {
          final inner = raw['data'];
          if (inner is Map<String, dynamic>) {
            mergedData.addAll(inner);
          } else {
            mergedData.addAll(raw);
          }
        }
      }

      if (mediaDetailsResp != null && mediaDetailsResp.statusCode == 200 && mediaDetailsResp.data != null) {
        final raw = mediaDetailsResp.data;
        if (raw is Map<String, dynamic>) {
          final inner = raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw;
          for (final entry in inner.entries) {
            if (entry.key == 'title' || entry.key == 'coverImage' || entry.key == 'bannerImage') {
              if (mergedData[entry.key] == null && entry.value != null) {
                mergedData[entry.key] = entry.value;
              }
            } else {
              mergedData[entry.key] = entry.value;
            }
          }
        }
      }

      // If characters or relations are still missing (e.g. server offline or AniList call error),
      // fetch extended details directly from AniList GraphQL
      final hasChars = mergedData['characters'] != null &&
          (mergedData['characters'] is Map &&
              (mergedData['characters']['edges'] as List?)?.isNotEmpty == true);
      if (!hasChars) {
        try {
          final anilistDirectResp = await _externalDio.post(
            'https://graphql.anilist.co',
            data: {
              'query': '''
                query (\$id: Int) {
                  Media(id: \$id, type: ANIME) {
                    id
                    description
                    trailer {
                      id
                      site
                      thumbnail
                    }
                    characters(sort: [ROLE]) {
                      edges {
                        id
                        role
                        name
                        node {
                          id
                          name {
                            userPreferred
                            full
                            native
                          }
                          image {
                            large
                            medium
                          }
                        }
                      }
                    }
                    relations {
                      edges {
                        relationType(version: 2)
                        node {
                          id
                          format
                          status(version: 2)
                          episodes
                          averageScore
                          title {
                            userPreferred
                            romaji
                            english
                            native
                          }
                          coverImage {
                            large
                            medium
                            color
                          }
                          bannerImage
                        }
                      }
                    }
                    recommendations(sort: RATING_DESC, perPage: 12) {
                      edges {
                        node {
                          mediaRecommendation {
                            id
                            format
                            status(version: 2)
                            episodes
                            meanScore
                            title {
                              userPreferred
                              romaji
                              english
                              native
                            }
                            coverImage {
                              large
                              medium
                              color
                            }
                            bannerImage
                          }
                        }
                      }
                    }
                    studios(isMain: true) {
                      nodes {
                        id
                        name
                      }
                    }
                  }
                }
              ''',
              'variables': {'id': mediaId},
            },
          );
          if (anilistDirectResp.statusCode == 200 && anilistDirectResp.data != null) {
            final mediaData = anilistDirectResp.data['data']?['Media'];
            if (mediaData is Map<String, dynamic>) {
              for (final entry in mediaData.entries) {
                if (mergedData[entry.key] == null) {
                  mergedData[entry.key] = entry.value;
                }
              }
            }
          }
        } catch (_) {}
      }

      if (mergedData['media'] is Map<String, dynamic>) {
        final m = mergedData['media'] as Map<String, dynamic>;
        for (final k in ['characters', 'relations', 'recommendations', 'trailer', 'studios', 'staff']) {
          if (mergedData[k] != null && m[k] == null) {
            m[k] = mergedData[k];
          }
        }
      }

      if (mergedData.isNotEmpty) {
        var details = AnimeDetails.fromJson(mergedData, episodes: episodes);
        details = details.copyWithAniZipData(aniZipData);

        // Fallback to initialEntry for any missing title/cover/banner
        if (initialEntry != null) {
          final fallbackTitle = (details.title == 'Sin título' || details.title.trim().isEmpty)
              ? initialEntry.title
              : details.title;
          final fallbackRomaji = details.romajiTitle ?? initialEntry.romajiTitle;
          final fallbackEnglish = details.englishTitle ?? initialEntry.englishTitle;
          final fallbackNative = details.nativeTitle ?? initialEntry.nativeTitle;
          final fallbackCover = details.coverImage ?? initialEntry.coverImage;
          final fallbackBanner = details.bannerImage ?? initialEntry.bannerImage;

          details = details.copyWith(
            title: fallbackTitle,
            romajiTitle: fallbackRomaji,
            englishTitle: fallbackEnglish,
            nativeTitle: fallbackNative,
            coverImage: fallbackCover,
            bannerImage: fallbackBanner,
          );
        }

        return details;
      }
    } catch (e) {
      debugPrint('Error fetching anime details: $e');
    }
    return null;
  }

  Future<List<AnimeEntry>> searchAnime(String query, {int page = 1, int perPage = 20}) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _apiClient.post(
        '/anilist/list-anime',
        data: {
          'search': query.trim(),
          'page': page,
          'perPage': perPage,
        },
      );
      return _parseMediaPage(response.data);
    } catch (e) {
      debugPrint('Error searching anime: $e');
      return [];
    }
  }

  List<AnimeEntry> _parseMediaPage(dynamic responseData) {
    if (responseData == null) return [];
    final list = <AnimeEntry>[];

    Map<String, dynamic>? root;
    if (responseData is Map<String, dynamic>) {
      root = responseData['data'] is Map<String, dynamic> ? responseData['data'] as Map<String, dynamic> : responseData;
    }

    if (root != null) {
      final page = root['Page'] as Map<String, dynamic>? ?? root;
      final media = (page['media'] ?? root['media'] ?? root['airingSchedules']) as List?;
      if (media != null) {
        for (final item in media) {
          if (item is Map<String, dynamic>) {
            list.add(AnimeEntry.fromJson(item));
          }
        }
      }
    }
    return list;
  }

  Future<List<AnimeEntry>> getRecommendationsForUser({
    required List<int> mediaIds,
    Set<int> excludeMediaIds = const {},
  }) async {
    if (mediaIds.isEmpty) return [];
    try {
      final results = <AnimeEntry>[];
      final seenIds = Set<int>.from(excludeMediaIds);

      // Query recommendations for up to 3 anime that the user is watching or completed
      for (final id in mediaIds.take(3)) {
        try {
          final res = await _externalDio.post(
            'https://graphql.anilist.co',
            data: {
              'query': '''
                query (\$id: Int) {
                  Media(id: \$id) {
                    recommendations(sort: RATING_DESC, perPage: 8) {
                      nodes {
                        mediaRecommendation {
                          id
                          title {
                            userPreferred
                            romaji
                            english
                            native
                          }
                          coverImage {
                            extraLarge
                            large
                            medium
                          }
                          bannerImage
                          status
                          format
                          episodes
                          averageScore
                          description
                        }
                      }
                    }
                  }
                }
              ''',
              'variables': {'id': id},
            },
          );

          if (res.statusCode == 200 && res.data != null) {
            final data = res.data is String ? jsonDecode(res.data) : res.data;
            if (data is Map<String, dynamic>) {
              final nodes = data['data']?['Media']?['recommendations']?['nodes'] as List?;
              if (nodes != null) {
                for (final node in nodes) {
                  if (node is Map && node['mediaRecommendation'] is Map<String, dynamic>) {
                    final rec = node['mediaRecommendation'] as Map<String, dynamic>;
                    final recId = rec['id'] as int? ?? 0;
                    if (recId > 0 && !seenIds.contains(recId)) {
                      seenIds.add(recId);
                      results.add(AnimeEntry.fromJson(rec));
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching recommendations for media \$id: \$e');
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error getting user recommendations: \$e');
      return [];
    }
  }

  Future<bool> scanLibrary() async {
    try {
      final response = await _apiClient.post(ApiEndpoints.libraryScan);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error triggering library scan: $e');
      return false;
    }
  }

  // ================= Airing Schedule & Genre Discovery =================

  Future<List<AiringScheduleItem>> getAiringSchedule({
    int? startTimestamp,
    int? endTimestamp,
    int page = 1,
    int perPage = 50,
  }) async {
    final start = startTimestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000 - 86400);
    final end = endTimestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 7 * 86400);

    try {
      final res = await _externalDio.post(
        'https://graphql.anilist.co',
        data: {
          'query': '''
            query (\$start: Int, \$end: Int, \$page: Int, \$perPage: Int) {
              Page(page: \$page, perPage: \$perPage) {
                airingSchedules(airingAt_greater: \$start, airingAt_lesser: \$end, sort: TIME) {
                  id
                  airingAt
                  episode
                  timeUntilAiring
                  media {
                    id
                    title {
                      userPreferred
                      romaji
                      english
                      native
                    }
                    coverImage {
                      extraLarge
                      large
                      medium
                    }
                    bannerImage
                    format
                    status
                    episodes
                    averageScore
                    genres
                    nextAiringEpisode {
                      airingAt
                      timeUntilAiring
                      episode
                    }
                  }
                }
              }
            }
          ''',
          'variables': {
            'start': start,
            'end': end,
            'page': page,
            'perPage': perPage,
          },
        },
      );

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        if (data is Map<String, dynamic>) {
          final list = data['data']?['Page']?['airingSchedules'] as List?;
          if (list != null) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((item) => AiringScheduleItem.fromJson(item))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching airing schedule: $e');
    }
    return [];
  }

  static const Set<String> anilistOfficialGenres = {
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Hentai',
    'Horror',
    'Mahou Shoujo',
    'Mecha',
    'Music',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
  };

  Future<List<AnimeEntry>> discoverAnime({
    String? search,
    List<String>? genres,
    List<String>? tags,
    String? season,
    int? year,
    String? format,
    String? status,
    String sort = 'TRENDING_DESC',
    int page = 1,
    int perPage = 24,
  }) async {
    try {
      final queryParams = <String>['\$page: Int', '\$perPage: Int', '\$sort: [MediaSort]'];
      final mediaArgs = <String>['type: ANIME', 'sort: \$sort', 'isAdult: false'];
      final variables = <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'sort': [sort],
      };

      if (search != null && search.trim().isNotEmpty) {
        queryParams.add('\$search: String');
        mediaArgs.add('search: \$search');
        variables['search'] = search.trim();
      }
      if (genres != null && genres.isNotEmpty) {
        queryParams.add('\$genre_in: [String]');
        mediaArgs.add('genre_in: \$genre_in');
        variables['genre_in'] = genres;
      }
      if (tags != null && tags.isNotEmpty) {
        queryParams.add('\$tag_in: [String]');
        mediaArgs.add('tag_in: \$tag_in');
        variables['tag_in'] = tags;
      }
      if (season != null && season.isNotEmpty) {
        queryParams.add('\$season: MediaSeason');
        mediaArgs.add('season: \$season');
        variables['season'] = season;
      }
      if (year != null) {
        queryParams.add('\$seasonYear: Int');
        mediaArgs.add('seasonYear: \$seasonYear');
        variables['seasonYear'] = year;
      }
      if (format != null && format.isNotEmpty) {
        queryParams.add('\$format_in: [MediaFormat]');
        mediaArgs.add('format_in: \$format_in');
        variables['format_in'] = [format];
      }
      if (status != null && status.isNotEmpty) {
        queryParams.add('\$status_in: [MediaStatus]');
        mediaArgs.add('status_in: \$status_in');
        variables['status_in'] = [status];
      }

      final query = '''
        query (${queryParams.join(', ')}) {
          Page(page: \$page, perPage: \$perPage) {
            media(${mediaArgs.join(', ')}) {
              id
              title {
                userPreferred
                romaji
                english
                native
              }
              coverImage {
                extraLarge
                large
                medium
              }
              bannerImage
              format
              status
              episodes
              averageScore
              genres
              seasonYear
              description
              nextAiringEpisode {
                airingAt
                timeUntilAiring
                episode
              }
            }
          }
        }
      ''';

      final res = await _externalDio.post(
        'https://graphql.anilist.co',
        data: {
          'query': query,
          'variables': variables,
        },
      );

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        if (data is Map<String, dynamic>) {
          final list = data['data']?['Page']?['media'] as List?;
          if (list != null) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((item) => AnimeEntry.fromJson(item))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error discovering anime: $e');
    }
    return [];
  }

  Future<List<MangaEntry>> discoverManga({
    String? search,
    List<String>? genres,
    List<String>? tags,
    int? year,
    String? format,
    String? status,
    String sort = 'TRENDING_DESC',
    int page = 1,
    int perPage = 24,
  }) async {
    try {
      final queryParams = <String>['\$page: Int', '\$perPage: Int', '\$sort: [MediaSort]'];
      final mediaArgs = <String>['type: MANGA', 'sort: \$sort', 'isAdult: false'];
      final variables = <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'sort': [sort],
      };

      if (search != null && search.trim().isNotEmpty) {
        queryParams.add('\$search: String');
        mediaArgs.add('search: \$search');
        variables['search'] = search.trim();
      }
      if (genres != null && genres.isNotEmpty) {
        queryParams.add('\$genre_in: [String]');
        mediaArgs.add('genre_in: \$genre_in');
        variables['genre_in'] = genres;
      }
      if (tags != null && tags.isNotEmpty) {
        queryParams.add('\$tag_in: [String]');
        mediaArgs.add('tag_in: \$tag_in');
        variables['tag_in'] = tags;
      }
      if (year != null) {
        queryParams.add('\$year: String');
        mediaArgs.add('startDate_like: \$year');
        variables['year'] = '$year%';
      }
      if (format != null && format.isNotEmpty) {
        queryParams.add('\$format_in: [MediaFormat]');
        mediaArgs.add('format_in: \$format_in');
        variables['format_in'] = [format];
      }
      if (status != null && status.isNotEmpty) {
        queryParams.add('\$status_in: [MediaStatus]');
        mediaArgs.add('status_in: \$status_in');
        variables['status_in'] = [status];
      }

      final query = '''
        query (${queryParams.join(', ')}) {
          Page(page: \$page, perPage: \$perPage) {
            media(${mediaArgs.join(', ')}) {
              id
              title {
                userPreferred
                romaji
                english
                native
              }
              coverImage {
                extraLarge
                large
                medium
              }
              bannerImage
              format
              status
              chapters
              volumes
              averageScore
              genres
              startDate {
                year
              }
              description
            }
          }
        }
      ''';

      final res = await _externalDio.post(
        'https://graphql.anilist.co',
        data: {
          'query': query,
          'variables': variables,
        },
      );

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        if (data is Map<String, dynamic>) {
          final list = data['data']?['Page']?['media'] as List?;
          if (list != null) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((item) => MangaEntry.fromJson(item))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error discovering manga: $e');
    }
    return [];
  }

  Future<List<AnimeEntry>> getAnimeByGenre({
    required String genre,
    String sort = 'TRENDING_DESC',
    int? year,
    int page = 1,
    int perPage = 24,
  }) async {
    final isOfficialGenre = anilistOfficialGenres.contains(genre);
    return discoverAnime(
      genres: isOfficialGenre ? [genre] : null,
      tags: !isOfficialGenre ? [genre] : null,
      year: year,
      sort: sort,
      page: page,
      perPage: perPage,
    );
  }

  Future<List<MangaEntry>> getMangaByGenre({
    required String genre,
    String sort = 'TRENDING_DESC',
    int? year,
    int page = 1,
    int perPage = 24,
  }) async {
    final isOfficialGenre = anilistOfficialGenres.contains(genre);
    return discoverManga(
      genres: isOfficialGenre ? [genre] : null,
      tags: !isOfficialGenre ? [genre] : null,
      year: year,
      sort: sort,
      page: page,
      perPage: perPage,
    );
  }

  // ================= Extensions & Marketplace =================

  Future<List<ExtensionItem>> getAllExtensions({bool withUpdates = true}) async {
    try {
      final response = await _apiClient.post(
        '/extensions/all',
        data: {'withUpdates': withUpdates},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        Map<String, dynamic>? root;
        if (data is Map<String, dynamic>) {
          root = data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : data;
        }

        if (root != null) {
          final result = <ExtensionItem>[];

          // Check for update IDs
          final updateIds = <String>{};
          if (root['hasUpdate'] is List) {
            for (final u in root['hasUpdate'] as List) {
              if (u is Map) {
                final id = u['extensionID']?.toString() ?? u['extensionId']?.toString() ?? u['id']?.toString();
                if (id != null && id.isNotEmpty) {
                  updateIds.add(id);
                }
              }
            }
          }

          // Active/loaded extensions
          if (root['extensions'] is List) {
            for (final ext in root['extensions'] as List) {
              if (ext is Map) {
                final extMap = Map<String, dynamic>.from(ext);
                final id = extMap['id'] as String? ?? '';
                result.add(ExtensionItem.fromJson(
                  extMap,
                  disabled: false,
                  hasUpdate: updateIds.contains(id),
                ));
              }
            }
          }

          // Disabled extensions
          if (root['disabledExtensions'] is List) {
            for (final ext in root['disabledExtensions'] as List) {
              if (ext is Map) {
                final extMap = Map<String, dynamic>.from(ext);
                final id = extMap['id'] as String? ?? '';
                result.add(ExtensionItem.fromJson(
                  extMap,
                  disabled: true,
                  hasUpdate: updateIds.contains(id),
                ));
              }
            }
          }

          return result;
        }
      }
    } catch (e) {
      debugPrint('Error fetching extensions: $e');
    }
    return [];
  }

  Future<bool> installExtension(String manifestUri) async {
    try {
      final response = await _apiClient.post(
        '/extensions/external/install',
        data: {
          'manifestUri': manifestUri.trim(),
          'manifestURI': manifestUri.trim(),
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error installing extension: $e');
      return false;
    }
  }

  Future<bool> installRepository(String repoUri) async {
    try {
      final response = await _apiClient.post(
        '/extensions/external/install-repository',
        data: {
          'repositoryUri': repoUri.trim(),
          'install': true,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error installing extension repository: $e');
      return false;
    }
  }

  Future<bool> uninstallExtension(String id) async {
    try {
      final response = await _apiClient.post(
        '/extensions/external/uninstall',
        data: {'id': id},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error uninstalling extension: $e');
      return false;
    }
  }

  Future<bool> setExtensionDisabled(String id, bool disabled) async {
    try {
      final response = await _apiClient.post(
        '/extensions/external/disabled',
        data: {'id': id, 'disabled': disabled},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error toggling extension: $e');
      return false;
    }
  }

  Future<bool> reloadExtensions() async {
    try {
      final response = await _apiClient.post('/extensions/external/reload');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error reloading extensions: $e');
      return false;
    }
  }

  Future<String?> getExtensionPayload(String id) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.extensionPayload}/$id');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data['data']?.toString();
        }
        return data.toString();
      }
    } catch (e) {
      debugPrint('Error getting extension payload: $e');
    }
    return null;
  }

  final Map<String, List<ExtensionItem>> _marketplaceCache = {};

  Future<List<ExtensionItem>> getMarketplaceExtensions(String repoUrl, {bool forceRefresh = false}) async {
    final key = repoUrl.trim();
    if (!forceRefresh && _marketplaceCache.containsKey(key)) {
      return _marketplaceCache[key]!;
    }
    try {
      final response = await _externalDio.get(key);
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        final decoded = raw is String ? jsonDecode(raw) : raw;
        List<dynamic>? list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          list = decoded['extensions'] as List? ?? decoded['data'] as List?;
        }
        if (list != null) {
          final items = list
              .whereType<Map<String, dynamic>>()
              .map((item) => ExtensionItem.fromJson(item))
              .where((item) => item.type.toLowerCase() != 'plugin')
              .toList();
          _marketplaceCache[key] = items;
          return items;
        }
      }
    } catch (e) {
      debugPrint('Error fetching marketplace extensions from $repoUrl: $e');
    }
    return _marketplaceCache[key] ?? [];
  }

  // ================= Library Entry Details =================

  Future<LibraryEntryDetails?> getAnimeLibraryEntry(int mediaId) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.animeEntry}/$mediaId');
      if (response.statusCode == 200 && response.data != null) {
        return LibraryEntryDetails.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error fetching anime library entry $mediaId: $e');
    }
    return null;
  }

  // ================= Online Streaming =================

  Future<List<OnlinestreamProvider>> getOnlinestreamProviders() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.listOnlinestreamProviders);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<dynamic>? list;
        if (data is Map<String, dynamic>) {
          list = data['data'] as List?;
        } else if (data is List) {
          list = data;
        }
        if (list != null && list.isNotEmpty) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(OnlinestreamProvider.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching onlinestream providers: $e');
    }

    // Fallback to getAllExtensions
    try {
      final all = await getAllExtensions();
      final onlinestreamExts = all
          .where((e) => e.type == 'onlinestream-provider' && !e.disabled)
          .map((e) => OnlinestreamProvider(
                id: e.id,
                name: e.name,
                lang: e.lang,
                supportsDub: true,
              ))
          .toList();
      return onlinestreamExts;
    } catch (_) {}

    return [];
  }

  Future<bool> ensureOnlineStreamingEnabled() async {
    try {
      final patchRes = await _apiClient.patch(
        '/settings/path',
        data: {
          'path': 'library.enableOnlinestream',
          'value': true,
        },
      );
      if (patchRes.statusCode == 200) return true;
    } catch (_) {}

    try {
      final startRes = await _apiClient.post(
        '/start',
        data: {
          'library': {
            'libraryPath': '',
            'libraryPaths': <String>[],
            'enableOnlinestream': true,
            'includeOnlineStreamingInLibrary': true,
          },
          'mediaPlayer': {
            'defaultPlayer': 'built-in',
          },
          'torrent': {
            'defaultTorrentClient': 'none',
          },
          'anilist': {},
          'discord': {},
          'manga': {},
          'notifications': {},
          'nakama': {},
        },
      );
      return startRes.statusCode == 200;
    } catch (e) {
      debugPrint('ensureOnlineStreamingEnabled fallback error: $e');
      return false;
    }
  }

  Future<bool> ensureTorrentStreamingEnabled() async {
    try {
      final res = await _apiClient.get('/torrentstream/settings');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;
        final settings = (data?['data'] is Map<String, dynamic>)
            ? data!['data'] as Map<String, dynamic>
            : (data ?? <String, dynamic>{});

        if (settings['enabled'] == true) {
          return true;
        }

        final updatedSettings = Map<String, dynamic>.from(settings);
        updatedSettings['enabled'] = true;
        if (updatedSettings['torrentClientPort'] == null || updatedSettings['torrentClientPort'] == 0) {
          updatedSettings['torrentClientPort'] = 43213;
        }
        if (updatedSettings['streamingServerPort'] == null || updatedSettings['streamingServerPort'] == 0) {
          updatedSettings['streamingServerPort'] = 43214;
        }
        if (updatedSettings['streamingServerHost'] == null || (updatedSettings['streamingServerHost'] as String).isEmpty) {
          updatedSettings['streamingServerHost'] = '127.0.0.1';
        }

        final patchRes = await _apiClient.patch(
          '/torrentstream/settings',
          data: {'settings': updatedSettings},
        );
        return patchRes.statusCode == 200;
      }
    } catch (e) {
      debugPrint('ensureTorrentStreamingEnabled check error: $e');
    }

    try {
      final patchRes = await _apiClient.patch(
        '/torrentstream/settings',
        data: {
          'settings': {
            'enabled': true,
            'autoSelect': true,
            'preferredResolution': '',
            'disableIPV6': true,
            'downloadDir': '',
            'addToLibrary': false,
            'torrentClientHost': '',
            'torrentClientPort': 43213,
            'streamingServerHost': '127.0.0.1',
            'streamingServerPort': 43214,
            'includeInLibrary': false,
            'streamUrlAddress': '',
            'slowSeeding': false,
            'preloadNextStream': false,
            'disableAcceleratedStartup': false,
          }
        },
      );
      return patchRes.statusCode == 200;
    } catch (e) {
      debugPrint('ensureTorrentStreamingEnabled fallback error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getTorrentstreamSettings() async {
    try {
      final res = await _apiClient.get('/torrentstream/settings');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;
        if (data?['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data!['data'] as Map);
        }
        return data != null ? Map<String, dynamic>.from(data) : null;
      }
    } catch (e) {
      debugPrint('getTorrentstreamSettings error: $e');
    }
    return null;
  }

  Future<bool> saveTorrentstreamSettings(Map<String, dynamic> settings) async {
    try {
      final res = await _apiClient.patch(
        '/torrentstream/settings',
        data: {'settings': settings},
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('saveTorrentstreamSettings error: $e');
      return false;
    }
  }

  Future<List<OnlinestreamEpisode>> getOnlinestreamEpisodes({
    required int mediaId,
    required String provider,
    bool dubbed = false,
  }) async {
    Future<List<OnlinestreamEpisode>?> doFetch() async {
      final response = await _apiClient.post(
        ApiEndpoints.onlinestreamEpisodeList,
        data: {
          'mediaId': mediaId,
          'provider': provider,
          'dubbed': dubbed,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        Map<String, dynamic>? root;
        if (data is Map<String, dynamic>) {
          root = data['data'] is Map<String, dynamic>
              ? data['data'] as Map<String, dynamic>
              : data;
        }
        final eps = root?['episodes'] as List?;
        if (eps != null) {
          return eps
              .whereType<Map<String, dynamic>>()
              .map(OnlinestreamEpisode.fromJson)
              .toList();
        }
      }
      return null;
    }

    try {
      final res = await doFetch();
      if (res != null) return res;
    } catch (e) {
      debugPrint('Error fetching onlinestream episodes for $mediaId ($provider): $e');
      final isSettingsErr = e.toString().toLowerCase().contains('setting') ||
          (e is DioException &&
              (e.response?.statusCode == 400 ||
                  e.response?.statusCode == 500 ||
                  e.response?.data.toString().contains('setting') == true));
      if (isSettingsErr) {
        debugPrint('Auto-enabling online streaming setting and retrying...');
        await ensureOnlineStreamingEnabled();
        try {
          final retryRes = await doFetch();
          if (retryRes != null) return retryRes;
        } catch (retryErr) {
          debugPrint('Retry fetching onlinestream episodes failed: $retryErr');
        }
      }
    }
    return [];
  }

  Future<List<OnlinestreamVideoSource>> getOnlinestreamSource({
    required int mediaId,
    required int episodeNumber,
    required String provider,
    bool dubbed = false,
    bool refresh = false,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.onlinestreamEpisodeSource,
        data: {
          'mediaId': mediaId,
          'episodeNumber': episodeNumber,
          'provider': provider,
          'dubbed': dubbed,
          'refresh': refresh,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        Map<String, dynamic>? root;
        if (data is Map<String, dynamic>) {
          root = data['data'] is Map<String, dynamic>
              ? data['data'] as Map<String, dynamic>
              : data;
        }
        final sources = root?['videoSources'] as List?;
        if (sources != null) {
          return sources
              .whereType<Map<String, dynamic>>()
              .map(OnlinestreamVideoSource.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching onlinestream sources: $e');
    }
    return [];
  }

  Future<List<OnlinestreamSearchResult>> searchOnlinestreamManual({
    required String provider,
    required String query,
    bool dubbed = false,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _apiClient.post(
        ApiEndpoints.onlinestreamSearch,
        data: {
          'provider': provider,
          'query': query.trim(),
          'dubbed': dubbed,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<dynamic>? list;
        if (data is Map<String, dynamic>) {
          list = data['data'] as List?;
        } else if (data is List) {
          list = data;
        }
        if (list != null) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(OnlinestreamSearchResult.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error searching onlinestream manually for $query ($provider): $e');
    }
    return [];
  }

  Future<String?> getOnlinestreamMapping({
    required String provider,
    required int mediaId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.onlinestreamGetMapping,
        data: {
          'provider': provider,
          'mediaId': mediaId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final root = data['data'] is Map<String, dynamic> ? data['data'] : data;
          final animeId = root['animeId'] as String?;
          if (animeId != null && animeId.isNotEmpty) {
            return animeId;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting onlinestream mapping for $mediaId ($provider): $e');
    }
    return null;
  }

  Future<bool> setOnlinestreamManualMapping({
    required String provider,
    required int mediaId,
    required String animeId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.onlinestreamManualMapping,
        data: {
          'provider': provider,
          'mediaId': mediaId,
          'animeId': animeId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error setting onlinestream manual mapping: $e');
      return false;
    }
  }

  Future<bool> removeOnlinestreamMapping({
    required String provider,
    required int mediaId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.onlinestreamRemoveMapping,
        data: {
          'provider': provider,
          'mediaId': mediaId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removing onlinestream mapping: $e');
      return false;
    }
  }

  Future<bool> emptyOnlinestreamCache(int mediaId) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.onlinestreamCache,
        data: {
          'mediaId': mediaId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error emptying onlinestream cache for $mediaId: $e');
      return false;
    }
  }

  // ================= Torrent Providers & Search =================

  Future<List<AnimeTorrentProvider>> getAnimeTorrentProviders() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.listAnimeTorrentProviders);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<dynamic>? list;
        if (data is Map<String, dynamic>) {
          list = data['data'] as List?;
        } else if (data is List) {
          list = data;
        }
        if (list != null && list.isNotEmpty) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(AnimeTorrentProvider.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching torrent providers: $e');
    }

    // Fallback to getAllExtensions
    try {
      final all = await getAllExtensions();
      return all
          .where((e) => e.type == 'anime-torrent-provider' && !e.disabled)
          .map((e) => AnimeTorrentProvider(
                id: e.id,
                name: e.name,
                lang: e.lang,
              ))
          .toList();
    } catch (_) {}

    return [];
  }

  Future<List<TorrentItem>> searchTorrents({
    required int mediaId,
    int? episodeNumber,
    String? provider,
    String? query,
    String type = 'smart',
    bool batch = false,
    AnimeDetails? animeDetails,
  }) async {
    try {
      final mediaMap = animeDetails?.toMediaMap() ?? {
        'id': mediaId,
        'isAdult': false,
        'status': 'FINISHED',
        'format': 'TV',
        'episodes': 12,
        'synonyms': <String>[],
        'title': {
          'romaji': '',
          'english': '',
          'userPreferred': '',
        },
        'startDate': {
          'year': 2020,
          'month': 1,
          'day': 1,
        },
      };

      final payload = <String, dynamic>{
        'type': type,
        'batch': batch,
        'media': mediaMap,
      };
      if (provider != null && provider.isNotEmpty && provider != 'none') {
        payload['provider'] = provider;
      }
      if (query != null && query.trim().isNotEmpty) {
        payload['query'] = query.trim();
      }
      if (episodeNumber != null && episodeNumber > 0) {
        payload['episodeNumber'] = episodeNumber;
      }

      final response = await _apiClient.post(
        ApiEndpoints.torrentSearch,
        data: payload,
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        Map<String, dynamic>? root;
        if (data is Map<String, dynamic>) {
          root = data['data'] is Map<String, dynamic>
              ? data['data'] as Map<String, dynamic>
              : data;
        }
        final list = root?['torrents'] as List?;
        if (list != null && list.isNotEmpty) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(TorrentItem.fromJson)
              .toList();
        }
        final previews = root?['previews'] as List?;
        if (previews != null && previews.isNotEmpty) {
          return previews
              .whereType<Map<String, dynamic>>()
              .map((p) => p['torrent'])
              .whereType<Map<String, dynamic>>()
              .map(TorrentItem.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error searching torrents for $mediaId: $e');
    }
    return [];
  }

  Future<bool> startTorrentStream({
    required int mediaId,
    required int episodeNumber,
    String? aniDBEpisode,
    TorrentItem? torrent,
    int? fileIndex,
    bool autoSelect = false,
    String playbackType = 'default',
  }) async {
    try {
      await ensureTorrentStreamingEnabled();

      final payload = <String, dynamic>{
        'mediaId': mediaId,
        'episodeNumber': episodeNumber,
        'aniDBEpisode': aniDBEpisode ?? episodeNumber.toString(),
        'autoSelect': autoSelect,
        'playbackType': playbackType,
        'clientId': 'seanime-app',
      };
      if (torrent != null) {
        payload['torrent'] = torrent.toJson();
      }
      if (fileIndex != null) {
        payload['fileIndex'] = fileIndex;
      }

      final response = await _apiClient.post(
        ApiEndpoints.torrentstreamStart,
        data: payload,
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error starting torrent stream: $e');
      return false;
    }
  }

  Future<bool> stopTorrentStream() async {
    // On Android/mobile, calling /torrentstream/stop in the embedded Go server causes
    // a mutex deadlock because desktop media players are uninitialized (nil pointer).
    // The Go server automatically handles dropping previous excess torrents when a new stream starts.
    if (Platform.isAndroid || Platform.isIOS) {
      debugPrint('[Repository] Skipping stopTorrentStream on mobile to prevent embedded server deadlock');
      return true;
    }
    try {
      final response = await _apiClient.post(
        ApiEndpoints.torrentstreamStop,
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error stopping torrent stream: $e');
      return false;
    }
  }

  // ─── MANGA REPOSITORY METHODS ───

  Future<List<MangaProvider>> getMangaProviders() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.listMangaProviders);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        List<dynamic>? list;
        if (data is Map<String, dynamic>) {
          list = data['data'] as List?;
        } else if (data is List) {
          list = data;
        }
        if (list != null && list.isNotEmpty) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(MangaProvider.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching manga providers: $e');
    }

    // Fallback to getAllExtensions
    try {
      final all = await getAllExtensions();
      final mangaExts = all
          .where((e) => e.type == 'manga-provider' && !e.disabled)
          .map((e) => MangaProvider(
                id: e.id,
                name: e.name,
                lang: e.lang,
                icon: e.icon,
              ))
          .toList();
      return mangaExts;
    } catch (_) {}

    return [];
  }

  Future<List<MangaEntry>> getMangaCollection() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.mangaCollection);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final root = data is Map<String, dynamic> && data['data'] != null
            ? data['data'] as Map<String, dynamic>
            : (data is Map<String, dynamic> ? data : null);
        final lists = root?['lists'] as List?;
        final result = <MangaEntry>[];
        if (lists != null) {
          for (final l in lists) {
            if (l is Map<String, dynamic>) {
              final entries = l['entries'] as List?;
              if (entries != null) {
                for (final e in entries) {
                  if (e is Map<String, dynamic>) {
                    result.add(MangaEntry.fromJson(e));
                  }
                }
              }
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('Error fetching manga collection: $e');
    }

    // Fallback to /manga/anilist/collection
    try {
      final res = await _apiClient.get(ApiEndpoints.mangaAnilistCollection);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        final root = data is Map<String, dynamic> && data['data'] != null
            ? data['data'] as Map<String, dynamic>
            : (data is Map<String, dynamic> ? data : null);
        final lists = (root?['lists'] ?? root?['MediaListCollection']?['lists']) as List?;
        final result = <MangaEntry>[];
        if (lists != null) {
          for (final l in lists) {
            if (l is Map<String, dynamic>) {
              final entries = l['entries'] as List?;
              if (entries != null) {
                for (final e in entries) {
                  if (e is Map<String, dynamic>) {
                    result.add(MangaEntry.fromJson(e));
                  }
                }
              }
            }
          }
        }
        return result;
      }
    } catch (_) {}

    return [];
  }

  Future<List<MangaEntry>> getContinueReadingManga() async {
    try {
      final collection = await getMangaCollection();
      final reading = collection
          .where((e) => e.status == 'CURRENT' || e.status == 'READING')
          .toList();
      return reading;
    } catch (e) {
      debugPrint('Error getting continue reading manga: $e');
      return [];
    }
  }

  Future<List<MangaEntry>> getTrendingManga({int page = 1, int perPage = 12}) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mangaAnilistList,
        data: {
          'page': page,
          'perPage': perPage,
          'sort': ['TRENDING_DESC'],
        },
      );
      return _parseMangaMediaPage(response.data);
    } catch (e) {
      debugPrint('Error fetching trending manga: $e');
      return [];
    }
  }

  Future<List<MangaEntry>> getPopularManga({int page = 1, int perPage = 12}) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mangaAnilistList,
        data: {
          'page': page,
          'perPage': perPage,
          'sort': ['POPULARITY_DESC'],
        },
      );
      return _parseMangaMediaPage(response.data);
    } catch (e) {
      debugPrint('Error fetching popular manga: $e');
      return [];
    }
  }

  Future<List<MangaEntry>> searchManga(String query, {int page = 1, int perPage = 20}) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mangaAnilistList,
        data: {
          'page': page,
          'perPage': perPage,
          'search': query,
        },
      );
      return _parseMangaMediaPage(response.data);
    } catch (e) {
      debugPrint('Error searching manga: $e');
      return [];
    }
  }

  List<MangaEntry> _parseMangaMediaPage(dynamic responseData) {
    if (responseData == null) return [];
    final list = <MangaEntry>[];

    Map<String, dynamic>? root;
    if (responseData is Map<String, dynamic>) {
      root = responseData['data'] is Map<String, dynamic>
          ? responseData['data'] as Map<String, dynamic>
          : responseData;
    }

    if (root != null) {
      final page = root['Page'] as Map<String, dynamic>? ?? root;
      final media = (page['media'] ?? root['media']) as List?;
      if (media != null) {
        for (final item in media) {
          if (item is Map<String, dynamic>) {
            list.add(MangaEntry.fromJson(item));
          }
        }
      }
    }
    return list;
  }

  Future<MangaEntry?> getMangaDetails(int mediaId, {MangaEntry? initialEntry}) async {
    try {
      final results = await Future.wait([
        _apiClient.get('${ApiEndpoints.mangaEntry}/$mediaId').then<dynamic>((r) => r).catchError((_) => null),
        _apiClient.get('${ApiEndpoints.mangaEntry}/$mediaId/details').then<dynamic>((r) => r).catchError((_) => null),
      ]);

      final entryRes = results[0];
      final detailsRes = results[1];

      Map<String, dynamic>? entryData;
      if (entryRes != null && entryRes.data != null) {
        final d = entryRes.data;
        entryData = d is Map<String, dynamic> && d['data'] != null
            ? d['data'] as Map<String, dynamic>
            : (d is Map<String, dynamic> ? d : null);
      }

      Map<String, dynamic>? detailsData;
      if (detailsRes != null && detailsRes.data != null) {
        final d = detailsRes.data;
        detailsData = d is Map<String, dynamic> && d['data'] != null
            ? d['data'] as Map<String, dynamic>
            : (d is Map<String, dynamic> ? d : null);
      }

      if (entryData != null) {
        final entry = MangaEntry.fromJson(entryData);
        final raw = detailsData ?? entry.rawMedia;
        return entry.copyWith(
          description: entry.description ?? (detailsData?['description'] as String?),
          rawMedia: raw,
        );
      } else if (detailsData != null) {
        return MangaEntry.fromJson(detailsData).copyWith(rawMedia: detailsData);
      }
    } catch (e) {
      debugPrint('Error fetching manga details: $e');
    }
    return initialEntry;
  }

  Future<MangaChapterContainer?> getMangaChapters({
    required int mediaId,
    required String provider,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mangaChapters,
        data: {
          'mediaId': mediaId,
          'provider': provider,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        final map = d is Map<String, dynamic> && d['data'] != null
            ? d['data'] as Map<String, dynamic>
            : (d is Map<String, dynamic> ? d : null);
        if (map != null) {
          return MangaChapterContainer.fromJson(map);
        }
      }
    } catch (e) {
      debugPrint('Error getting manga chapters for provider $provider: $e');
    }
    return null;
  }

  Future<List<MangaPage>> getMangaPages({
    required int mediaId,
    required String provider,
    required String chapterId,
    bool doublePage = false,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mangaPages,
        data: {
          'mediaId': mediaId,
          'provider': provider,
          'chapterId': chapterId,
          'doublePage': doublePage,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        final map = d is Map<String, dynamic> && d['data'] != null
            ? d['data'] as Map<String, dynamic>
            : (d is Map<String, dynamic> ? d : null);
        final pagesList = map?['pages'] as List?;
        if (pagesList != null) {
          return pagesList
              .whereType<Map<String, dynamic>>()
              .map(MangaPage.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getting manga pages: $e');
    }
    return [];
  }

  Future<bool> updateMangaProgress({
    required int mediaId,
    required int chapterNumber,
    int? totalChapters,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mangaUpdateProgress,
        data: {
          'mediaId': mediaId,
          'chapterNumber': chapterNumber,
          'totalChapters': totalChapters ?? 0,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating manga progress: $e');
      return false;
    }
  }

  Future<bool> emptyMangaCache(int mediaId) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.mangaCache,
        data: {'mediaId': mediaId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error emptying manga cache: $e');
      return false;
    }
  }

  Future<bool> downloadMangaChapters({
    required int mediaId,
    required String provider,
    required List<String> chapterIds,
    bool startNow = true,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mangaDownloadChapters,
        data: {
          'mediaId': mediaId,
          'provider': provider,
          'chapterIds': chapterIds,
          'startNow': startNow,
        },
        // El servidor procesa cada capítulo síncronamente (~1.4s/cap)
        // antes de responder, así que necesitamos un timeout generoso.
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error downloading manga chapters: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMangaDownloadData(int mediaId, {bool cached = true}) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.mangaDownloadData,
        data: {
          'mediaId': mediaId,
          'cached': cached,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        return d is Map<String, dynamic> && d['data'] != null
            ? d['data'] as Map<String, dynamic>
            : (d is Map<String, dynamic> ? d : null);
      }
    } catch (e) {
      debugPrint('Error getting manga download data: $e');
    }
    return null;
  }

  Future<List<dynamic>> getMangaDownloadQueue() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.mangaDownloadQueue);
      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        final list = d is Map<String, dynamic> && d['data'] is List
            ? d['data'] as List
            : (d is List ? d : []);
        return list;
      }
    } catch (e) {
      debugPrint('Error getting manga download queue: $e');
    }
    return [];
  }

  Future<bool> startMangaDownloadQueue() async {
    try {
      final response = await _apiClient.post(ApiEndpoints.mangaDownloadQueueStart);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error starting manga download queue: $e');
      return false;
    }
  }

  Future<bool> stopMangaDownloadQueue() async {
    try {
      final response = await _apiClient.post(ApiEndpoints.mangaDownloadQueueStop);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error stopping manga download queue: $e');
      return false;
    }
  }

  Future<bool> deleteMangaDownloadedChapters(List<Map<String, dynamic>> downloadIds) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.mangaDownloadChapterDelete,
        data: {'downloadIds': downloadIds},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting downloaded chapters: $e');
      return false;
    }
  }

  Future<List<dynamic>> getMangaDownloadsList() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.mangaDownloadsList);
      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        final list = d is Map<String, dynamic> && d['data'] is List
            ? d['data'] as List
            : (d is List ? d : []);
        return list;
      }
    } catch (e) {
      debugPrint('Error getting manga downloads list: $e');
    }
    return [];
  }

  /// Obtiene los IDs descargados y en cola para un manga en una sola llamada,
  /// utilizando cached: true para evitar disparar hydrateMediaMap() y eventos WS recurrentes.
  Future<MangaDownloadInfo> getMangaDownloadInfo(int mediaId) async {
    final downloaded = <String>{};
    final queued = <String>{};

    try {
      final downloadData = await getMangaDownloadData(mediaId, cached: true);
      if (downloadData != null) {
        final downloadedMap = downloadData['downloaded'];
        if (downloadedMap is Map<String, dynamic>) {
          for (final list in downloadedMap.values) {
            if (list is List) {
              for (final ch in list) {
                if (ch is Map<String, dynamic>) {
                  final id = ch['chapterId'] as String? ?? ch['id'] as String? ?? '';
                  if (id.isNotEmpty) downloaded.add(id);
                }
              }
            }
          }
        }

        final queuedMap = downloadData['queued'];
        if (queuedMap is Map<String, dynamic>) {
          for (final list in queuedMap.values) {
            if (list is List) {
              for (final ch in list) {
                if (ch is Map<String, dynamic>) {
                  final id = ch['chapterId'] as String? ?? ch['id'] as String? ?? '';
                  if (id.isNotEmpty) queued.add(id);
                }
              }
            }
          }
        }

        if (downloaded.isNotEmpty || queued.isNotEmpty) {
          return MangaDownloadInfo(downloadedIds: downloaded, queuedIds: queued);
        }
      }

      // Fallback: API de contenedores de capítulos descargados
      final response = await _apiClient.get(
        '${ApiEndpoints.mangaDownloadedChapters}/$mediaId',
      );
      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        final list = d is Map<String, dynamic> && d['data'] is List
            ? d['data'] as List
            : (d is List ? d : []);
        for (final container in list) {
          if (container is Map<String, dynamic>) {
            final chaptersList = container['chapters'] as List?;
            if (chaptersList != null) {
              for (final ch in chaptersList) {
                if (ch is Map<String, dynamic>) {
                  final chId = ch['id'] as String? ?? ch['chapterId'] as String? ?? '';
                  if (chId.isNotEmpty) downloaded.add(chId);
                }
              }
            }
            final flatId = container['chapterId'] as String? ?? container['id'] as String? ?? '';
            if (flatId.isNotEmpty) downloaded.add(flatId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting manga download info: $e');
    }

    return MangaDownloadInfo(downloadedIds: downloaded, queuedIds: queued);
  }

  /// Consulta al servidor Go los capítulos descargados para un manga.
  /// Retorna un Set de chapterIds que están completamente descargados.
  Future<Set<String>> getServerDownloadedChapterIds(int mediaId) async {
    final info = await getMangaDownloadInfo(mediaId);
    return info.downloadedIds;
  }

  /// Consulta la cola de descarga del servidor y retorna los chapterIds
  /// que están en cola o descargándose para un mediaId específico.
  Future<Set<String>> getDownloadQueueChapterIds(int mediaId) async {
    final info = await getMangaDownloadInfo(mediaId);
    return info.queuedIds;
  }

  /// Retorna los objetos MangaChapter descargados para una obra desde el servidor.
  Future<List<MangaChapter>> getServerDownloadedChapters(int mediaId) async {
    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.mangaDownloadedChapters}/$mediaId',
      );
      if (response.statusCode == 200 && response.data != null) {
        final d = response.data;
        final list = d is Map<String, dynamic> && d['data'] is List
            ? d['data'] as List
            : (d is List ? d : []);
        final chapters = <MangaChapter>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final container = MangaChapterContainer.fromJson(item);
            chapters.addAll(container.chapters);
          }
        }
        return chapters;
      }
    } catch (e) {
      debugPrint('Error getting server downloaded chapter list: $e');
    }
    return [];
  }
}

class MangaDownloadInfo {
  final Set<String> downloadedIds;
  final Set<String> queuedIds;

  const MangaDownloadInfo({
    required this.downloadedIds,
    required this.queuedIds,
  });

  static const empty = MangaDownloadInfo(downloadedIds: {}, queuedIds: {});
}
