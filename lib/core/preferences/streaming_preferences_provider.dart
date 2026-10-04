import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreamingPreferences {
  final bool torrentStreamingEnabled;
  final bool onlineStreamingEnabled;
  final bool pauseTorrentStreamOnExit;

  const StreamingPreferences({
    this.torrentStreamingEnabled = true,
    this.onlineStreamingEnabled = true,
    this.pauseTorrentStreamOnExit = true,
  });

  StreamingPreferences copyWith({
    bool? torrentStreamingEnabled,
    bool? onlineStreamingEnabled,
    bool? pauseTorrentStreamOnExit,
  }) {
    return StreamingPreferences(
      torrentStreamingEnabled:
          torrentStreamingEnabled ?? this.torrentStreamingEnabled,
      onlineStreamingEnabled:
          onlineStreamingEnabled ?? this.onlineStreamingEnabled,
      pauseTorrentStreamOnExit:
          pauseTorrentStreamOnExit ?? this.pauseTorrentStreamOnExit,
    );
  }
}

class StreamingPreferencesNotifier extends Notifier<StreamingPreferences> {
  static const _prefTorrentKey = 'pref_torrent_streaming_enabled';
  static const _prefOnlineKey = 'pref_online_streaming_enabled';
  static const _prefPauseTorrentKey = 'pref_pause_torrent_on_exit';

  @override
  StreamingPreferences build() {
    _load();
    return const StreamingPreferences();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final torrent = prefs.getBool(_prefTorrentKey) ?? true;
      final online = prefs.getBool(_prefOnlineKey) ?? true;
      final pauseTorrent = prefs.getBool(_prefPauseTorrentKey) ?? true;
      state = StreamingPreferences(
        torrentStreamingEnabled: torrent,
        onlineStreamingEnabled: online,
        pauseTorrentStreamOnExit: pauseTorrent,
      );
    } catch (_) {}
  }

  Future<void> setTorrentEnabled(bool enabled) async {
    state = state.copyWith(torrentStreamingEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTorrentKey, enabled);
    } catch (_) {}
  }

  Future<void> setOnlineEnabled(bool enabled) async {
    state = state.copyWith(onlineStreamingEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefOnlineKey, enabled);
    } catch (_) {}
  }

  Future<void> setPauseTorrentStreamOnExit(bool enabled) async {
    state = state.copyWith(pauseTorrentStreamOnExit: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefPauseTorrentKey, enabled);
    } catch (_) {}
  }
}

final streamingPreferencesProvider =
    NotifierProvider<StreamingPreferencesNotifier, StreamingPreferences>(
  StreamingPreferencesNotifier.new,
);
