import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../presentation/widgets/welcome/tv/tv_pairing_sheet.dart';

/// Global root navigator key to allow opening sheets/dialogs from external deep links.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Service to handle URL schemes (e.g. `aniting://pair?action=serve_tv&ip=...`)
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _channel = MethodChannel('com.anyyting.aniting/server');
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler(_handleNativeCall);

      // Check initial link on cold launch after frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkInitialLink();
      });
    }
  }

  Future<void> _checkInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialDeepLink');
      if (link != null && link.isNotEmpty) {
        handleUriString(link);
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error checking initial link: $e');
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final link = call.arguments as String?;
      if (link != null && link.isNotEmpty) {
        handleUriString(link);
      }
    }
  }

  /// Parses and routes incoming URI strings.
  void handleUriString(String uriString) {
    debugPrint('DeepLinkService: Received URI: $uriString');
    final uri = Uri.tryParse(uriString);
    if (uri == null) return;

    if (uri.scheme == 'aniting') {
      if (uri.host == 'pair') {
        _handlePairingUri(uri);
      }
    }
  }

  void _handlePairingUri(Uri uri) {
    final action = uri.queryParameters['action'];
    final ip = uri.queryParameters['ip'];
    final portStr = uri.queryParameters['port'];
    final port = int.tryParse(portStr ?? '43211') ?? 43211;

    if (action == 'serve_tv' && ip != null && ip.isNotEmpty) {
      _showPairingFlow(tvIp: ip, tvPort: port);
    }
  }

  void _showPairingFlow({required String tvIp, required int tvPort}) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      // Retry in next microtask / frame if context is not mounted yet
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedCtx = rootNavigatorKey.currentContext;
        if (delayedCtx != null) {
          TvPairingSheet.show(context: delayedCtx, tvIp: tvIp, tvPort: tvPort);
        }
      });
      return;
    }

    TvPairingSheet.show(context: context, tvIp: tvIp, tvPort: tvPort);
  }
}
