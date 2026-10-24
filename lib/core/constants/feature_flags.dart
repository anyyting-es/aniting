/// Compile-time feature gates.
///
/// These features are temporarily hidden from the user interface while their
/// visual pipeline is being stabilized. The implementation stays in place so
/// they can be re-enabled by flipping the flag back to `true`.
class FeatureFlags {
  FeatureFlags._();

  /// Custom wallpaper picker, preview, opacity/blur controls and the dynamic
  /// "Material You from wallpaper" palette entry.
  static const bool customWallpaper = false;

  /// Desktop window transparency + compositor blur controls.
  static const bool desktopWindowTransparency = false;
}
