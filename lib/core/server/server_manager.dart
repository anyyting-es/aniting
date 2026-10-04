import 'dart:io';
import 'package:dio/dio.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/constants/app_constants.dart';
import 'package:seanime_app/core/server/android_server_channel.dart';
import 'package:seanime_app/core/server/desktop_server.dart';

enum ServerState {
  stopped,
  starting,
  running,
  remote,
  error,
}

class ServerManager {
  final ApiClient _apiClient;
  final DesktopServer _desktopServer = DesktopServer();
  final AndroidServerChannel _androidChannel = AndroidServerChannel();

  ServerState _state = ServerState.stopped;
  String? _lastError;
  String _host = AppConstants.defaultHost;
  int _port = AppConstants.defaultPort;

  ServerManager(this._apiClient);

  ServerState get state => _state;
  String? get lastError => _lastError;
  String get host => _host;
  int get port => _port;
  AndroidServerChannel get androidChannel => _androidChannel;

  void resetToLocal() {
    _host = AppConstants.defaultHost;
    _port = AppConstants.defaultPort;
    _apiClient.updateConfig(host: _host, port: _port);
    _state = ServerState.stopped;
    _lastError = null;
  }

  Future<bool> isBatteryOptimizationIgnored() => _androidChannel.isBatteryOptimizationIgnored();
  Future<bool> requestIgnoreBatteryOptimization() => _androidChannel.requestIgnoreBatteryOptimization();
  Future<bool> isManageStorageGranted() => _androidChannel.isManageStorageGranted();
  Future<bool> requestManageStorage() => _androidChannel.requestManageStorage();

  Future<bool> startLocalServer({
    int port = AppConstants.defaultPort,
    String host = '127.0.0.1',
    String? desktopBinaryPath,
  }) async {
    _port = port;
    _host = AppConstants.defaultHost;
    _apiClient.updateConfig(host: _host, port: _port);
    _state = ServerState.starting;
    _lastError = null;

    if (Platform.isAndroid) {
      final res = await _androidChannel.startServer(port: port, host: host);
      if (res != null) {
        _state = ServerState.running;
        return true;
      } else {
        _state = ServerState.error;
        _lastError = 'No se pudo iniciar el servicio de Android';
        return false;
      }
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      final success = await _desktopServer.start(
        executablePath: desktopBinaryPath,
        port: port,
        host: host,
      );
      if (success) {
        _state = ServerState.running;
        return true;
      } else {
        _state = ServerState.error;
        _lastError = 'No se encontró el ejecutable seanime en backend/';
        return false;
      }
    }

    _state = ServerState.error;
    _lastError = 'Plataforma no soportada para servidor local';
    return false;
  }

  Future<bool> checkHealth({String? host, int? port}) async {
    final h = host ?? _host;
    final p = port ?? _port;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://$h:$p/api/v1',
          connectTimeout: const Duration(milliseconds: 3000),
          receiveTimeout: const Duration(milliseconds: 3000),
        ),
      );

      final response = await dio.get('/status');
      if (response.statusCode == 200) {
        _host = h;
        _port = p;
        _apiClient.updateConfig(host: h, port: p);
        if (h != '127.0.0.1' && h != 'localhost') {
          _state = ServerState.remote;
        } else {
          _state = ServerState.running;
        }
        _lastError = null;
        return true;
      }
    } catch (e) {
      // Server not reachable yet
      _lastError = 'No se pudo conectar a $h:$p';
    }
    return false;
  }

  Future<void> stopServer() async {
    if (Platform.isAndroid) {
      await _androidChannel.stopServer();
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      await _desktopServer.stop();
    }
    _state = ServerState.stopped;
  }
}
