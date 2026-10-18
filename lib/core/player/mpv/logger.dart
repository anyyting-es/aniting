import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger();
  void e(String msg, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[MPV ERROR] $msg ${error ?? ""}');
  }
  void w(String msg, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[MPV WARN] $msg ${error ?? ""}');
  }
  void i(String msg, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[MPV INFO] $msg');
  }
  void d(String msg, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[MPV DEBUG] $msg');
  }
}

const appLogger = AppLogger();
