import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/api/ws_events.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

/// Notifier que mantiene el estado en tiempo real de la descarga del torrent
/// recibido mediante eventos WebSocket del servidor Seanime (`torrentstream-state`).
class TorrentStreamStatusNotifier extends Notifier<TorrentStreamStatus?> {
  StreamSubscription? _sub;

  @override
  TorrentStreamStatus? build() {
    final ws = ref.watch(webSocketServiceProvider);
    _sub?.cancel();
    _sub = ws.eventStream.listen(_handleWsEvent);

    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });

    return null;
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    if (event['type'] == WsEvents.torrentstreamState) {
      final payload = event['payload'];
      if (payload is Map<String, dynamic>) {
        final st = payload['state'] as String?;
        if (st == 'status' && payload['data'] is Map<String, dynamic>) {
          state = TorrentStreamStatus.fromJson(
            payload['data'] as Map<String, dynamic>,
          );
        } else if (st == 'stopped') {
          state = null;
        }
      }
    }
  }

  /// Limpia manualmente el estado actual cuando se cierra el reproductor o stream.
  void reset() {
    state = null;
  }
}

final torrentStreamStatusProvider =
    NotifierProvider<TorrentStreamStatusNotifier, TorrentStreamStatus?>(
  TorrentStreamStatusNotifier.new,
);

/// Preferencia de visualización del overlay de progreso de torrent en pantalla.
/// Por defecto desactivado (`false`) según requerimientos de UX.
class TorrentProgressOverlayEnabledNotifier extends Notifier<bool> {
  static const _prefKey = 'torrent_progress_overlay_enabled';

  @override
  bool build() {
    _load();
    return false; // Por defecto desactivado
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }
}

final torrentProgressOverlayEnabledProvider =
    NotifierProvider<TorrentProgressOverlayEnabledNotifier, bool>(
  TorrentProgressOverlayEnabledNotifier.new,
);
