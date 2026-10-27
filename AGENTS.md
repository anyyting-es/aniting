# Seanime App - Agents & Core Architectural Guide

> **MANDATORY INSTRUCTION FOR AGENTS**:
> Keep this document clean, elemental, and modular. Do **NOT** bloat this file with hundreds of lines of historical change logs or individual bug fixes.
> Instead, refer to and update the specialized documents in `docs/`:
> - 📜 **Changelog History**: [`docs/CHANGELOG_HISTORY.md`](file:///home/anthony/Documents/Eris/aniting/docs/CHANGELOG_HISTORY.md)
> - 🏛️ **Subsystem Deep-Dives**: [`docs/ARCHITECTURE_SUBSYSTEMS.md`](file:///home/anthony/Documents/Eris/aniting/docs/ARCHITECTURE_SUBSYSTEMS.md)
> - 🛠️ **Troubleshooting & Bug Fixes**: [`docs/TROUBLESHOOTING_BUGS.md`](file:///home/anthony/Documents/Eris/aniting/docs/TROUBLESHOOTING_BUGS.md)

---

## 1. Golden Rules (Non-Negotiable)

1. **Liquid Glass Effects (`g1455`)**:
   - For all liquid glass effects, strictly use and follow https://g1455.plugfox.dev/SKILL.md (`GlassCard`, `GlassSegmentedControl`, `showGlassSheet`, `GlassPopoverAnchor`).
   - Never stack redundant `BackdropFilter` layers over opaque backgrounds.

2. **Release Changelog Simplicity**:
   - Release changelogs must **ALWAYS be simple, clean, and concise**.
   - **NEVER** include microscopic or tedious implementation details that end users do not care about.
   - **ALWAYS** summarize improvements at a high, user-facing level with punchy bullet points in [`docs/CHANGELOG_HISTORY.md`](file:///home/anthony/Documents/Eris/aniting/docs/CHANGELOG_HISTORY.md).

3. **File Size & Modular Architecture**:
   - **NEVER** create gigantic monolithic files. Avoid single source files exceeding ~400–500 lines.
   - Decompose UI screens, cards, forms, and dialogs into modular sub-widgets inside dedicated folders (e.g. `widgets/anime_detail/desktop/`, `widgets/player/services/`, `widgets/welcome/`).

4. **Mandatory Internationalization (i18n)**:
   - Any user-facing string **MUST** be registered in all three translation files:
     - Contract: `lib/core/i18n/translations/translations.dart`
     - English: `lib/core/i18n/translations/en.dart`
     - Spanish: `lib/core/i18n/translations/es.dart`
   - Use `l10n.keyName`. Never hardcode strings in any language.

5. **Theme Integrity & Contrast**:
   - Never hardcode colors. Consume `Theme.of(context).colorScheme` and `context.themeColors`.
   - Maintain pure black background in OLED mode.

6. **Automated Verification**:
   - Run `flutter analyze lib/` before finishing any task to guarantee 0 issues.

7. **Material 3 Expressive (`material_3_expressive`)**:
   - Prefer `material_3_expressive` widgets (`M3EButton`, `M3EIconButton`, `M3ESwitch`, etc.) for actionable UI controls to leverage spring-driven physics (`motor`), morphing shapes on press, and expressive state layers.
   - Wrap UI trees with `M3ETheme` using `M3EThemeData.dark(seedColor: ...)` or `.light(...)` to seamlessly propagate dynamic color schemes.
   - Harmoniously combine with `g1455` liquid glass containers (`GlassCard`, `GlassSegmentedControl`, `GlassMenuAnchor`).

---

## 2. Tech Stack & Key Libraries

- **Framework**: Flutter (Dart 3.x) with Material Design 3.
- **Design System & Motion**: Material 3 Expressive via `material_3_expressive` (spring motion via `motor`, shape morphing, buttons, switches) and liquid glass via `g1455`.
- **State Management**: `flutter_riverpod` (Providers, Notifiers, StateNotifiers).
- **Networking**: `dio` (REST API), `web_socket_channel` (real-time server events).
- **Video Playback**:
  - **Android**: Native Android Media3 **ExoPlayer** + `libass-android` via platform channels (`exo_player_service.dart`), with automatic fallback to **libmpv**.
  - **Desktop / Fallback**: **libmpv** via `media_kit` and `media_kit_video` (`mpv_player_service.dart`).
- **Desktop Media Controls**: Linux MPRIS via `package:dbus` (`mpris_service.dart`).
- **Backend**: Go embedded companion server (`backend/`) using `echo/v4`, GORM SQLite, Goja (JS extensions), and libtorrent.
- **Icons**: `lucide_icons_flutter` and Material Symbols (`AppIcons`, `iconPackProvider`).

---

## 3. Directory Map

```
seanime_app/
├── AGENTS.md                         # <--- THIS FILE (Elemental guide & component index)
├── docs/                             # Specialized deep documentation
│   ├── ARCHITECTURE_SUBSYSTEMS.md    # In-depth subsystem specifications
│   ├── TROUBLESHOOTING_BUGS.md       # Platform quirks, crash fixes, and hardware decoding
│   └── CHANGELOG_HISTORY.md          # User-facing historical changelogs
├── pubspec.yaml                      # Dependencies & asset definitions
├── backend/                          # Seanime Go backend source code
│   └── internal/
│       ├── handlers/                 # Echo REST handlers (/shows, /library, /torrentstream, etc.)
│       ├── library/shows/            # Plex/Jellyfin TV & Movie parser and scanner
│       └── database/                 # SQLite GORM models and bridges
└── lib/
    ├── core/                         # Core API, theme, player engines, i18n, preferences
    ├── data/                         # Models, repositories, offline services, TMDB service
    └── presentation/                 # Riverpod providers, screens, and modular widgets
```

---

## 4. Component Directory & Navigation Index

Use this directory to quickly locate any screen, widget, provider, or subsystem:

### 4.1. Navigation & Main Views
| Component | Path | Description |
| :--- | :--- | :--- |
| **Main Shell** | [`main_shell.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/main_shell.dart) | Application shell with adaptive bottom dock / desktop sidebar |
| **Anime Home Feed** | [`feed_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/feed_screen.dart) | 100% User Library feed, continue watching, currently watching |
| **Manga Home Feed** | [`manga_feed_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/manga_feed_screen.dart) | User manga library, continue reading, reading progress |
| **Explore Hub** | [`search_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/search_screen.dart) | Hero carousel, genre chips, catalog search, media type toggle |
| **Airing Calendar** | [`airing_calendar_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/airing_calendar_screen.dart) | 7-day broadcast schedule, mobile PageView, desktop multi-column |
| **Profile & Library** | [`library_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/library_screen.dart) | User statistics, AniList collection sync, custom lists |

### 4.2. Video Player & Playback Subsystem
| Component | Path | Description |
| :--- | :--- | :--- |
| **Player Viewport** | [`video_player_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/video_player_screen.dart) | Main video player view, orientation, gesture overlay |
| **Playback Coordinator**| [`player_playback_coordinator.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/player/services/player_playback_coordinator.dart) | Dual-engine manager (ExoPlayer + libmpv auto fallback) |
| **Progress Manager** | [`player_progress_manager.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/player/services/player_progress_manager.dart) | Playback continuity, LastSession, AniList watch sync |
| **Window Manager** | [`player_window_manager.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/player/services/player_window_manager.dart) | Fullscreen, window resizing, ExoPlayer surface bounds sync |
| **Source Controller** | [`player_source_controller.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/player/services/player_source_controller.dart) | Online stream source discovery, auto-stream, live switcher |
| **MPRIS Service** | [`mpris_service.dart`](file:///home/anthony/Documents/Eris/aniting/lib/core/player/mpris_service.dart) | Linux D-Bus `org.mpris.MediaPlayer2` media controls & metadata |
| **ExoPlayer Bridge** | [`exo_player_service.dart`](file:///home/anthony/Documents/Eris/aniting/lib/core/player/exo_player_service.dart) | Android native Media3 + libass platform channels |
| **MPV Player Service** | [`mpv_player_service.dart`](file:///home/anthony/Documents/Eris/aniting/lib/core/player/mpv_player_service.dart) | libmpv / media_kit engine with Plezy performance tweaks |
| **Shader Presets** | [`player_shader_service.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/player/services/player_shader_service.dart) | Real-time GLSL anime shaders (Anime4K, FSR, deband) |

### 4.3. Anime & Shows Details Subsystem
| Component | Path | Description |
| :--- | :--- | :--- |
| **Detail Orchestrator**| [`anime_detail_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/anime_detail_screen.dart) | Responsive router for desktop, mobile, and TV layouts |
| **Desktop Layout** | [`anime_detail_desktop_layout.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/anime_detail/anime_detail_desktop_layout.dart) | Panoramic hero banner, clean bottom-aligned metadata, tabs |
| **Mobile Layout** | [`anime_detail_mobile_layout.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/anime_detail/anime_detail_mobile_layout.dart) | Compact layout with 0 FPS idle scroll parallax |
| **Desktop Episodes** | [`desktop_episodes_tab.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/anime_detail/desktop/desktop_episodes_tab.dart) | Episode coordinator, online/torrent/local filters, pagination |
| **Universal Episodes**| [`episodes_view.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/episodes/episodes_view.dart) | Universal episodes coordinator for Anime, TMDB Shows & Movies |
| **Universal Card**     | [`episode_card.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/episodes/episode_card.dart) | Canonical 16:9 Grid and compact List episode card with continuity |

### 4.4. Torrent Subsystem & Visor de Torrents
| Component | Path | Description |
| :--- | :--- | :--- |
| **Torrent Coordinator**| [`torrent_selector_dialog.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/torrent_selector/torrent_selector_dialog.dart) | Dual-mode coordinator (responsive desktop dialog / mobile sheet) |
| **Desktop View** | [`torrent_selector_desktop_view.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/torrent_selector/desktop/torrent_selector_desktop_view.dart) | Full-width 2-panel split container (Left info/settings, Right torrents) |
| **Left Info Panel** | [`torrent_sidebar_info_panel.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/torrent_selector/desktop/torrent_sidebar_info_panel.dart) | 16:9 episode thumbnail, stepper changer, quality chips, providers |
| **Torrent File Card** | [`torrent_file_card.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/torrent_selector/desktop/torrent_file_card.dart) | Sleek custom card with health status, release tags, size, and actions |
| **Mobile View** | [`torrent_selector_mobile_view.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/torrent_selector/mobile/torrent_selector_mobile_view.dart) | Touch-optimized modal sheet with horizontal filter chips |
| **Batch Files Sheet** | [`torrent_batch_files_sheet.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/torrent_batch_files_sheet.dart) | Inspector and file picker for multi-episode batch torrents |

### 4.5. Local Library & Hybrid TMDB/AniList Subsystem
| Component | Path | Description |
| :--- | :--- | :--- |
| **Backend Parser** | [`parser.go`](file:///home/anthony/Documents/Eris/aniting/backend/internal/library/shows/parser.go) | Plex/Jellyfin naming convention regex parser for TV & movies |
| **Backend Scanner** | [`scanner.go`](file:///home/anthony/Documents/Eris/aniting/backend/internal/library/shows/scanner.go) | Directory walker grouping local files by series & season |
| **Shows Handlers** | [`shows.go`](file:///home/anthony/Documents/Eris/aniting/backend/internal/handlers/shows.go) | Endpoints for scanning, matching, unmatching, and collection |
| **Local Library State**| [`local_library_provider.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/providers/local_library_provider.dart) | Paths, scan progress, match/unmatch state, stats |
| **Folder Paths Card** | [`local_library_paths_card.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/settings/widgets/local_library/local_library_paths_card.dart) | Directory manager with folder type selector (Anime/TV/Movies) |
| **Hybrid Match Dialog**| [`local_library_match_dialog.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/settings/widgets/local_library/local_library_match_dialog.dart) | Matcher with `[ AniList ]` vs `[ TMDB ]` toggle and unmatch action |

### 4.5. Manga Subsystem
| Component | Path | Description |
| :--- | :--- | :--- |
| **Manga Detail** | [`manga_detail_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/manga_detail_screen.dart) | Chapters manager, download manager, recommendations |
| **Manga Reader** | [`manga_reader_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/manga_reader_screen.dart) | High-performance image viewer (vertical webtoon / paginated) |
| **Page Memory Keep** | [`manga_keep_alive_page.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/manga/manga_keep_alive_page.dart) | Preserves offscreen decoded pages without stuttering |

### 4.6. Settings, Theming & UI Utilities
| Component | Path | Description |
| :--- | :--- | :--- |
| **Settings Screen** | [`settings_screen.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/settings_screen.dart) | Adaptive dual-panel settings (Appearance, Player, Library, etc.) |
| **Theme Provider** | [`theme_provider.dart`](file:///home/anthony/Documents/Eris/aniting/lib/core/theme/theme_provider.dart) | Light, Dark, and OLED theme state, dynamic color schemes |
| **Liquid Glass Toggle**| [`media_type_toggle.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/media_type_toggle.dart) | Non-wrapping segmented control for Anime / Shows / Manga |
| **Window Transparency**| [`desktop_window_transparency_provider.dart`](file:///home/anthony/Documents/Eris/aniting/lib/core/preferences/desktop_window_transparency_provider.dart) | Compositor blur and window opacity state (Niri, Hyprland, KDE) |
| **Wallpaper Background**| [`app_wallpaper_background.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/app_wallpaper_background.dart) | Root-level custom wallpaper projection with blur & opacity |
| **Appearance Header**   | [`theme_appearance_header_card.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/screens/settings/widgets/theme/theme_appearance_header_card.dart) | Expressive header card with wallpaper thumbnail and mode pills |
| **M3 Expressive Select**| [`m3_expressive_select.dart`](file:///home/anthony/Documents/Eris/aniting/lib/presentation/widgets/m3_expressive_select.dart) | Fluid dropdown select with decoupled popover overlay |

---

## 5. Maintenance & Build Commands

Consulte la guía detallada en [`docs/BUILD_AND_RUN_GUIDE.md`](file:///home/anthony/Documents/Eris/aniting/docs/BUILD_AND_RUN_GUIDE.md).

- **Ejecución en Debug (Con servidor Go)**:
  ```bash
  ./run_debug_server.sh
  # Opcional con dispositivo: ./run_debug_server.sh -d <device>
  ```
- **Ejecución en Debug (Sin servidor / Cliente remoto)**:
  ```bash
  ./run_debug_client.sh
  ```
- **Compilación de APK Completo (Con servidor Go Release)**:
  ```bash
  ./build_apk_full.sh
  ```
- **Compilación de APK Cliente (Sin servidor Go Release)**:
  ```bash
  ./build_apk_client.sh
  ```
- **Compilación Servidor Linux Desktop**:
  ```bash
  ./build_server.sh
  ```
- **Code Analysis**:
  ```bash
  flutter analyze lib/
  ```
- **Automated Tests**:
  ```bash
  flutter test
  # Unit tests for Go shows parser:
  cd backend && go test -v ./internal/library/shows/...
  ```
- **Run Application (Desktop Linux)**:
  ```bash
  flutter run -d linux
  ```
