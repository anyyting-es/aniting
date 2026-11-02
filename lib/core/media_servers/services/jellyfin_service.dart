import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/media_server_config.dart';
import '../models/media_server_item.dart';
import '../models/media_server_library.dart';
import '../models/media_server_type.dart';

/// Cliente REST para comunicarse con servidores Jellyfin / Emby.
class JellyfinService {
  final MediaServerConfig config;

  JellyfinService(this.config);

  String get _baseUrl => config.url.endsWith('/')
      ? config.url.substring(0, config.url.length - 1)
      : config.url;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Emby-Token': config.token,
        'X-Emby-Authorization':
            'MediaBrowser Client="Aniting", Device="Desktop/Mobile", DeviceId="${config.clientIdentifier ?? "Aniting-Client"}", Version="1.0.0"',
      };

  /// Autentica contra un servidor Jellyfin por usuario y contraseña.
  static Future<MediaServerConfig> authenticate({
    required String baseUrl,
    required String username,
    required String password,
    String? clientIdentifier,
  }) async {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final deviceId = clientIdentifier ?? const Uuid().v4();

    final uri = Uri.parse('$cleanBase/Users/AuthenticateByName');
    final authHeader =
        'MediaBrowser Client="Aniting", Device="Desktop/Mobile", DeviceId="$deviceId", Version="1.0.0"';

    final res = await http
        .post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Emby-Authorization': authHeader,
          },
          body: jsonEncode({'Username': username, 'Pw': password}),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Credenciales incorrectas o servidor no accesible (HTTP ${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['AccessToken']?.toString() ?? '';
    final user = data['User'] as Map<String, dynamic>? ?? {};
    final userId = user['Id']?.toString() ?? '';

    return MediaServerConfig(
      id: const Uuid().v4(),
      name: 'Jellyfin ($username)',
      type: MediaServerType.jellyfin,
      url: cleanBase,
      token: token,
      clientIdentifier: deviceId,
      userId: userId,
      username: username,
      createdAt: DateTime.now(),
      isOnline: true,
    );
  }

  /// Prueba si el servidor Jellyfin responde correctamente.
  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$_baseUrl/System/Info/Public');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene las bibliotecas (Vistas) del usuario en Jellyfin.
  Future<List<MediaServerLibrary>> getLibraries() async {
    final userId = config.userId;
    final uri = userId != null && userId.isNotEmpty
        ? Uri.parse('$_baseUrl/Users/$userId/Views')
        : Uri.parse('$_baseUrl/Library/MediaFolders');

    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('Error al obtener bibliotecas de Jellyfin (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['Items'] as List<dynamic>? ?? [];

    return items.map((i) {
      final map = i as Map<String, dynamic>;
      final typeStr = map['CollectionType']?.toString() ?? map['Type']?.toString();
      return MediaServerLibrary(
        id: map['Id']?.toString() ?? '',
        serverId: config.id,
        title: map['Name']?.toString() ?? 'Biblioteca',
        type: MediaServerLibraryType.fromRawType(typeStr),
      );
    }).toList();
  }

  /// Obtiene los elementos en progreso (Resume) de Jellyfin.
  Future<List<MediaServerItem>> getContinueWatching() async {
    final userId = config.userId;
    if (userId == null || userId.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/Users/$userId/Items/Resume?Limit=20&MediaTypes=Video');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['Items'] as List<dynamic>? ?? [];

    return items.map((i) => _parseItem(i as Map<String, dynamic>)).toList();
  }

  /// Obtiene los elementos contenidos en una biblioteca de Jellyfin.
  Future<List<MediaServerItem>> getLibraryItems(String parentId, {int startIndex = 0, int limit = 50}) async {
    final userId = config.userId;
    final uri = Uri.parse(
        '$_baseUrl/Users/$userId/Items?ParentId=$parentId&StartIndex=$startIndex&Limit=$limit&Recursive=true&IncludeItemTypes=Series,Movie&SortBy=SortName&SortOrder=Ascending&Fields=Genres,Studios,ProviderIds,Overview');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['Items'] as List<dynamic>? ?? [];

    return items.map((i) => _parseItem(i as Map<String, dynamic>)).toList();
  }

  /// Obtiene todos los episodios de una serie en Jellyfin.
  Future<List<MediaServerItem>> getShowEpisodes(String seriesId) async {
    final userId = config.userId;
    final uri = Uri.parse('$_baseUrl/Shows/$seriesId/Episodes?userId=$userId');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['Items'] as List<dynamic>? ?? [];

    return items.map((i) => _parseItem(i as Map<String, dynamic>)).toList();
  }

  /// Genera la URL de reproducción directa (Direct Play) para un ítem.
  String buildStreamUrl(String itemId) {
    return '$_baseUrl/Videos/$itemId/stream?static=true&api_key=${config.token}';
  }

  /// Reporta el inicio de reproducción a Jellyfin.
  Future<void> reportPlaybackStart(String itemId) async {
    try {
      final uri = Uri.parse('$_baseUrl/Sessions/Playing');
      await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'ItemId': itemId, 'PlayMethod': 'DirectPlay'}),
      );
    } catch (_) {}
  }

  /// Reporta el progreso de reproducción periódicamente a Jellyfin (en ticks de 100ns).
  Future<void> reportPlaybackProgress(String itemId, int positionMs) async {
    try {
      final ticks = positionMs * 10000;
      final uri = Uri.parse('$_baseUrl/Sessions/Playing/Progress');
      await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'ItemId': itemId,
          'PositionTicks': ticks,
          'PlayMethod': 'DirectPlay',
        }),
      );
    } catch (_) {}
  }

  /// Reporta que se detuvo la reproducción.
  Future<void> reportPlaybackStopped(String itemId, int positionMs) async {
    try {
      final ticks = positionMs * 10000;
      final uri = Uri.parse('$_baseUrl/Sessions/Playing/Stopped');
      await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'ItemId': itemId, 'PositionTicks': ticks}),
      );
    } catch (_) {}
  }

  /// Marca un ítem como visto.
  Future<void> markWatched(String itemId) async {
    final userId = config.userId;
    if (userId == null) return;
    try {
      final uri = Uri.parse('$_baseUrl/Users/$userId/PlayedItems/$itemId');
      await http.post(uri, headers: _headers);
    } catch (_) {}
  }

  /// Parsea un mapa de Jellyfin a nuestro modelo unificado `MediaServerItem`.
  MediaServerItem _parseItem(Map<String, dynamic> map) {
    final id = map['Id']?.toString() ?? '';
    final typeStr = map['Type']?.toString();
    final itemType = MediaServerItemType.fromRaw(typeStr);

    final title = map['Name']?.toString() ?? 'Sin título';
    final seriesName = map['SeriesName']?.toString();
    final seasonName = map['SeasonName']?.toString();

    final runTimeTicks = int.tryParse(map['RunTimeTicks']?.toString() ?? '');
    final durationMs = runTimeTicks != null ? (runTimeTicks / 10000).round() : null;

    final userData = map['UserData'] as Map<String, dynamic>?;
    final playbackTicks = int.tryParse(userData?['PlaybackPositionTicks']?.toString() ?? '');
    final playbackMs = playbackTicks != null ? (playbackTicks / 10000).round() : null;
    final isPlayed = userData?['Played'] == true;

    // Miniatura / Imagen primaria
    final imageTags = map['ImageTags'] as Map<String, dynamic>?;
    final hasPrimary = imageTags != null && imageTags.containsKey('Primary');
    final thumbUrl = hasPrimary ? '$_baseUrl/Items/$id/Images/Primary?fillWidth=600&quality=90&api_key=${config.token}' : null;
    final hasLogo = imageTags != null && imageTags.containsKey('Logo');
    final logoUrl = hasLogo ? '$_baseUrl/Items/$id/Images/Logo?fillWidth=600&quality=90&api_key=${config.token}' : null;

    // Fondo
    final backdropTags = map['BackdropImageTags'] as List<dynamic>?;
    final hasBackdrop = backdropTags != null && backdropTags.isNotEmpty;
    final backdropUrl = hasBackdrop ? '$_baseUrl/Items/$id/Images/Backdrop/0?fillWidth=1600&quality=90&api_key=${config.token}' : null;

    final isEpisode = itemType == MediaServerItemType.episode;
    final streamUrl = (isEpisode || itemType == MediaServerItemType.movie) ? buildStreamUrl(id) : null;

    final genres = <String>[];
    final rawGenres = map['Genres'];
    if (rawGenres is List) {
      for (final g in rawGenres) {
        final value = g?.toString();
        if (value != null && value.isNotEmpty) genres.add(value);
      }
    }

    String? studio;
    final rawStudios = map['Studios'];
    if (rawStudios is List && rawStudios.isNotEmpty) {
      final first = rawStudios.first;
      if (first is Map && first['Name'] != null) {
        studio = first['Name'].toString();
      }
    }

    return MediaServerItem(
      id: id,
      serverId: config.id,
      title: title,
      type: itemType,
      parentId: map['SeriesId']?.toString() ?? map['ParentId']?.toString(),
      parentTitle: seriesName ?? seasonName,
      grandParentTitle: seriesName,
      grandParentId: map['SeriesId']?.toString(),
      seasonNumber: int.tryParse(map['ParentIndexNumber']?.toString() ?? ''),
      episodeNumber: int.tryParse(map['IndexNumber']?.toString() ?? ''),
      overview: map['Overview']?.toString(),
      year: int.tryParse(map['ProductionYear']?.toString() ?? ''),
      airDate: _formatPremiereDate(map['PremiereDate']?.toString()),
      durationMs: durationMs,
      playbackPositionMs: playbackMs,
      thumbUrl: thumbUrl,
      backdropUrl: backdropUrl,
      streamUrl: streamUrl,
      isWatched: isPlayed,
      rating: double.tryParse(
        (map['CommunityRating'] ?? map['CriticRating'])?.toString() ?? '',
      ),
      externalIds: _parseExternalIds(map),
      genres: genres,
      studio: studio,
      logoUrl: logoUrl,
      episodeCount: int.tryParse(
        (map['RecursiveItemCount'] ?? map['RecursiveChildCount'])?.toString() ?? '',
      ),
      seasonCount: int.tryParse(map['ChildCount']?.toString() ?? ''),
    );
  }

  /// Jellyfin reports `PremiereDate` as a full ISO timestamp. The player only
  /// needs the calendar day, which is what AniZip (and the watch page) expect.
  static String? _formatPremiereDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  Map<String, String>? _parseExternalIds(Map<String, dynamic> map) {
    final raw = map['ProviderIds'];
    if (raw is! Map) return null;

    final ids = <String, String>{};
    raw.forEach((key, value) {
      final id = value?.toString();
      if (id == null || id.isEmpty) return;
      ids[key.toString().toLowerCase()] = id;
    });
    return ids.isEmpty ? null : ids;
  }
}
