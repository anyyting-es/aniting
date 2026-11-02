import 'dart:convert';
import 'media_server_type.dart';

/// Configuración persistente de una conexión a un servidor multimedia (Plex o Jellyfin).
class MediaServerConfig {
  final String id;
  final String name;
  final MediaServerType type;
  final String url;
  final String token;
  final String? clientIdentifier;
  final String? userId;
  final String? username;
  final DateTime createdAt;
  final bool isOnline;

  const MediaServerConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.token,
    this.clientIdentifier,
    this.userId,
    this.username,
    required this.createdAt,
    this.isOnline = false,
  });

  MediaServerConfig copyWith({
    String? id,
    String? name,
    MediaServerType? type,
    String? url,
    String? token,
    String? clientIdentifier,
    String? userId,
    String? username,
    DateTime? createdAt,
    bool? isOnline,
  }) {
    return MediaServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      token: token ?? this.token,
      clientIdentifier: clientIdentifier ?? this.clientIdentifier,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'url': url,
      'token': token,
      'clientIdentifier': clientIdentifier,
      'userId': userId,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MediaServerConfig.fromMap(Map<String, dynamic> map) {
    return MediaServerConfig(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Media Server',
      type: MediaServerType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MediaServerType.plex,
      ),
      url: map['url'] as String? ?? '',
      token: map['token'] as String? ?? '',
      clientIdentifier: map['clientIdentifier'] as String?,
      userId: map['userId'] as String?,
      username: map['username'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isOnline: false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MediaServerConfig.fromJson(String source) =>
      MediaServerConfig.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
