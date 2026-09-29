import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AndroidServerChannel {
  static const MethodChannel _channel = MethodChannel('com.seanime.app/server');

  static bool get isSupported => Platform.isAndroid;

  Future<Map<String, dynamic>?> startServer({int port = 43211}) async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('startServer', {'port': port});
      return result?.cast<String, dynamic>();
    } on PlatformException catch (e) {
      debugPrint('AndroidServerChannel startServer error: ${e.message}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> stopServer() async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('stopServer');
      return result?.cast<String, dynamic>();
    } on PlatformException catch (e) {
      debugPrint('AndroidServerChannel stopServer error: ${e.message}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStatus() async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
      return result?.cast<String, dynamic>();
    } on PlatformException catch (e) {
      debugPrint('AndroidServerChannel getStatus error: ${e.message}');
      return null;
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    if (!isSupported) return true;
    try {
      final res = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimization() async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimization');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isManageStorageGranted() async {
    if (!isSupported) return true;
    try {
      final res = await _channel.invokeMethod<bool>('isManageStorageGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestManageStorage() async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestManageStorage');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getDataDir() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('getDataDir');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readConfig() async {
    if (!isSupported) return null;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('readConfig');
      return res?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> writeConfig(String content) async {
    if (!isSupported) return null;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('writeConfig', {'content': content});
      return res?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> resetConfig() async {
    if (!isSupported) return null;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('resetConfig');
      return res?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}
