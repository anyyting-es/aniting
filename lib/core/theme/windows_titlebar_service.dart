import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges Flutter theme changes to Windows 11 Desktop Window Manager (DWM).
///
/// Configures native Windows 11 DWM attributes:
/// - Windows 11 rounded window corners (`DWMWA_WINDOW_CORNER_PREFERENCE`)
/// - Immersive dark / light mode decorations (`DWMWA_USE_IMMERSIVE_DARK_MODE`)
/// - Mica / Mica Alt system backdrop (`DWMWA_SYSTEMBACKDROP_TYPE`)
/// - Dynamic caption bar & text color coordination (`DWMWA_CAPTION_COLOR`, `DWMWA_TEXT_COLOR`)
class WindowsTitlebarService {
  static const MethodChannel _channel = MethodChannel('plezy/window');

  /// Synchronizes the native titlebar appearance with the current app theme.
  static Future<void> updateTitleBar({
    required bool isDark,
    required bool isOled,
    Color? surfaceColor,
    bool useMica = true,
  }) async {
    if (kIsWeb || !Platform.isWindows) return;

    try {
      int? captionColor;
      int? textColor;

      if (isOled) {
        // OLED mode strictly requires pure pitch black
        captionColor = const Color(0xFF000000).toARGB32();
        textColor = const Color(0xFFEEEEEE).toARGB32();
      } else if (!useMica && surfaceColor != null) {
        captionColor = surfaceColor.toARGB32();
        textColor = isDark ? const Color(0xFFEEEEEE).toARGB32() : const Color(0xFF1E1E1E).toARGB32();
      }
      // When useMica is true and not OLED, captionColor is omitted (null / default),
      // allowing the native Windows 11 Mica material to render cleanly on the titlebar.

      final params = <String, dynamic>{
        'isDark': isDark,
        'useMica': useMica && !isOled,
      };
      if (captionColor != null) {
        params['captionColor'] = captionColor;
      }
      if (textColor != null) {
        params['textColor'] = textColor;
      }

      await _channel.invokeMethod('setTitleBarStyle', params);
    } catch (_) {}
  }
}
