import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_server_config.dart';
import '../models/media_server_item.dart';
import '../models/media_server_library.dart';

/// Cliente REST para comunicarse directamente con un Plex Media Server.
class PlexService {
  final MediaServerConfig config;

  PlexService(this.config);

  String get _baseUrl => config.url.endsWith('/')
      ? config.url.substring(0, config.url.length - 1)
      : config.url;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'X-Plex-Token': config.token,
        'X-Plex-Client-Identifier': config.clientIdentifier ?? 'Aniting-Client',
      };

  /// Verifica si el servidor está online y accesible.
  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$_baseUrl/identity');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene la lista de bibliotecas (secciones) del servidor Plex.
  Future<List<MediaServerLibrary>> getLibraries() async {
    final uri = Uri.parse('$_baseUrl/library/sections');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('Error al obtener bibliotecas de Plex (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final container = data['MediaContainer'] as Map<String, dynamic>? ?? {};
    final directories = container['Directory'] as List<dynamic>? ?? [];

    return directories.map((d) {
      final map = d as Map<String, dynamic>;
      final typeStr = map['type']?.toString();
      return MediaServerLibrary(
        id: map['key']?.toString() ?? '',
        serverId: config.id,
        title: map['title']?.toString() ?? 'Biblioteca',
        type: MediaServerLibraryType.fromRawType(typeStr),
      );
    }).toList();
  }

  /// Obtiene los elementos "Continuar viendo" (On Deck) del usuario.
  Future<List<MediaServerItem>> getContinueWatching() async {
    final uri = Uri.parse('$_baseUrl/library/onDeck?includeGuids=1');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final container = data['MediaContainer'] as Map<String, dynamic>? ?? {};
    final metadata = container['Metadata'] as List<dynamic>? ?? [];

    return metadata.map((m) => _parseItem(m as Map<String, dynamic>)).toList();
  }

  /// Obtiene los elementos de una sección/biblioteca específica.
  Future<List<MediaServerItem>> getLibraryItems(String sectionId, {int start = 0, int size = 50}) async {
    final uri = Uri.parse(
        '$_baseUrl/library/sections/$sectionId/all?X-Plex-Container-Start=$start&X-Plex-Container-Size=$size&includeGuids=1');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final container = data['MediaContainer'] as Map<String, dynamic>? ?? {};
    final metadata = container['Metadata'] as List<dynamic>? ?? [];

    return metadata.map((m) => _parseItem(m as Map<String, dynamic>)).toList();
  }

  /// Obtiene todos los episodios de una serie a través de su ratingKey.
  Future<List<MediaServerItem>> getShowEpisodes(String showRatingKey) async {
    final uri = Uri.parse('$_baseUrl/library/metadata/$showRatingKey/allLeaves');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final container = data['MediaContainer'] as Map<String, dynamic>? ?? {};
    final metadata = container['Metadata'] as List<dynamic>? ?? [];

    return metadata.map((m) => _parseItem(m as Map<String, dynamic>)).toList();
  }

  /// Construye la URL de reproducción directa (Direct Play) para un ítem o parte.
  String buildStreamUrl(String partKey) {
    final cleanPart = partKey.startsWith('/') ? partKey : '/$partKey';
    return '$_baseUrl$cleanPart?X-Plex-Token=${config.token}';
  }

  /// Reporta el progreso de reproducción a Plex (Timeline).
  Future<void> reportTimeline({
    required String ratingKey,
    required String state, // 'playing', 'paused', 'stopped'
    required int timeMs,
    required int durationMs,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/:/timeline').replace(queryParameters: {
        'ratingKey': ratingKey,
        'state': state,
        'time': timeMs.toString(),
        'duration': durationMs.toString(),
        'X-Plex-Token': config.token,
        'X-Plex-Client-Identifier': config.clientIdentifier ?? 'Aniting-Client',
      });
      await http.get(uri, headers: _headers);
    } catch (_) {}
  }

  /// Marca un ítem como visto en Plex.
  Future<void> markWatched(String ratingKey) async {
    try {
      final uri = Uri.parse('$_baseUrl/:/scrobble').replace(queryParameters: {
        'key': ratingKey,
        'identifier': 'com.plexapp.plugins.library',
        'X-Plex-Token': config.token,
      });
      await http.get(uri, headers: _headers);
    } catch (_) {}
  }

  /// Parsea un mapa de metadata de Plex a nuestro modelo unificado `MediaServerItem`.
  MediaServerItem _parseItem(Map<String, dynamic> map) {
    final ratingKey = map['ratingKey']?.toString() ?? '';
    final typeStr = map['type']?.toString();
    final itemType = MediaServerItemType.fromRaw(typeStr);

    final title = map['title']?.toString() ?? 'Sin título';
    final parentTitle = map['parentTitle']?.toString();
    final grandParentTitle = map['grandparentTitle']?.toString();

    final thumb = map['thumb']?.toString();
    final art = map['art']?.toString();

    final genres = <String>[];
    final rawGenres = map['Genre'];
    if (rawGenres is List) {
      for (final g in rawGenres) {
        if (g is Map && g['tag'] != null) {
          genres.add(g['tag'].toString());
        } else if (g != null) {
          genres.add(g.toString());
        }
      }
    }

    // Prefer the exact logo URL advertised by Plex metadata instead of
    // guessing the clearLogo endpoint, which is not available for every item.
    String? logoUrl;
    final rawImages = map['Image'];
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is! Map) continue;
        final type = img['type']?.toString().toLowerCase();
        if (type != 'clearlogo' && type != 'logo') continue;
        final url = img['url']?.toString();
        if (url == null || url.isEmpty) continue;
        final token = config.token.isEmpty
            ? ''
            : '?X-Plex-Token=${config.token}';
        logoUrl = '$_baseUrl$url$token';
        break;
      }
    }

    // Extraer clave de reproducción de la primera parte si existe
    String? streamPartKey;
    final mediaList = map['Media'] as List<dynamic>?;
    if (mediaList != null && mediaList.isNotEmpty) {
      final parts = (mediaList.first as Map<String, dynamic>)['Part'] as List<dynamic>?;
      if (parts != null && parts.isNotEmpty) {
        streamPartKey = (parts.first as Map<String, dynamic>)['key']?.toString();
      }
    }

    // Marcadores de intro si están disponibles
    int? introStart;
    int? introEnd;
    final markers = map['Marker'] as List<dynamic>?;
    if (markers != null) {
      for (final m in markers) {
        if (m is Map<String, dynamic> && m['type'] == 'intro') {
          introStart = int.tryParse(m['startTimeOffset']?.toString() ?? '');
          introEnd = int.tryParse(m['endTimeOffset']?.toString() ?? '');
        }
      }
    }

    return MediaServerItem(
      id: ratingKey,
      serverId: config.id,
      title: title,
      type: itemType,
      parentId: map['parentRatingKey']?.toString() ?? map['grandparentRatingKey']?.toString(),
      parentTitle: parentTitle,
      grandParentTitle: grandParentTitle,
      grandParentId: map['grandparentRatingKey']?.toString(),
      seasonNumber: int.tryParse(map['parentIndex']?.toString() ?? ''),
      episodeNumber: int.tryParse(map['index']?.toString() ?? ''),
      overview: map['summary']?.toString(),
      year: int.tryParse(map['year']?.toString() ?? ''),
      airDate: map['originallyAvailableAt']?.toString(),
      durationMs: int.tryParse(map['duration']?.toString() ?? ''),
      playbackPositionMs: int.tryParse(map['viewOffset']?.toString() ?? ''),
      thumbUrl: thumb != null ? '$_baseUrl$thumb?X-Plex-Token=${config.token}' : null,
      backdropUrl: art != null ? '$_baseUrl$art?X-Plex-Token=${config.token}' : null,
      streamUrl: streamPartKey != null ? buildStreamUrl(streamPartKey) : null,
      introStartMs: introStart,
      introEndMs: introEnd,
      isWatched: map['viewCount'] != null && (map['viewCount'] as num) > 0,
      rating: double.tryParse(
        (map['rating'] ?? map['audienceRating'])?.toString() ?? '',
      ),
      externalIds: _parseExternalIds(map),
      genres: genres,
      studio: map['studio']?.toString(),
      logoUrl: logoUrl,
      episodeCount: int.tryParse(map['leafCount']?.toString() ?? ''),
      seasonCount: int.tryParse(map['childCount']?.toString() ?? ''),
    );
  }

  Map<String, String>? _parseExternalIds(Map<String, dynamic> map) {
    final ids = <String, String>{};

    void parseGuid(String raw) {
      final match = RegExp(
        r'(tmdb|imdb|tvdb|anilist)://([^?&/]+)',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null) {
        ids[match.group(1)!.toLowerCase()] = match.group(2)!;
      }
    }

    final guid = map['guid'];
    if (guid != null) parseGuid(guid.toString());

    final guids = map['Guid'];
    if (guids is List) {
      for (final g in guids) {
        if (g is Map && g['id'] != null) {
          parseGuid(g['id'].toString());
        } else {
          parseGuid(g.toString());
        }
      }
    }

    return ids.isEmpty ? null : ids;
  }
}
