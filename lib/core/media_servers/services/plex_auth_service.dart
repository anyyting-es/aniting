import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/media_server_config.dart';
import '../models/media_server_type.dart';

/// Representa una conexión o endpoint anunciado por un servidor Plex.
class PlexServerCandidate {
  final String name;
  final String clientIdentifier;
  final String accessToken;
  final List<String> candidateUrls;

  const PlexServerCandidate({
    required this.name,
    required this.clientIdentifier,
    required this.accessToken,
    required this.candidateUrls,
  });
}

/// Servicio para manejar la autenticación oficial de Plex vía PIN / OAuth.
class PlexAuthService {
  static const String _appName = 'Aniting';
  static const String _plexApiBase = 'https://plex.tv/api/v2';

  final String clientIdentifier;

  PlexAuthService({String? clientIdentifier})
      : clientIdentifier = clientIdentifier ?? const Uuid().v4();

  Map<String, String> _headers({String? token}) {
    final map = {
      'Accept': 'application/json',
      'X-Plex-Product': _appName,
      'X-Plex-Client-Identifier': clientIdentifier,
      'X-Plex-Platform': 'Flutter',
      'X-Plex-Device': 'Desktop/Mobile',
    };
    if (token != null) {
      map['X-Plex-Token'] = token;
    }
    return map;
  }

  /// Crea un PIN en plex.tv para que el usuario autorice la app.
  /// Retorna un mapa con `id`, `code` y la URL para navegar o mostrar en QR.
  Future<Map<String, dynamic>> createPin() async {
    final uri = Uri.parse('$_plexApiBase/pins?strong=true');
    final response = await http.post(uri, headers: _headers());

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final code = data['code']?.toString() ?? '';
      final id = data['id'];
      final authUrl =
          'https://app.plex.tv/auth#?clientID=$clientIdentifier&code=$code&context[device][product]=$_appName';

      return {
        'id': id,
        'code': code,
        'authUrl': authUrl,
      };
    } else {
      throw Exception('Error al generar PIN de Plex (HTTP ${response.statusCode})');
    }
  }

  /// Consulta si el PIN fue reclamado y retorna el `authToken` si está listo.
  Future<String?> checkPin(dynamic pinId) async {
    final uri = Uri.parse('$_plexApiBase/pins/$pinId');
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['authToken'] as String?;
      return (token != null && token.isNotEmpty) ? token : null;
    }
    return null;
  }

  /// Obtiene los servidores Plex vinculados a la cuenta autorizada.
  Future<List<PlexServerCandidate>> getServers(String authToken) async {
    final uri = Uri.parse('$_plexApiBase/resources?includeHttps=1&includeRelay=1&includeIPv6=1');
    final response = await http.get(uri, headers: _headers(token: authToken));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error al consultar servidores de Plex (HTTP ${response.statusCode})');
    }

    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    final results = <PlexServerCandidate>[];

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final provides = item['provides']?.toString() ?? '';
      if (!provides.contains('server')) continue;

      final name = item['name']?.toString() ?? 'Plex Server';
      final machineId = item['clientIdentifier']?.toString() ?? '';
      final accessToken = item['accessToken']?.toString() ?? authToken;

      final connections = item['connections'] as List<dynamic>? ?? [];
      final candidateUrls = <String>[];

      for (final conn in connections) {
        if (conn is! Map<String, dynamic>) continue;
        final uriStr = conn['uri']?.toString();
        if (uriStr != null && uriStr.isNotEmpty) {
          candidateUrls.add(uriStr);
        } else {
          final ip = conn['address']?.toString();
          final port = conn['port']?.toString() ?? '32400';
          final proto = conn['protocol']?.toString() ?? 'http';
          if (ip != null) {
            candidateUrls.add('$proto://$ip:$port');
          }
        }
      }

      if (candidateUrls.isNotEmpty) {
        results.add(PlexServerCandidate(
          name: name,
          clientIdentifier: machineId,
          accessToken: accessToken,
          candidateUrls: candidateUrls,
        ));
      }
    }

    return results;
  }

  /// Prueba los endpoints candidatos de un servidor y retorna el primero que responda con éxito.
  Future<String?> findWorkingUrl(List<String> urls, String token) async {
    for (final url in urls) {
      try {
        final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
        final uri = Uri.parse('$cleanUrl/identity');
        final response = await http.get(uri, headers: {
          'X-Plex-Token': token,
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          return cleanUrl;
        }
      } catch (_) {
        // Intenta la siguiente URL
      }
    }
    return urls.isNotEmpty ? urls.first : null;
  }

  /// Construye un `MediaServerConfig` listo para persistir.
  MediaServerConfig buildConfig({
    required PlexServerCandidate candidate,
    required String activeUrl,
  }) {
    return MediaServerConfig(
      id: candidate.clientIdentifier.isNotEmpty
          ? candidate.clientIdentifier
          : const Uuid().v4(),
      name: candidate.name,
      type: MediaServerType.plex,
      url: activeUrl,
      token: candidate.accessToken,
      clientIdentifier: clientIdentifier,
      createdAt: DateTime.now(),
      isOnline: true,
    );
  }
}
