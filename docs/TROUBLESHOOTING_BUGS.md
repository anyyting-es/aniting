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
- **Solution**: Wrapped controls in _ControlsOverlay that completely unmounts the controls subtree when AnimatedOpacity reaches 0.0. Position and buffer listeners are strictly scoped to the timeline slider and time label, not the buttons row.

### 1.5. Black Video Viewport on Linux Wayland & Windows Subsurfaces
- **Symptom**: On Linux (Wayland/X11) and Windows, audio and hardware decoding (VA-API/NVDEC) worked normally, but the video viewport remained solid black.
- **Root Cause**: Plezy's `PlayerLinux` renders via a native Wayland `wl_subsurface` placed *below* the Flutter surface (`wl_subsurface_place_below`), and `PlayerWindows` renders to a child HWND below the Flutter window. `VideoPlayerScreen` and `PlayerViewport` unconditionally painted opaque `Colors.black` backgrounds when `!Platform.isAndroid`, occluding the underlying video plane.
- **Solution**: Set the Flutter Scaffold and `PlayerViewport` root backgrounds to `Colors.transparent` so the hardware-accelerated subsurface renders cleanly through Flutter's RGBA window visual.

### 1.6. Online Sources Show No Subtitle Tracks
- **Symptom**: The subtitle picker only listed `Disable Subtitles` / `Automatic` for online sources (e.g. KickAssAnime), even though the provider returned several subtitle languages.
- **Root Cause**: `PlayerPlaybackCoordinator.open()` (the path used when online sources are resolved *after* the player was created) issued `setSubtitleTrack(uri)` before `loadfile` had finished. mpv silently drops that call. The track-list listener also captured the `externalSubtitles` argument from the initial `init()` (usually `null`), so the UI never merged the extension's subtitle list even though `_externalSubtitles` had been updated.
- **Solution**: `open()` now goes through `_openAndAttachExternalSubtitles()`: it awaits the media open and then `sub-add`s every external track (with the proxy/header treatment). The track listener reads the mutable `_externalSubtitles` field and appends only tracks that `sub-add` has not already registered, so each language appears once. Note that some providers genuinely return no subtitles (EspAnime, AnimeGG, AnimeHeaven); KickAssAnime and Reanime do.

### 1.7. Diagnosing Occasional Micro-Stutters (MPV frame pacing)
- **Symptom**: Playback is smooth but every so often the video "hiccups" for a frame or two (mini-tirón), with no obvious CPU spike.
- **How to collect data**:
  1. Open the **Playback Stats / Stats for Nerds** overlay *before* reproducing. It starts `PerformanceStatsService` polling native mpv properties.
  2. The overlay now shows real `frame-drop-count` (VO), `decoder-frame-drop-count`, `mistimed-frame-count`, `hwdec-current`, `avsync`, `demuxer-cache-duration` and `cache-buffering-state`.
  3. Every time a counter increases the console prints a line like:
     `[PlayerDiag] stutter: vo=+1 (total 12), decoder=+0 (3), mistimed=+1 (4) | hwdec=d3d11va cache=18.2s buffer=100% avsync=0.003 fps=23.976 ...`
  4. For full libmpv logs (decoder/cache/vo negotiations) run with verbose logs: desktop `ANITING_MPV_DEBUG=1 ./run_debug_server.sh`, or any platform with `--dart-define=ANITING_MPV_DEBUG=true`. Lines appear as `[MPV/<level>]`.
- **Interpretation**:
  - `decoder-frame-drop-count` ↑ → decode/GPU too slow. Check `hwdec-current` (`no`/`auto-safe` vs `d3d11va`/`vaapi`), 10-bit HEVC/AV1, 4K. Try disabling shaders (Anime4K/FSR).
  - Only `frame-drop-count` (VO) ↑ with decoder stable → presentation/VSync path: GPU driver, DWM, monitor refresh mismatch, heavy shader chain, or another window/overlay compositing.
  - `demuxer-cache-duration` near 0 or `cache-buffering-state < 100` → source/network (torrent pieces, HLS segment hiccup). Compare a local file against the same source.
  - `avsync` drifting/growing → audio clock or audio-device issue; try another audio output.
  - `mistimed-frame-count` ↑ with no drops → frames arriving late (refresh-rate/`video-sync`/timer resolution).
- **Judder without drops** (e.g. `Display: 60.00 Hz · 2.50 vsync/frame`, video 23.976 fps): this is the classic 24 fps→60 Hz 3:2 cadence. It is not a dropped frame and no counter will move. Enable **Ajustes → Reproductor → Suavizado de movimiento** (mpv `video-sync=display-resample` + `interpolation=yes` + `tscale=oversample`), or use a display whose refresh is a multiple of 23.976 (120/144 Hz). If `Sync` shows `audio` and `DS` is missing, mpv is not doing display sync at all.

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

### 4.3. `AmbientVideoGlow` Rectangular Inner-Shadow Seam Around Desktop Player (`ShaderMask` + `ImageFiltered`)
- **Symptom**: In desktop normal layout mode, while the ambient blurred video glow (`AmbientVideoGlow`) spread into the background around the player, a sharp rectangular frame with an inward-fading dark shadow appeared around the video (matching no individual widget's bounds in the Flutter Widget Inspector).
- **Root Cause**: In `AmbientVideoGlow` (`lib/presentation/widgets/player/viewport/ambient_video_glow.dart`), `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55))` was placed *inside* the two `ShaderMask(blendMode: BlendMode.dstIn)` widgets. Because a Gaussian blur expands its layer `paintBounds` by `~3 * sigma` (`~165px`) beyond the child's layout box, `ShaderMaskLayer` created a `saveLayer` covering the expanded blur bounds (`[-165, -165, W + 165, H + 165]`) but only drew the `BlendMode.dstIn` edge-fade gradient rect inside `maskRect` (`[0, 0, W, H]`). In Skia/Impeller, `drawRect` with `BlendMode.dstIn` does not modify pixels outside `maskRect`, leaving the outer `165px` blur unmasked while abruptly multiplying the `maskRect` border by `alpha = 0.0` and ramping inward—creating a sharp dark rectangular cutout with an inward gradient around the player.
- **Solution**: Applied the two `ShaderMask` edge fades directly to `_buildTexture()` *before* wrapping with `ImageFiltered(imageFilter: ImageFilter.blur(...))`. Because `_buildTexture()` is clipped to `maskRect`, the `ShaderMask` fades the texture's edges cleanly to zero alpha within its exact bounds, and `ImageFiltered` subsequently blurs the edge-faded result smoothly outward with no rectangular seam.

### 4.4. Desktop Caption Buttons (Minimize/Maximize/Close) Vanish After Fullscreen
- **Symptom**: After toggling fullscreen a few times in the player (especially from a maximized window) and leaving it, the custom titlebar disappeared permanently, losing the minimize, maximize/restore, and close buttons.
- **Root Cause**: `window_manager` 0.5.2 on Windows only emits `leave-full-screen` when `WM_SIZE` arrives as `SIZE_RESTORED`. If the window was maximized before entering fullscreen, its native restore path posts `SC_MAXIMIZE` instead, so the plugin's internal `last_state` remains `FULLSCREEN_ENTERED` and no leave event is ever sent. `DesktopTitleBar` relied on that event to clear its local `_isFullScreen`, so it stayed hidden forever.
- **Solution**: Added `desktopNativeFullscreenProvider` (`lib/presentation/widgets/desktop_title_bar.dart`) and made `PlayerWindowManager` update it directly when entering/exiting fullscreen (`defaultEnterNativeFullscreen` / `defaultExitNativeFullscreen`). The titlebar and `DesktopWindowFrame` now watch that provider instead of relying on plugin events, so exiting fullscreen always restores the caption controls and rounded window frame. Additionally, the maximize/restore button queries `windowManager.isMaximized()` before acting (and re-syncs after a short delay) instead of trusting its cached flag, because the same swallowed events could leave it stuck sending `maximize` while the window was already maximized — making "restore to floating" impossible. Covered by `test/desktop_title_bar_click_through_test.dart`.

### 4.5. Shorts/Specials Hijacking Episode Titles & Thumbnails (AniZip)
- **Symptom**: A season's episode list showed the 2-minute shorts (`Maomao no Hitorigoto Episode 50/51/52`…) as if they were the real episodes, with their chibi thumbnails, while the count matched the online provider's available episodes.
- **Root Cause**: `AniZipData` parses specials keyed `S1`, `S2`… assigning them `episodeNumber` = 1, 2… (the number after the `S`). `_buildOnlineProviderEpisodes` (`desktop_episodes_tab.dart`) built its lookup map with `for (ep in aniZipData.episodes)` using `episodeNumber` as key, so the later specials silently overwrote the real episodes 1..N, leaking special titles/art into the provider episode list.
- **Solution**: Build the lookup map from `aniZipData.mainEpisodes` only, so specials can never override main episode metadata. Covered by the regression test in `test/desktop_online_provider_episodes_test.dart`.

### 4.6. Missing Episode Titles/Stills for Brand-New Seasons (Animap vs AniZip)
- **Symptom**: A newly airing season (e.g. AniList `213805`, *The Ramparts of Ice S2*) showed generic `EP 2`, `EP 3`… and the same cover image repeated, while the official app showed real titles (`Clouds and Rain`, `Stop and Go`) and stills for the same media.
- **Root Cause**: Three independent gaps. (1) The Go backend's `animap.go` sent `X-Aniting-Version` instead of the upstream `X-Seanime-Version` header, and `anime.clap.ing` answers **403** unless the request uses the `Go-http-client/1.1` user agent *and* the `X-Seanime-Version` header — so every anime silently fell back to empty metadata. (2) The Flutter client fetched episode metadata directly from `api.ani.zip`, which returns `{"episodes":{}}` for entries without a TVDB mapping yet; the backend resolves through **Animap**, exactly like the official app. (3) `AnimeEpisode.fromJson` only read `displayTitle` (always `Episode N`) and a top-level `image`, ignoring Animap's `episodeTitle` and `episodeMetadata.image/overview`, discarding the backend data even when present.
- **Solution**: `animap.go` now sends both `X-Seanime-Version` and `X-Aniting-Version` (the Go user agent requirement is already satisfied by `net/http`). `AnimeEpisode.fromJson` prefers `episodeTitle`, falls back to `displayTitle`, and reads the still/description from `episodeMetadata`. Online-provider episode rows in `desktop_episodes_tab.dart` are enriched with `details.episodes` (Animap) when AniZip has no data, so real titles/thumbnails are shown. Covered by `test/desktop_online_provider_episodes_test.dart`. On mobile/TV, `OnlineStreamView` applies the same Animap fallback for titles/stills. Note: the Full Android APK embeds a prebuilt `aniting.aar`; rebuild it with `gomobile bind` after backend changes (see `docs/BUILD_AND_RUN_GUIDE.md` §3.D), otherwise the mobile-embedded server keeps the old behavior.

### 4.7. Continue Watching Jumping When Leaving the Player
- **Symptom**: After closing an episode, the feed showed the old Continue Watching episode/progress for a moment, then it updated live with a visible stutter/jump on arrival.
- **Root Cause**: Progress was flushed ~200 ms after the route pop and `continueWatchingProvider` was invalidated 420 ms later, i.e. exactly when the feed was already visible. The card's live progress was also cleared on dispose before the persisted value was in place.
- **Solution**: `continueWatchingProvider` is now an `AsyncNotifier` with `applyLocalProgress()`. `VideoPlayerScreen._handleExit` applies the new episode/progress optimistically **before** popping, so the feed rebuilds behind the closing transition. After the continuity PATCH completes, `refreshFromServer()` re-reads the server list silently (no loading state), so when the feed is revealed nothing changes on screen. The local playback map is also saved synchronously before the pop so the progress bar never reverts.

### 4.8. Episode Carousel Stutter When Returning From the Player
- **Symptom**: Leaving an episode and landing back on the anime detail page made the horizontal episode carousel animate a long distance, lagging for a moment and only then showing the new position.
- **Root Cause**: `_scrollToResumeEpisode` always called `animateTo(targetIndex * 443px)` for 420 ms. Returning from the player changes the target episode (progress/last playback), so it animated across many heavy `DesktopGridEpisodeCard`s — rebuilding every card in the path — even when the target card was already on screen.
- **Solution**: The carousel now aligns the resume episode to the **left edge** (first card) whenever it changes or the player closes, using `jumpTo` for the first alignment/long jumps and a 260 ms animation for short corrections. `episodeResumeAlignmentProvider` is incremented on player exit so the list re-aligns even when the target number did not change (e.g. after manually scrolling before pressing Continue). The target also takes the offline entry's progress into account, so finishing episode 15 advances the list to 16 immediately without waiting for the server collection.

### 4.9. Player Episode Rail Scroll Chaining & Auto-Reveal
- **Symptom**: Wheeling inside the episode list on the player page kept scrolling the whole page once the list hit its end. The rail also moved on its own while the user was browsing it.
- **Root Cause**: The rail is an independent vertical `SingleChildScrollView` nested inside the page's vertical `ListView`. Once the inner list reached its extent, the wheel gesture chained into the outer page. Separately, `_revealActiveEpisode` always called `ensureVisible(alignment: 0.28)`, which moved the list even when the active card was already fully visible or while the user was scrolling.
- **Solution**: `PlayerDesktopLayout` tracks hover over the rail through a `MouseRegion` and swaps the page to `NeverScrollableScrollPhysics` while the pointer is inside it, so the wheel stops at the rail's end. The rail now skips auto-reveal when the active card is already visible, while the user is actively scrolling, or within 800 ms of their last scroll. Programmatic reveals mark themselves so they don't count as user scrolling.

### 4.10. Anime Detail Episode List Is Source-Dependent
- **Symptom**: Switching between Torrent and Online (or changing the online provider) could keep showing the previous source's episode list instead of rebuilding it for the newly selected source.
- **Root Cause**: `DesktopEpisodesTab` memoizes the processed list but its fast-path/cache was not invalidated when `currentTab`, the selected provider or the dub mode changed. The canonical (torrent/local) path also used AniZip only, ignoring Animap titles/stills when AniZip was incomplete.
- **Solution**: The memoized list and carousel target reset whenever the source/tab/provider changes. Torrent/local lists now merge AniZip with `details.episodes` (Animap) per episode (title, synopsis, still, air-date image fallback). Online lists keep using the provider episode list enriched with AniZip/Animap. The same Animap fallback was added to the mobile/TV `AniZipEpisodeListView`.

---

## 5. Linux MPRIS D-Bus Integration Quirks

### 5.1. Session Bus Disconnection on Player Re-entry
- **Symptom**: Player controls via `playerctl` stopped working when entering a second video after exiting the first.
- **Root Cause**: Disposing the player called `client.close()`, disconnecting the DBus client from the session bus.
- **Solution**: Designed `MprisService` as a persistent singleton that remains registered on the D-Bus session bus across the app lifecycle. `reset()` clears active metadata, track positions, and callbacks without unregistering the service interface or closing the D-Bus connection.

---

## 6. Online Stream Downloads (HLS) & Player Stability

### 6.1. Downloaded Episode Was Unplayable (Encrypted HLS Written Raw)
- **Symptom**: An online episode download reported "completed", but opening it prompted an ExoPlayer→libmpv fallback and nothing ever played. The file was hundreds of MB of high-entropy garbage (no `ftyp`/`moov`/TS sync bytes).
- **Root Cause**: On Android/iOS there is no ffmpeg, so `OnlineStreamDownloader` used the pure-Dart HLS fallback. That path ignored `#EXT-X-KEY` (AES-128) and `#EXT-X-MAP` (fMP4/CMAF init segment), so the raw **encrypted** segment bytes were concatenated and saved as `.mp4`.
- **Solution**: New `HlsDownloadEngine` (`lib/core/downloads/hls_download_engine.dart`) that parses `#EXT-X-KEY`, `#EXT-X-MAP` and `#EXT-X-BYTERANGE`, decrypts AES-128 (CBC + PKCS7, with `pointycastle`) and derives the IV from `IV=` or the media sequence. SAMPLE-AES/DRM is reported with a clear error instead of writing garbage.

### 6.2. False "Completed" Downloads / Missing Feedback
- **Solution**: After every download the output is validated (`_validateOutput` → `isValidMediaHeader`); a non-media file is deleted and the task is marked `failed` with a machine code (`protected` / `invalid` / `unknown`) that the dialog maps to localized text. `startDownload` now returns a `DownloadStartResult` so the UI distinguishes "already downloading" from "no save folder configured" (previously both showed the wrong "already downloading" message).

### 6.3. `ref` Used Inside `dispose()` (Player)
- **Symptom**: `Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe` when leaving the player.
- **Root Cause**: `_VideoPlayerScreenState.dispose()` called `ref.read(...)` to decide whether to pause the torrent stream.
- **Solution**: The repository is captured in `initState`, and the torrent/preference flags are cached in fields during `build` (`ref.watch`), so `dispose()` never touches `ref`.

### 6.4. Playback Card Showed "No Sources Found" for Local / Torrent Playback
- **Symptom**: Playing a downloaded (local) episode or a torrent stream, the player card read "Playback options" and tapping it opened the online source sheet showing "No playback options found for this episode" (plus a reload button that errored).
- **Root Cause**: `PlayerSourceCard` always rendered the online source selector because `_sourceController` is created for every playback session, regardless of whether the video comes from an online provider.
- **Solution**: New `PlayerPlaybackOrigin` (`online` / `torrent` / `local`) computed by the player and threaded through `PlayerInfoPanel` → `PlayerSourceCard`. Only `online` renders the switchable selector; `local` shows "Playing locally" and `torrent` shows "Playing from torrent" as informational, non-interactive cards (no reload, no chevron, no DUB/SUB badge).

### 6.5. Online Stream Downloads Missing from the Download Manager
- **Symptom**: Starting an online episode download showed the "Download started" confirmation, but Settings → Downloads never listed it (no progress, no banner badge).
- **Root Cause**: The download task state (`onlineStreamDownloadProvider`) was updated correctly, but the widget created to display it (`ActiveDownloadsTab`) was never referenced by any screen, so nothing rendered it. The download manager and banner counts only accounted for torrents and the manga queue.
- **Solution**: New reusable `OnlineStreamDownloadsSection` (moved out of the orphan widget) embedded in `DownloadManagerScreen`'s active section, sharing the torrent flow: in-progress progress/speed, cancel, and a localized failure card for protected/invalid sources. Online tasks are also included in the active-download counts of `DownloadsScreen` and its desktop layout.
