# Desktop Window Transparency & Compositor Blur (Wayland / X11 / Multi-OS)

This guide documents the native architecture and implementation for **desktop window transparency and compositor-driven background blur** in **Aniting (Seanime App)**.

---

## 1. Architectural Philosophy

In modern display servers—especially **Wayland**—client applications are strictly isolated for security. A client (Flutter/GTK) **cannot directly inspect or sample pixels from other windows or the desktop wallpaper**. Therefore, standard client-side blur shaders (`BackdropFilter` or `g1455`) only operate on widgets drawn *inside* Flutter's own widget hierarchy.

To achieve true system-level frosted glass / blur behind the app:
1. **Flutter** outputs an RGBA frame with transparent or semi-transparent background pixels (e.g., 85% opacity).
2. **The GTK3 Runner** assigns an RGBA visual to the top-level window and configures a transparent `FlView` background.
3. **The Window Compositor** (e.g., Niri, Hyprland, SwayFX, KDE KWin, DWM) intercepts the semi-transparent pixels and executes a GPU-accelerated Dual-Kawase blur shader over whatever is underneath the window.

```
┌────────────────────────────────────────────────────────┐
│  Flutter Widget Tree (Text, Posters, Glass Cards)      │
├────────────────────────────────────────────────────────┤
│  Flutter Scaffold (Semi-transparent background: 85%)   │
├────────────────────────────────────────────────────────┤
│  FlView (GdkRGBA {0, 0, 0, 0} transparent surface)     │
├────────────────────────────────────────────────────────┤
│  Wayland wl_surface (RGBA8888 buffer passed to compositor)│
├────────────────────────────────────────────────────────┤
│  Wayland Compositor (Niri / Hyprland GPU Blur Shader)  │
├────────────────────────────────────────────────────────┤
│  Desktop Wallpaper / Windows Beneath                   │
└────────────────────────────────────────────────────────┘
```

---

## 2. Layer 1: Native Linux Runner (`my_application.cc`)

### 2.1. RGBA Visual & FlView Transparency
In `linux/runner/my_application.cc`:
- `setup_window_transparency_and_visual(GtkWindow* window, FlView* view)` queries `gdk_screen_get_rgba_visual(screen)`.
- It sets `gtk_widget_set_visual(window, visual)` and `gtk_widget_set_app_paintable(window, TRUE)`.
- It calls `fl_view_set_background_color(view, &transparent)` with `GdkRGBA {0.0, 0.0, 0.0, 0.0}`.
- Works on both **Wayland** and **composited X11** display servers.

### 2.2. GTK Window CSS Pass-Through
To prevent GTK3's Adwaita/theme engine from painting an opaque background box behind the Flutter view, the application loads a CSS rule:
```css
window, .background {
  background-color: transparent;
}
```

### 2.3. Dual Harmony with MPV Video Planes
Aniting renders video on Wayland via a hardware `wl_subsurface` placed *below* Flutter's `wl_surface`. Flutter punches an alpha-0 hole for video playback. Because the window visual is RGBA transparent, Flutter's transparent pixels flawlessly expose the video plane during playback and the compositor's blurred desktop when idle.

---

## 3. Layer 2: Flutter & Riverpod Architecture

### 3.1. Preference Provider (`desktop_window_transparency_provider.dart`)
- **State**:
  - `enabled`: `bool` (default: `false` / opt-in)
  - `opacity`: `double` (default: `0.85`, range: `0.40` to `0.98`)
- **Storage**: Persisted to `SharedPreferences` keys:
  - `desktop_window_transparency_enabled`
  - `desktop_window_transparency_opacity`

### 3.2. Dynamic Theme Integration (`lib/main.dart`)
In `MaterialApp.builder`:
```dart
final windowTrans = ref.watch(desktopWindowTransparencyProvider);
final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
final effectiveWindowTransparency = isDesktop && windowTrans.enabled;

final effectiveScaffoldBg = effectiveWindowTransparency
    ? baseTheme.scaffoldBackgroundColor.withValues(alpha: windowTrans.opacity)
    : baseTheme.scaffoldBackgroundColor;

final updatedTheme = baseTheme.copyWith(
  scaffoldBackgroundColor: effectiveScaffoldBg,
  // ...
);
```

For `GlassHost` (`g1455`):
```dart
GlassHost(
  richBackdrop: true,
  finish: isDark ? GlassFinish.regularDark : GlassFinish.regularLight,
  backdrop: effectiveWindowTransparency ? Colors.transparent : updatedTheme.scaffoldBackgroundColor,
  // ...
)
```
Setting `backdrop: Colors.transparent` ensures `GlassHost` does not paint an opaque backdrop behind the app tree.

### 3.3. Double-Stacking Prevention (`main_shell.dart`)
When the main shell has a semi-transparent `Scaffold` and child views (`FeedScreen`, `SearchScreen`, etc.) also contain `Scaffold`s, stacking them would multiply alpha values (making the window opaque).

To prevent this, `main_shell.dart` wraps inner page stacks in:
```dart
Theme(
  data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
  child: ShellAnimatedIndexedStack(
    index: activeIndex,
    children: availablePages,
  ),
)
```
Only the top-level shell paints the semi-transparent canvas.

---

## 4. Layer 3: Compositor Setup & Replication Across Systems

### 4.1. Niri (Wayland)
Requires **Niri >= 26.04** (supports `background-effect { blur true }`).

In `~/.config/niri/config.kdl`:
```kdl
window-rule {
    match app-id="com.seanime.app.seanime_app"
    match app-id="aniting"
    match app-id="seanime_app"
    background-effect {
        blur true
        xray false
    }
}

blur {
    passes 3
    offset 3.0
    noise 0.02
    saturation 1.5
}
```
Reload with:
```bash
niri msg action load-config-file
```

---

### 4.2. Hyprland (Wayland)
In `~/.config/hypr/hyprland.conf`:
```ini
# Match either application ID or executable name
windowrule = blur, match:class ^(com.seanime.app.seanime_app)$
windowrule = blur, match:class ^(aniting)$
windowrule = blur, match:class ^(seanime_app)$

# Optional: Global blur tuning
decoration {
    blur {
        enabled = true
        size = 8
        passes = 3
        new_optimizations = true
    }
}
```

---

### 4.3. SwayFX (Wayland)
In `~/.config/sway/config`:
```
blur enable
blur_passes 3
blur_radius 5
for_window [app_id="com.seanime.app.seanime_app"] blur enable
for_window [app_id="aniting"] blur enable
```

---

### 4.4. KDE Plasma / KWin (Wayland / X11)
KWin natively supports blurring windows with alpha channels:
1. In **System Settings** -> **Window Management** -> **Window Rules**:
   - Add new rule for Window Class: `com.seanime.app.seanime_app`.
   - Set "Force Blur" or use KWin Scripts such as `kwin-effects-forceblur`.
2. Under Plasma Wayland, transparent surfaces with RGBA visual are automatically blended over the wallpaper.

---

### 4.5. GNOME Shell (Wayland / X11)
GNOME Mutter does not expose an arbitrary blur protocol to client windows by default.
To enable blur behind Aniting on GNOME:
1. Install the popular **Blur my Shell** extension.
2. In **Blur my Shell Settings** -> **Applications**:
   - Enable "Application Blur".
   - Add `com.seanime.app.seanime_app` or `aniting` to the whitelist.

---

### 4.6. Windows 10/11 (DWM Acrylic / Mica)
To extend this to Windows in future iterations:
- Windows 11 uses `DwmSetWindowAttribute` with `DWMWA_SYSTEMBACKDROP_TYPE`:
  - `DWMSBT_MAINWINDOW` (Mica)
  - `DWMSBT_TRANSIENTWINDOW` (Acrylic blur)
- Can be triggered via Flutter plugin `flutter_acrylic` or native `windows/runner/flutter_window.cpp` DWM calls.

---

### 4.7. macOS (Vibrancy)
To extend this to macOS in future iterations:
- An `NSVisualEffectView` is inserted behind Flutter's view in `macos/Runner/MainFlutterWindow.swift`.
- Setting `visualEffectView.material = .underWindowBackground` blends macOS frosted vibrancy with Flutter's semi-transparent theme.
