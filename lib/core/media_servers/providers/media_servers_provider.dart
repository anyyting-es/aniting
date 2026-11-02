import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_server_config.dart';
import '../models/media_server_type.dart';
import '../services/jellyfin_service.dart';
import '../services/plex_service.dart';

const String _kMediaServersKey = 'aniting_media_servers_v1';
const String _kActiveServerIdKey = 'aniting_active_media_server_id_v1';

class MediaServersState {
  final List<MediaServerConfig> servers;
  final String? activeServerId;
  final bool isLoading;

  const MediaServersState({
    this.servers = const [],
    this.activeServerId,
    this.isLoading = false,
  });

  MediaServerConfig? get activeServer {
    if (servers.isEmpty) return null;
    if (activeServerId == null) return servers.first;
    return servers.firstWhere(
      (s) => s.id == activeServerId,
      orElse: () => servers.first,
    );
  }

  MediaServersState copyWith({
    List<MediaServerConfig>? servers,
    String? activeServerId,
    bool? isLoading,
  }) {
    return MediaServersState(
      servers: servers ?? this.servers,
      activeServerId: activeServerId ?? this.activeServerId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MediaServersNotifier extends Notifier<MediaServersState> {
  @override
  MediaServersState build() {
    _loadFromPrefs();
    return const MediaServersState(isLoading: true);
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_kMediaServersKey) ?? [];
      final activeId = prefs.getString(_kActiveServerIdKey);

      final loaded = listJson
          .map((str) {
            try {
              return MediaServerConfig.fromJson(str);
            } catch (_) {
              return null;
            }
          })
          .whereType<MediaServerConfig>()
          .toList();

      state = MediaServersState(
        servers: loaded,
        activeServerId: activeId ?? (loaded.isNotEmpty ? loaded.first.id : null),
        isLoading: false,
      );

      checkAllServersHealth();
    } catch (_) {
      state = const MediaServersState(isLoading: false);
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = state.servers.map((s) => s.toJson()).toList();
    await prefs.setStringList(_kMediaServersKey, listJson);
    if (state.activeServerId != null) {
      await prefs.setString(_kActiveServerIdKey, state.activeServerId!);
    } else {
      await prefs.remove(_kActiveServerIdKey);
    }
  }

  Future<void> addServer(MediaServerConfig server) async {
    final updated = List<MediaServerConfig>.from(state.servers)
      ..removeWhere((s) => s.id == server.id)
      ..add(server);

    state = state.copyWith(
      servers: updated,
      activeServerId: server.id,
    );
    await _saveToPrefs();
  }

  Future<void> removeServer(String id) async {
    final updated = state.servers.where((s) => s.id != id).toList();
    final newActiveId = (state.activeServerId == id)
        ? (updated.isNotEmpty ? updated.first.id : null)
        : state.activeServerId;

    state = state.copyWith(
      servers: updated,
      activeServerId: newActiveId,
    );
    await _saveToPrefs();
  }

  void setActiveServer(String id) {
    if (state.servers.any((s) => s.id == id)) {
      state = state.copyWith(activeServerId: id);
      _saveToPrefs();
    }
  }

  Future<void> checkAllServersHealth() async {
    final checked = await Future.wait(
      state.servers.map((server) async {
        bool isOnline = false;
        try {
          if (server.type == MediaServerType.plex) {
            isOnline = await PlexService(server).testConnection();
          } else {
            isOnline = await JellyfinService(server).testConnection();
          }
        } catch (_) {
          isOnline = false;
        }
        return server.copyWith(isOnline: isOnline);
      }),
    );

    state = state.copyWith(servers: checked);
  }
}

final mediaServersProvider =
    NotifierProvider<MediaServersNotifier, MediaServersState>(
  MediaServersNotifier.new,
);

/// Proveedor del servidor actualmente activo.
final activeMediaServerProvider = Provider<MediaServerConfig?>((ref) {
  return ref.watch(mediaServersProvider).activeServer;
});
