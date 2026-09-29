class AppConstants {
  static const String appName = 'Seanime App';
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 43211;
  static const String defaultBaseUrl = 'http://$defaultHost:$defaultPort/api/v1';
  static const String defaultWsUrl = 'ws://$defaultHost:$defaultPort/events';

  // Storage keys
  static const String keyServerHost = 'seanime_server_host';
  static const String keyServerPort = 'seanime_server_port';
  static const String keyServerPassword = 'seanime_server_password';
  static const String keyIsLocalServer = 'seanime_is_local_server';
}
