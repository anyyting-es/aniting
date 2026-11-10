import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Warms the images that are guaranteed to be visible the instant the startup
/// splash hands over to [MainShell].
///
/// `precacheImage` only runs the expensive part (network + disk + decode) and
/// leaves the result in Flutter's [ImageCache], so the first shell frames paint
/// already-decoded bitmaps instead of kicking off a burst of simultaneous
/// decodes on the frame where the splash fades out.
///
/// The provider is built with the exact same `maxWidth`/`maxHeight` the card
/// widgets pass as `memCacheWidth`/`memCacheHeight`: those values are part of
/// `CachedNetworkImageProvider`'s cache key, so a mismatch would produce a
/// second, unused decode.
class StartupImageWarmer {
  const StartupImageWarmer._();

  /// Upper bound of distinct URLs to warm. Enough to cover the first rail,
  /// small enough that it can never become its own startup stall.
  static const int maxImages = 6;

  static Future<void> precacheCovers(
    BuildContext context,
    Iterable<String?> urls, {
    required List<int> memCacheWidths,
    int? memCacheHeight,
    Duration budget = const Duration(milliseconds: 800),
  }) async {
    if (memCacheWidths.isEmpty) return;

    final seen = <String>{};
    final targets = <String>[];
    for (final url in urls) {
      if (url == null || url.isEmpty) continue;
      if (seen.add(url)) targets.add(url);
      if (targets.length >= maxImages) break;
    }
    if (targets.isEmpty) return;

    final work = Future.wait<void>([
      for (final url in targets)
        for (final width in memCacheWidths)
          precacheImage(
            CachedNetworkImageProvider(
              url,
              maxWidth: width,
              maxHeight: memCacheHeight,
            ),
            context,
          ).catchError((_) {}),
    ]);

    // Never let a slow disk or a dead CDN hold the splash hostage.
    try {
      await work.timeout(budget);
    } catch (_) {}
  }
}
