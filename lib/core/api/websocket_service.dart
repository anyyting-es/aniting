import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:seanime_app/core/constants/app_constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;
  String _wsUrl = AppConstants.defaultWsUrl;

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  bool get isConnected => _isConnected;

  void connect({String? host, int? port}) {
    if (host != null && port != null) {
      _wsUrl = 'ws://$host:$port/events';
    }

    disconnect();

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _subscription = _channel?.stream.listen(
        (message) {
          try {
            if (message is String) {
              final data = jsonDecode(message) as Map<String, dynamic>;
              _eventController.add(data);
            }
          } catch (e) {
            debugPrint('WebSocket parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _isConnected = false;
    }
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
