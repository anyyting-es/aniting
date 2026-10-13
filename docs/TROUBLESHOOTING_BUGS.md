# Troubleshooting, Bug Fixes & Platform Quirks

This document records solutions to complex platform-specific bugs, hardware decoder quirks, memory leaks, threading issues, and architectural edge cases resolved across the Seanime App codebase.

---

## 1. Video Playback & Hardware Decoding (libmpv / Desktop)

### 1.1. Linux Raster Thread Stall Fix (`MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME = 0`)
- **Symptom**: On Linux (X11 and Wayland), video playback of 24fps or 30fps content locked the entire Flutter UI down to 15–24 FPS, making navigation, sliders, and controls lag heavily.
- **Root Cause**: `media_kit_video` defaulted `MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME` to `1` in `texture_gl.cc`. This caused `mpv_render_context_render` to synchronously block Flutter's main raster thread for 17–25ms per frame while waiting for the next display vsync.
- **Solution**: Patched vendored `packages/media_kit_video/linux/texture_gl.cc` via `pubspec.yaml` `dependency_overrides` with `MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME = 0`. The raster call now returns non-blocking in ~0.5ms and the UI maintains a rock-solid 60/120/144 FPS.

### 1.2. GTK UI Freeze on Video Player Exit (Linux)
- **Symptom**: Popping `VideoPlayerScreen` on Linux caused a ~1-second complete UI freeze in the window before returning to the previous screen.
- **Root Cause**: `video_output_dispose` in `packages/media_kit_video/linux/video_output.cc` invoked synchronous `mpv_render_context_free` and `eglDestroyContext` on the main GTK UI thread.
- **Solution**: Delegated heavy context destruction and GL teardown to a detached background thread (`std::thread(...).detach()`). Route pop transitions are now instantaneous (0ms UI lag).

### 1.3. Driver Timeouts & Hangs with Modern Linux HWDEC
- **Symptom**: On hybrid GPU systems (Intel/Nvidia or AMD/Nvidia), initializing libmpv caused a 1-second freeze or error dialogs.
- **Root Cause**: libmpv probed unsupported Vulkan video extensions (`VK_KHR_video_decode_queue`) and CUDA extensions that timed out on non-matching drivers.
- **Solution**: In `MpvPlayerService` and `VideoControllerConfiguration`, configured `hwdec` to `'vaapi,vaapi-copy,nvdec,nvdec-copy,auto-safe'` with `video-sync: 'audio'`, bypassing Vulkan probe delays and ensuring stable zero-copy hardware decoding.

### 1.4. In-Player Controls Continuous Rebuilds
- **Symptom**: GPU/CPU usage remained high while watching full-screen video even when controls were hidden.
- **Root Cause**: Invisible controls remained mounted in the widget tree, and active `ValueListenableBuilder` listeners rebuilt bottom bar widgets 60 times per second on every position tick.
- **Solution**: Wrapped controls in `_ControlsOverlay` that completely unmounts the controls subtree when `AnimatedOpacity` reaches `0.0`. Position and buffer listeners are strictly scoped to the timeline slider and time label, not the buttons row.

---

## 2. Android Playback Engine (Media3 ExoPlayer & libass)

### 2.1. Initial Black Viewport and Centering Glitch in Portrait
- **Symptom**: Opening a video in portrait on Android displayed a black letterbox at the top or centered the video behind the info panel until entering and exiting fullscreen.
- **Root Cause**: `ExoPlayerPlugin` initialized its native container as `MATCH_PARENT, MATCH_PARENT`. When `openMedia` called `ensureInitialized()` with default arguments, it reset container bounds to full screen, ignoring Flutter's portrait bounds.
- **Solution**: Preserved explicit `initialHeight` in `ensureInitialized()`, removed pre-population of bounds in `VideoPlayerScreen.initState()`, and ensured `_updateExoSurfaceBounds` synchronizes exact MediaQuery dimensions on the very first frame.

### 2.2. Duplicate plain-text Cues with Styled ASS Subtitles
- **Symptom**: Subtitles appeared twice on screen: once with styled ASS positioning, and once as plain unstyled white text at the bottom.
- **Root Cause**: Media3 subtitle decoders passed plain text cues to `standardSubtitleView` while `AssSubtitleSurfaceView` simultaneously rendered the styled subtitles.
- **Solution**: Added `isCurrentSubAss` detection in `ExoPlayerPlugin.kt` and `AssHandler.kt`. When an ASS track is active, plain cues are suppressed across native views and Flutter layers.

### 2.3. Matroska CodecPrivate Malformed Headers
- **Symptom**: `Bad timestamp` and `Warning: no style named '0' found, using 'Default'` when decoding MKV ASS subtitles.
- **Root Cause**: Missing or malformed `[Events]` sections and disordered columns in Matroska CodecPrivate headers.
- **Solution**: Added `AssHeaderParser.kt` to normalize headers, enforce canonical column order (`Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text`), and correctly evaluate duration from sample tokens.

---

## 3. Networking, Ports & Platform Storage

### 3.1. Android Socket `reusePort` Crash
- **Symptom**: App crashed on Android when initializing LAN discovery service: `Dart Socket ERROR: socket_linux.cc: reusePort not supported on this platform`.
- **Root Cause**: The Linux kernel on Android does not permit `reusePort: true` on user-space raw datagram sockets without elevated permissions.
- **Solution**: Set `reusePort: !Platform.isWindows && !Platform.isAndroid` in `LanDiscoveryService.dart`.

### 3.2. Seanime vs Aniting Process & Port Collisions
- **Symptom**: Running official Seanime and Aniting concurrently caused binding errors (`address already in use`) or mixed up user credentials and databases.
- **Root Cause**: Both applications shared default ports (`43211`-`43214`) and storage directories.
- **Solution**: Decoupled Aniting to dedicated default ports: API (`43311`), UDP Discovery (`43312`), Torrent Client (`43313`), Streaming Server (`43314`), with isolated database `aniting.db` in dedicated data folders.

### 3.3. Riverpod `CircularDependencyError` in `ServerNotifier`
- **Symptom**: `CircularDependencyError` thrown during server startup or switching between local and remote server.
- **Root Cause**: Server notifier evaluated feed providers while feed providers watched server notifier synchronously during transition states.
- **Solution**: Scheduled feed provider invalidations via `Future.microtask` and committed server state prior to notifying feed consumers.

---

## 4. UI Rendering, GPU Optimization & 0 FPS Idle

### 4.1. Infinite Animation Controllers Causing High GPU Consumption
- **Symptom**: The anime details page consumed 20–40% GPU on idle with no user interaction.
- **Root Cause**: An active `SingleTickerProviderStateMixin` ran a continuous 10-second looping animation controller for subtle background breathing, forcing Flutter to render 60–120 FPS indefinitely.
- **Solution**: Replaced the looping controller with scroll-driven parallax calculations driven directly by `ScrollController`. When the screen is static, frame rate is 0 FPS and GPU usage drops to 0%.

### 4.2. Redundant BackdropFilters Over Opaque Surfaces
- **Symptom**: High GPU fill-rate and frame drops during fast scrolling.
- **Root Cause**: `BackdropFilter` widgets placed inside components that sat entirely on top of solid opaque background colors.
- **Solution**: Removed redundant `BackdropFilter` layers where translucency was not visually effective, restricted blur sigma to ≤25 for banners, and wrapped interactive cards and buttons with `RepaintBoundary`.

---

## 5. Linux MPRIS D-Bus Integration Quirks

### 5.1. Session Bus Disconnection on Player Re-entry
- **Symptom**: Player controls via `playerctl` stopped working when entering a second video after exiting the first.
- **Root Cause**: Disposing the player called `client.close()`, disconnecting the DBus client from the session bus.
- **Solution**: Designed `MprisService` as a persistent singleton that remains registered on the D-Bus session bus across the app lifecycle. `reset()` clears active metadata, track positions, and callbacks without unregistering the service interface or closing the D-Bus connection.
