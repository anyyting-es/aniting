# Architecture & Key Subsystems

This document provides in-depth architectural specifications and implementation guidelines for each major subsystem in **Seanime App (Aniting)**.

---

## 1. Navigation, Feeds & Explore Architecture

### 1.1. Navigation Hierarchy (`main_shell.dart`)
- **Main Views (5 Tabs)**:
  0. **Inicio (`feed_screen.dart`)**: 100% User Library anime feed (in-page search, Continue Watching with local video playback progress, Currently Watching, Missed Sequels full uncapped list, anime recommendations).
  1. **Manga (`manga_feed_screen.dart`)**: 100% User Library manga feed (in-page search, Continue Reading with chapters progress bar & `Capítulo X - Total` format, Completed Manga, manga recommendations).
  2. **Explorar (`search_screen.dart`)**: Comprehensive exploration hub with hero banner carousel, genre chips, non-wrapping media type toggle (Anime/Manga/Shows), filters (season, year, sort), genres hub.
  3. **Calendario (`airing_calendar_screen.dart`)**: Dedicated airing calendar page tracking upcoming broadcast schedules and episode countdowns.
  4. **Perfil (`library_screen.dart`)**: User profile stats, AniList account, collection lists.

### 1.2. Hybrid Media Provider & TMDB Integration
- **Modular Provider Coexistence (`section_visibility_provider.dart`, `tmdb_preferences_provider.dart`)**:
  - Users can independently enable or disable **Anime** (AniList), **Shows** (TMDB), or **Manga** from Settings.
  - A guard ensures at least one media section remains enabled.
- **TMDB Service & Clean Model Mapping (`tmdb_service.dart`)**:
  - Leverages The Movie Database API to query `trending/tv/week`, `tv/popular`, `tv/top_rated`, and `search/tv`.
  - Maps TMDB records seamlessly into the universal `AnimeEntry` model (`mediaId: tmdbId`, localized titles, `w500` cover images, `w1280` backdrop banner images, scaled 0-100 score, `TV`/`MOVIE` format), allowing complete reuse of existing UI components (`AnimeCard`, `ExploreHeroCarousel`).
- **TMDB Details & Season / Episode View (`widgets/anime_detail/tmdb/`)**:
  - `TmdbSeasonSelector`: Horizontal chip selector supporting Season 1..N and Specials (Season 0) with episode count badges.
  - `TmdbSeasonPostersView`: Horizontal season poster carousel with 2:3 cover thumbnails, active season highlight, and episode count badges.
  - `TmdbEpisodeCard`: 16:9 thumbnail display matching AniList desktop cards styling (`EP X. Title`, subtle hover scale, duration badge, overview, grid and 2-column list layouts). Shows disk badge when local file is available.
  - `TmdbEpisodesView`: Coordinator managing clickable Seasons heading and Episodes heading with grid/list and order sort toggles.

### 1.3. Airing Calendar (`airing_calendar_screen.dart`, `widgets/calendar/`)
- Full-width 7-day header with animated sliding line indicator (`calendar_day_tabs.dart`).
- Desktop multi-column layout (`calendar_desktop_view.dart`) with real-time current time marker (`calendar_now_marker.dart`).
- Mobile swipeable day-by-day PageView (`calendar_mobile_view.dart`).

---

## 2. Video Player Architecture

### 2.1. Dual-Engine Pipeline (`PlayerPlaybackCoordinator`)
- **Android Native Engine**: Media3 **ExoPlayer** + `libass-android` (`exo_player_service.dart`, `AssSubtitleSurfaceView`).
- **Desktop & Fallback Engine**: Direct `media_kit` and `media_kit_video` integration (`media_kit_player_service.dart`).
- **Automatic Fallback Execution**: If ExoPlayer encounters an unrecoverable format or codec error on Android, `triggerFallbackToMpv` seamlessly transitions to `MpvPlayerService` at the exact same playback position without interrupting the user.

### 2.2. Plezy-Inspired Controls & Micro-Optimizations
- **Clean Viewport**: Minimal controls, no oversized central buttons, center reserved for seek toasts.
- **Dynamic Icon Sizing**: Optically balanced dimensions between Lucide and Material icon packs.
- **Enlarged Timeline Seek Bar (`TimelineSlider`)**: 6dp track height with dark background and visual chapter ticks.
- **Desktop Volume Capsule (`VolumeSlider`)**: Thumb-free filled vertical capsule popping on hover with scroll-wheel support.
- **In-Player Online Source Resolution & Live Switching**:
  - Instant navigation to player route (0ms outside delay).
  - Background source resolution with automatic auto-play of the first found server/quality.
  - `PlayerSourceCard` in info panel with live provider and server switching sheet.
- **Modular Service Decomposition**:
  - `PlayerProgressManager`: Continuity saves, AniList watch sync threshold.
  - `PlayerWindowManager`: Fullscreen, orientation, and Android surface bounds sync.
  - `PlayerSourceController`: Online source resolution and episode transitions.
  - `PlayerShaderService`: Real-time mpv GLSL shader presets.

---

## 3. Hybrid Local Library Architecture (AniList + TMDB)

### 3.1. Philosophy: Plex / Jellyfin Standard Conventions
- To eliminate false positives, the system separates anime heuristics from western TV series and movies:
  - **TV Series Patterns**:
    - Folder structure: `Show Name (Year)/Season 01/Show - S01E01 - Title.mkv` or `Show Name/Temporada 1/1x04.mp4`
    - Regex: `[sS]([0-9]{1,3})[eE]([0-9]{1,3})`, `([0-9]{1,2})x([0-9]{1,3})`, `[tT]emporada\s*([0-9]{1,2}).*?[eE]pisodio\s*([0-9]{1,3})`
  - **Movies Patterns**:
    - Folder structure: `Movie Name (Year)/Movie Name (Year).mkv`
    - Regex: `^(.*?)\s*\((\d{4})\)`

### 3.2. Backend Submodule (`backend/internal/library/shows/`)
- `parser.go`: Plex/Jellyfin naming convention parser stripping resolution tags (1080p, 720p, WEB-DL, x264, x265, HEVC).
- `localfile.go`: `ShowLocalFile` struct with path, season, episode, tmdbId, mediaType (`tv`/`movie`), locked state.
- `scanner.go`: Directory walker grouping files by show folders while respecting configured path types.
- `collection.go`: Groups scanned files into `ShowCollection` (`ShowEntry` -> `Seasons` -> `Episodes`).
- **Database & Handlers**:
  - Table `show_local_files` in SQLite.
  - Endpoints: `POST /api/v1/shows/scan`, `GET /api/v1/shows/collection`, `GET /api/v1/shows/local-files`, `POST /api/v1/shows/match`, `POST /api/v1/shows/unmatch`.

### 3.3. Frontend Integration
- **Folder Type Configuration (`LocalLibraryPathsCard`)**: Users designate each directory as `anime`, `tv`, `movie`, or `mixed`.
- **Hybrid Match Dialog (`LocalLibraryMatchDialog`)**: Segmented toggle `[ AniList ]` vs `[ TMDB ]` with live search, matching, and unmatch capabilities.
- **Direct Local Playback**: TMDB episode cards highlight local availability with a green disk badge and route to `VideoPlayerScreen(isLocalFile: true)`.

---

## 4. Linux MPRIS Media Controls Integration

### 4.1. D-Bus Specification (`org.mpris.MediaPlayer2`)
- **Service (`lib/core/player/mpris_service.dart`)**:
  - Implements `org.mpris.MediaPlayer2` and `org.mpris.MediaPlayer2.Player` via `package:dbus`.
  - Registered under well-known bus name `org.mpris.MediaPlayer2.aniting` on Linux session bus.
  - Lifecycle persistent singleton: remains registered across route transitions.
- **Controls & Events**:
  - Supported methods: `Play`, `Pause`, `PlayPause`, `Stop`, `Next`, `Previous`, `Seek(offsetUs)`, `SetPosition(trackId, positionUs)`.
  - Properties: `PlaybackStatus` (`Playing`, `Paused`, `Stopped`), `Metadata` (`mpris:trackid`, `xesam:title`, `xesam:artist`, `xesam:album`, `mpris:artUrl`, `mpris:length`), `Position`, `CanPlay`, `CanPause`, `CanSeek`, `CanGoNext`, `CanGoPrevious`, `CanControl`.
- **Integration with Video Player**:
  - Synchronously updates metadata and playback state on position, duration, and playing changes.
  - Resets metadata gracefully upon player disposal.

---

## 5. Extensions & Community Marketplace

- **Architecture (`extensions_marketplace_screen.dart`, `backend/internal/extension_repo/`)**:
  - Connects to Seanime community extension marketplace.
  - Supports torrent providers, online stream extractors, manga providers, and anime news.
  - Sandboxed Goja JS runtime in backend executes user extension scripts.
  - Automatic version checks and 1-tap in-app updates for extensions.

---

## 6. Theming, Liquid Glass (`g1455`) & Focus Engine

- **Liquid Glass Specification (`g1455`)**:
  - Uses `g1455` library for translucent glass cards (`GlassCard`), segmented controls (`GlassSegmentedControl`), modal sheets (`showGlassSheet`), and popover anchors (`GlassPopoverAnchor`).
  - Strict performance rule: Never stack multiple `BackdropFilter` layers over opaque backgrounds.
- **Theme Modes**: Clean trio of Light, Dark, and Pure OLED Black. Dynamic color scheme extraction with custom palette overrides (`AppPalette`).

---

## 7. Onboarding & Welcome Flow (`welcome_screen.dart`)

- 5-step interactive wizard for first-time launch:
  1. Language Selection (English / Spanish).
  2. Theme & Appearance (Light, Dark, OLED, Accent Palette, Icon Pack).
  3. Content Preferences (Title language, global corner radius).
  4. Extensions Setup (Recommended community extensions).
  5. AniList Integration (Token login or skip to offline mode).

---

## 8. Downloader & Offline Storage Pipeline

- Unified downloader for anime episodes and manga chapters in `Aniting/Downloads/`.
- Background torrent downloads with libtorrent bindings in Go backend.
- Full offline library cache (`OfflineLibraryService`) enabling complete playback without internet connection.

---

## 9. Adaptive Multi-Device Layouts

- **Desktop (Windows / Linux / macOS)**:
  - Custom client-area titlebar with window controls (`DesktopTitleBar`).
  - Floating icon-only sidebar (`DesktopSidebar`).
  - Wide panoramic hero banners and 2-column or grid episode lists.
- **Mobile (Android / iOS)**:
  - Floating gesture dock with integrated resume pill (`MobileFloatingNav`).
  - Swipeable air calendar and touch-optimized bottom sheets.
- **TV (Android TV / 10-foot UI)**:
  - D-Pad focus traversal and oversized action cards (`AnimeDetailTvLayout`).

---

## 10. Manga Reader High-Performance Pipeline

- High-speed image reader (`manga_reader_screen.dart`) with webtoon continuous vertical scroll and single/double-page horizontal modes.
- `MangaKeepAlivePage` preserving offscreen decoded images in memory without stuttering.

---

## 11. Desktop Window Transparency & Compositor Blur

- **Architecture Guide**: Full deep dive available in [`docs/DESKTOP_BLUR_TRANSPARENCY.md`](file:///home/anthony/Documents/Eris/aniting/docs/DESKTOP_BLUR_TRANSPARENCY.md).
- **Native RGBA Visual Pipeline**: `setup_window_transparency_and_visual` in `my_application.cc` sets transparent `FlView` background and RGBA visual on Wayland & composited X11.
- **Dynamic Scaffolding**: Riverpod provider `desktopWindowTransparencyProvider` dynamically binds window opacity (40%–98%) to `ThemeData.scaffoldBackgroundColor` without double-alpha artifacts.
- **Compositor Integration**: Native Dual-Kawase blur support across Niri (`background-effect { blur true }`), Hyprland, SwayFX, KDE KWin, and GNOME.
