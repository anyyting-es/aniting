import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Represents a discovered Aniting server on the local network.
class DiscoveredServer {
  final String name;
  final String ip;
  final int port;
  final String version;
  final DateTime lastSeen;

  const DiscoveredServer({
    required this.name,
    required this.ip,
    required this.port,
    required this.version,
    required this.lastSeen,
  });

  String get address => '$ip:$port';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredServer && ip == other.ip && port == other.port;

  @override
  int get hashCode => Object.hash(ip, port);
}

/// Service for discovering and advertising Aniting servers on the local network
/// via lightweight UDP broadcast beacons (~120 bytes every 3 seconds).
class LanDiscoveryService {
  static const int _discoveryPort = 43212;
  static const String _magicHeader = 'ANITING_SRV';
  static const Duration _broadcastInterval = Duration(seconds: 3);
  static const Duration _serverTimeout = Duration(seconds: 10);

  // ─── Broadcasting (Host side) ─────────────────────────────────
  RawDatagramSocket? _broadcastSocket;
  Timer? _broadcastTimer;
  bool _isBroadcasting = false;

  bool get isBroadcasting => _isBroadcasting;

  /// Start broadcasting this server's presence on the local network.
  Future<void> startBroadcasting({
    required String serverName,
    required int serverPort,
    required String version,
  }) async {
    if (_isBroadcasting) return;

    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // OS picks an ephemeral port for sending
      );
      _broadcastSocket!.broadcastEnabled = true;
      _isBroadcasting = true;

      final localIp = await getLocalIpAddress();

      _broadcastTimer = Timer.periodic(_broadcastInterval, (_) {
        _sendBeacon(
          serverName: serverName,
          serverPort: serverPort,
          ip: localIp ?? '0.0.0.0',
          version: version,
        );
      });

      // Send first beacon immediately
      _sendBeacon(
        serverName: serverName,
        serverPort: serverPort,
        ip: localIp ?? '0.0.0.0',
        version: version,
      );

      debugPrint('LanDiscovery: Broadcasting started as "$serverName" on port $_discoveryPort');
    } catch (e) {
      debugPrint('LanDiscovery: Failed to start broadcasting: $e');
      _isBroadcasting = false;
    }
  }

  void _sendBeacon({
    required String serverName,
    required int serverPort,
    required String ip,
    required String version,
  }) {
    if (_broadcastSocket == null) return;

    final payload = jsonEncode({
      'h': _magicHeader,
      'n': serverName,
      'ip': ip,
      'p': serverPort,
      'v': version,
    });

    final data = utf8.encode(payload);

    try {
      _broadcastSocket!.send(
        data,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );
    } catch (e) {
      debugPrint('LanDiscovery: Beacon send failed: $e');
    }
  }

  /// Stop broadcasting this server's presence.
  void stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
    _isBroadcasting = false;
    debugPrint('LanDiscovery: Broadcasting stopped');
  }

  // ─── Listening (Client side) ──────────────────────────────────
  RawDatagramSocket? _listenerSocket;
  final _serversController = StreamController<List<DiscoveredServer>>.broadcast();
  final Map<String, DiscoveredServer> _discoveredServers = {};
  Timer? _cleanupTimer;
  bool _isListening = false;

  bool get isListening => _isListening;
  Stream<List<DiscoveredServer>> get serversStream => _serversController.stream;
  List<DiscoveredServer> get currentServers => _discoveredServers.values.toList();

  /// Start listening for server beacons on the local network.
  Future<void> startListening() async {
    if (_isListening) return;

    try {
      _listenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _isListening = true;

      _listenerSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenerSocket!.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // Periodically remove stale servers (not seen in 10 seconds)
      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _removeStaleServers();
      });

      debugPrint('LanDiscovery: Listening on port $_discoveryPort');
    } catch (e) {
      debugPrint('LanDiscovery: Failed to start listening: $e');
      _isListening = false;
    }
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;

      if (json['h'] != _magicHeader) return;

      final server = DiscoveredServer(
        name: json['n'] as String? ?? 'Aniting Server',
        ip: json['ip'] as String? ?? datagram.address.address,
        port: json['p'] as int? ?? 43211,
        version: json['v'] as String? ?? '',
        lastSeen: DateTime.now(),
      );

      // Skip if it's our own broadcast (same IP as this device)
      _updateServer(server);
    } catch (e) {
      // Ignore malformed packets silently
    }
  }

  void _updateServer(DiscoveredServer server) {
    _discoveredServers[server.address] = server;
    _emitServers();
  }

  void _removeStaleServers() {
    final now = DateTime.now();
    final staleKeys = <String>[];

    for (final entry in _discoveredServers.entries) {
      if (now.difference(entry.value.lastSeen) > _serverTimeout) {
        staleKeys.add(entry.key);
      }
    }

    if (staleKeys.isNotEmpty) {
      for (final key in staleKeys) {
        _discoveredServers.remove(key);
      }
      _emitServers();
    }
  }

  void _emitServers() {
    if (!_serversController.isClosed) {
      _serversController.add(_discoveredServers.values.toList());
    }
  }

  /// Stop listening for server beacons.
  void stopListening() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _listenerSocket?.close();
    _listenerSocket = null;
    _discoveredServers.clear();
    _isListening = false;
    debugPrint('LanDiscovery: Listening stopped');
  }

  // ─── Utilities ────────────────────────────────────────────────

  /// Returns the device's local IPv4 address on the Wi-Fi network.
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        // Prefer Wi-Fi / WLAN interfaces
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') ||
            name.contains('wifi') ||
            name.contains('wi-fi') ||
            name.contains('en0') ||
            name.contains('eth')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      }

      // Fallback: return any non-loopback IPv4 address
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('LanDiscovery: Failed to get local IP: $e');
    }
    return null;
  }

  /// Clean up all resources.
  void dispose() {
    stopBroadcasting();
    stopListening();
    _serversController.close();
  }
}
