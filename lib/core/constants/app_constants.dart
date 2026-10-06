class AppConstants {
  static const String appName = 'Aniting';
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 43311;
  static const String defaultBaseUrl = 'http://$defaultHost:$defaultPort/api/v1';
  static const String defaultWsUrl = 'ws://$defaultHost:$defaultPort/events';

  // Storage keys
  static const String keyServerHost = 'aniting_server_host';
  static const String keyServerPort = 'aniting_server_port';
  static const String keyServerPassword = 'aniting_server_password';
  static const String keyIsLocalServer = 'aniting_is_local_server';
}
