# Seanime App - Agents & Architecture Guide

> **RELEASE CHANGELOG SIMPLICITY RULE (CRITICAL - MANDATORY)**:
> Release changelogs must **ALWAYS be simple, clean, and concise**.
> - **NEVER** include microscopic, tedious, or trivial implementation details that end users do not care about (e.g., do **NOT** write: *"Eliminado el brillo fosforescente del indicador deslizante"*, *"Pestañas de los 7 días visibles en frame 0"*, *"Ajustado padding a 4px"*, *"Cambiado color del dot"*).
> - **ALWAYS** summarize improvements at a high, user-facing level with clear, direct bullet points (e.g., *"Mejoras de UI y navegación en el calendario de emisión"*, *"Nueva pantalla y gestión de estado sin conexión"*, *"Optimizaciones en la caché de seguir viendo"*).
> - Keep it punchy, professional, and easy to skim.
>
> **MANDATORY INSTRUCTION FOR AGENTS**:
> Whenever you make architectural changes, add new features, refactor existing components, or change directory structures in this project, you **MUST** update this `AGENTS.md` file. Add new context or update the existing documentation so future agents have an up-to-date map of the project.
>
> **FILE SIZE & MODULAR ARCHITECTURE RULE**:
> **NEVER** create gigantic monolithic files with thousands of lines. As a strict rule, avoid single source files exceeding ~400–500 lines unless exceptional constraints require it. Always decompose UI screens, tabs, cards, dialogs, and complex features into modular sub-widgets inside dedicated subfolders (e.g., `widgets/anime_detail/desktop/`, `widgets/player/layouts/`, `widgets/welcome/`). Keep files small, focused, maintainable, and adhering to single responsibility.
>
> **MANDATORY INTERNATIONALIZATION (i18n) RULE**:
> Whenever you add **any** new feature, screen, widget, dialog, toast, error message, or UI element that contains **user-facing text**, you **MUST** simultaneously add the corresponding translation keys to all three i18n files: `lib/core/i18n/translations/translations.dart` (abstract contract), `lib/core/i18n/translations/en.dart` (English), and `lib/core/i18n/translations/es.dart` (Spanish). **NEVER** leave hardcoded strings in any language. All user-visible text must go through `l10n.keyName`. This applies to labels, placeholders, tooltips, error messages, button text, section headers, empty states, confirmation dialogs, and snackbar messages.

---

## 1. Project Overview

**Seanime App** is a modern, high-performance cross-platform client (primarily targeted at Android mobile, with Linux, Windows, and macOS desktop support) for the [Seanime](https://github.com/5rahim/seanime) media server ecosystem.

The application allows users to:
- Browse, track, and manage their anime library and AniList sync.
- Stream anime directly via online stream providers or torrent streaming.
- Browse and read manga with integrated manga providers.
- Discover and install extensions from the community marketplace (torrent providers, stream providers, manga providers, custom sources).
- Play media using a dual-engine video playback pipeline with advanced subtitles (`.ass`), audio selection, subtitle synchronization, shaders, and real-time performance metrics.

---

## 2. Tech Stack & Key Libraries

- **Framework**: Flutter (Dart 3.x) with Material Design 3.
- **State Management**: `flutter_riverpod` (Providers, Notifiers, StateNotifiers).
- **Networking**: `dio` for REST API and JSON feeds, `web_socket_channel` for real-time Seanime server events.
- **Image Caching**: `cached_network_image`.
- **Local Storage**: `shared_preferences` for theme settings, server configuration, and player preferences.
- **Video Playback Engine**:
  - **Android**: Primary native engine is Android Media3 **ExoPlayer** + `libass-android` (via platform channels in `lib/core/player/exo_player_service.dart`), with automatic fallback to **libmpv**.
  - **Desktop / Fallback**: **libmpv** via `media_kit` and `media_kit_video` (`lib/core/player/mpv_player_service.dart`).
- **Backend (Embedded/Companion)**: Go server (`backend/`) using `echo/v4` (can run as standalone server or companion daemon on desktop/Android).
- **Icon Packs**: `lucide_icons_flutter` and Material Symbols.

---

## 3. Directory Structure

```
seanime_app/
├── AGENTS.md                         # <--- THIS FILE (Always keep updated!)
├── pubspec.yaml                      # Flutter dependencies and assets
├── analysis_options.yaml             # Dart/Flutter linting rules
├── lib/
│   ├── main.dart                     # App entry point, ProviderScope, Theme initialization
│   ├── core/
│   │   ├── api/                      # ApiClient (Dio wrapper), Endpoints, WebSocketService
│   │   ├── constants/                # AppConstants, default URLs, timeout values
│   │   ├── i18n/                     # Internationalization (AppLanguage, AppTranslations, en, es, i18nProvider)
│   │   ├── icons/                    # AppIcons, AppIconPack (lucide, material)
│   │   ├── player/                   # Video playback service wrappers
│   │   │   ├── exo_player_service.dart   # Android Media3 platform channel bridge
│   │   │   └── mpv_player_service.dart   # media_kit / libmpv service with Plezy optimizations
│   │   ├── preferences/              # PlayerEngineProvider, TitleLanguageProvider, EpisodeViewModeProvider, OnboardingProvider, DownloadPreferencesProvider, LayoutModeProvider, PlaybackProgressPreferencesProvider, AnimeFavoritesProvider, BannerBlurProvider, SubtitleStylePreferencesProvider, DesktopNavStyleProvider, glassEffectsEnabledProvider (GlassEffectsEnabledNotifier)
│   │   ├── server/                   # ServerManager, AndroidServerChannel, DesktopServer
│   │   ├── storage/                  # AppStoragePaths (Documents/Anime/aniting/ resolution for Android and Desktop)
│   │   └── theme/                    # AppTheme, ThemeProvider, AppPalette, AppThemeColors, AppScrollBehavior, smooth_scroll_controller (SmoothScrollController, SmoothTrackingScrollController, DynMouseScroll), custom_route_transitions (WebPageTransitionsBuilder, SmoothPageRoute)
│   ├── data/
│   │   ├── models/                   # Data models (AnimeEntry, MangaEntry, ExtensionItem, Torrent, ExploreCarouselConfig, etc.)
│   │   ├── repositories/             # SeanimeRepository (API methods, marketplace fetching, cache)
│   │   └── services/                 # MangaOfflineService, FeedCacheService (persistent SWR feed cache), OfflineLibraryService, ExploreCarouselService
│   └── presentation/
│       ├── providers/                # Global UI and repository providers
│       ├── screens/                  # Main application views
│       │   ├── main_shell.dart       # Shell with bottom dock / desktop sidebar
│       │   ├── welcome_screen.dart   # Welcome & initial configuration wizard (5 steps)
│       │   ├── feed_screen.dart      # Anime feed & continue watching
│       │   ├── manga_feed_screen.dart # Manga feed & continue reading
│       │   ├── search_screen.dart    # Full exploration hub (Anime/Manga, filters, calendar, genres)
│       │   ├── library_screen.dart   # User profile, AniList sync, collection stats
│       │   ├── anime_detail_screen.dart # Anime details orchestrator (delegates to adaptive layouts)
│       │   ├── anime_full_details_screen.dart # Complete metadata, characters, relations, staff
│       │   ├── manga_detail_screen.dart # Manga details, chapters, reader integration
│       │   ├── manga_reader_screen.dart # Manga image reader viewer
│       │   ├── settings_screen.dart  # App settings (theme, player engine, icon pack, server)
│       │   ├── extensions_marketplace_screen.dart # Extensions marketplace & installed list
│       │   └── video_player_screen.dart # Main video player orchestration
│       └── widgets/                  # Reusable UI components
│           ├── anime_detail/         # Modular adaptive layouts for anime details
│           │   ├── anime_detail_desktop_layout.dart # Desktop layout coordinator (~180 lines)
│           │   ├── desktop/          # Modular desktop subcomponents
│           │   │   ├── desktop_sidebar.dart            # Clean vertical poster with smooth hover scale
│           │   │   ├── desktop_header.dart             # Title, metadata row (Format, Status, Eps, Studio, Score), genres & synopsis
│           │   │   ├── desktop_action_bar.dart         # Play pill, bookmark, share, trailer, links & source pills
│           │   │   ├── desktop_hero_banner.dart        # Panoramic top banner with scroll-driven fade-to-black
│           │   │   ├── desktop_tab_button.dart         # Desktop navigation tab button with clean white indicator
│           │   │   ├── desktop_episodes_tab.dart       # Episodes coordinator (online/torrent, filters & views)
│           │   │   ├── desktop_episode_models.dart     # DesktopEpisodeItemData model
│           │   │   ├── desktop_episode_context_menu.dart # On-demand GlassCard context menu on secondary tap (Play, Watched toggle, Torrent download/delete)
│           │   │   ├── desktop_episode_grid_card.dart  # 16:9 grid episode card with dimmed watched opacity
│           │   │   ├── desktop_episode_list_card.dart  # 2-column list episode card with dimmed watched opacity
│           │   │   ├── desktop_episode_pagination.dart # 20-episode pagination bar (next/prev & page chips)
│           │   │   ├── desktop_characters_tab.dart     # Character cards grid with gentle neutral hover
│           │   │   ├── desktop_relations_tab.dart      # Relations grid with clean covers & below labels
│           │   │   └── desktop_recommendations_tab.dart# Recommendations grid with clean covers & titles below
│           │   ├── mobile/           # Modular mobile subcomponents
│           │   │   ├── anime_detail_mode_popup.dart    # Expressive spring-animated mode popup (Online/Torrent/Local)
│           │   │   ├── anime_detail_source_popup.dart  # Expressive spring-animated online sources popup
│           │   │   └── anime_detail_advanced_sheet.dart# Full modal sheet for advanced options (Sub/Dub, link, reload)
│           │   ├── anime_detail_mobile_layout.dart  # Compact vertical mobile layout with inline Action Hub
│           │   └── anime_detail_tv_layout.dart      # 10-foot remote / D-Pad focused TV layout
│           ├── manga_detail/         # Modular adaptive layouts for manga details
│           │   ├── manga_detail_desktop_layout.dart # Desktop layout coordinator (~280 lines)
│           │   ├── desktop/          # Modular desktop subcomponents
│           │   │   ├── desktop_manga_sidebar.dart      # Poster, format, status, score, year & read progress
│           │   │   ├── desktop_manga_header.dart       # Title, format/year & expandable synopsis
│           │   │   ├── desktop_manga_action_bar.dart   # Continue reading pill, bookmark, batch download & links
│           │   │   ├── desktop_manga_chapters_tab.dart # Chapter manager (providers, search, 30-chapter pagination)
│           │   │   ├── desktop_manga_chapter_card.dart # Chapter card with dimmed read opacity & download state
│           │   │   ├── desktop_manga_characters_section.dart # 2-per-row horizontal character cards (photo left, info right)
│           │   │   └── desktop_manga_recommendations_row.dart # Full-width horizontal scroll for similar works
│           │   └── manga_detail_mobile_layout.dart  # Compact vertical mobile layout (~380 lines)
│           ├── compact_search_bar.dart # Sleek, semi-transparent top search bar for feeds
│           ├── top_status_bar_glass.dart # Ambient frosted top glass protection
│           ├── media_type_toggle.dart # Non-wrapping pill toggle for Anime / Manga
│           ├── explore_hero_carousel.dart # Featured banner carousel with gradients & indicators
│           ├── calendar/             # Modular adaptive widgets for airing calendar
│           │   ├── calendar_day_tabs.dart     # Full-width day tabs header with animated sliding line indicator
│           │   ├── calendar_desktop_view.dart # Multi-column schedule layout with live time marker & sync
│           │   ├── calendar_mobile_view.dart  # Swipeable single-day focused PageView with animated tabs
│           │   ├── calendar_episode_card.dart # Compact timeline card (air time, square thumbnail, title & ep)
│           │   └── calendar_now_marker.dart   # Real-time current time indicator (clock icon + HH:mm)
│           ├── anime_card.dart       # Card displays for anime items
│           ├── manga_card.dart       # Card displays for manga items
│           ├── continue_watching_card.dart # 16:9 episode progress card
│           ├── continue_reading_card.dart  # Manga continue reading progress card
│           ├── feed_empty_state.dart       # Expressive M3 empty state for unauthenticated or empty anime/manga feeds
│           ├── desktop_sidebar.dart  # Desktop floating icon-only sidebar
│           ├── desktop_title_bar.dart # Integrated modern Windows client-area title bar with drag & caption buttons (includes DesktopSafeAppBar)
│           ├── my_lists/             # Modular desktop layouts for user collection
│           │   └── my_lists_desktop_layout.dart # Modern desktop layout with titlebar clearance, search, pills & grid
│           ├── downloads/            # Modular desktop layouts for offline downloads
│           │   └── downloads_desktop_layout.dart # Modern desktop downloads layout with safe titlebar clearance, media toggle & multi-column grid
│           ├── catalog_search/       # Modular catalog search & exploration widgets
│           │   ├── catalog_search_view.dart     # Split-column desktop catalog coordinator & mobile view
│           │   ├── catalog_filter_sidebar.dart  # Filter sidebar (search, media type, sort, genres, tags, format, season, year, score)
│           │   └── catalog_filter_dropdown.dart # Liquid glass popover dropdown using g1455 GlassPopoverAnchor
│           ├── edit_entry_modal.dart # Modern liquid glass slide-down edit entry dialog coordinator
│           ├── edit_entry/           # Modular edit entry form sub-widgets
│           │   ├── edit_entry_status_dropdown.dart # Liquid glass popover status selector with g1455 GlassPopoverAnchor
│           │   ├── edit_entry_score_slider.dart    # Liquid glass 0.0-10.0 score slider with amber star badge & +/- 0.5 steps
│           │   ├── edit_entry_stepper.dart         # Liquid glass progress & repeats steppers with progress bar & direct input
│           │   └── edit_entry_date_picker.dart     # Liquid glass start & completion date pickers
│           ├── floating_nav/         # Modular floating navigation dock & resume companion
│           │   ├── floating_dock_pill.dart        # Solid M3 dock with expandable active pill & icon-only mode
│           │   └── floating_resume_companion.dart # Solid M3 resume companion (cover poster, titles, bottom bar, play button)
│           ├── mobile_nav_dock.dart  # Mobile icon-only floating dock with sliding indicator
│           ├── mobile_floating_nav.dart # Coordinated floating dock with 2-phase zero-overlap resume animation
│           ├── online_stream_view.dart  # Stream servers, sub/dub toggle & quality selector
│           ├── extensions/           # Modular extension & marketplace widgets
│           │   └── extensions_desktop_layout.dart # Modern Seanime-style desktop layout for extensions (segmented pill, repo header, multi-column grid)
│           ├── player/               # Modular video player UI components
│           │   ├── layouts/          # Responsive desktop & mobile player layouts
│           │   ├── panels/           # Player info panel, source card & next episode card
│           │   │   ├── player_info_panel.dart    # YouTube-style info panel & side drawer
│           │   │   ├── player_source_card.dart   # Interactive playback source card & modal switcher
│           │   │   └── next_episode_card.dart    # 16:9 next episode card
│           │   ├── services/         # Playback coordinator, shader service, episode resolver, player progress manager, player window manager, player source controller
│           │   │   ├── player_playback_coordinator.dart # Dual-engine orchestration (ExoPlayer + libmpv)
│           │   │   ├── player_progress_manager.dart     # Continuity periodic updates, LastSession, AniList watch sync
│           │   │   ├── player_window_manager.dart       # Window state, fullscreen, orientation rotation & ExoPlayer surface bounds sync
│           │   │   ├── player_source_controller.dart    # Online stream source resolution, auto-streaming, live switcher & episode transition
│           │   │   ├── player_episode_resolver.dart     # Media source resolution and background prefetching
│           │   │   └── player_shader_service.dart       # Real-time mpv GLSL shader presets and pipeline
│           │   └── sheets/           # Unified settings launcher, subtitle_style_view & settings subviews
│           ├── manga/                # Manga reader widgets & keep-alive components
│           │   ├── manga_keep_alive_page.dart # Preserves offscreen manga pages in memory
│           │   ├── manga_chapter_item.dart
│           │   ├── manga_details_modal_sheet.dart
│           │   └── manga_reader_settings_sheet.dart
│           └── welcome/              # Modular welcome wizard step widgets & sheets
│               ├── welcome_step_language.dart            # Step 1: Language selection
│               ├── welcome_step_theme.dart               # Step 2: Appearance, mode graphics, icons & theme palettes
│               ├── welcome_step_content_preferences.dart # Step 3: Title language & global corner radius slider
│               ├── welcome_step_extensions.dart          # Step 4: Recommended extensions & actions
│               ├── welcome_step_anilist.dart             # Step 5: AniList integration & completion
│               └── welcome_marketplace_sheet.dart        # Full marketplace modal sheet
├── backend/                          # Seanime Go backend source code
│   └── internal/                     # Go packages (handlers, extension_repo, mediaplayers, etc.)
└── test/                             # Automated test suite (widget & unit tests)
```

---

## 4. Key Subsystems & Guidelines

### 4.1. Navigation, Feeds & Explore Architecture
- **Navigation Hierarchy**:
  - `main_shell.dart` organizes navigation into 5 primary views:
    0. **Inicio (`feed_screen.dart`)**: 100% User Library anime feed (in-page search, Continue Watching with local video playback progress, Currently Watching, Missed Sequels full uncapped list, anime recommendations).
    1. **Manga (`manga_feed_screen.dart`)**: 100% User Library manga feed (in-page search, Continue Reading with chapters progress bar & `Capítulo X - Total` format, Completed Manga, manga recommendations).
    2. **Explorar (`search_screen.dart`)**: Comprehensive exploration hub with hero banner carousel, genre chips, non-wrapping media type toggle (Anime/Manga), filters (season, year, sort), genres hub.
    3. **Calendario (`airing_calendar_screen.dart`)**: Dedicated airing calendar page tracking upcoming broadcast schedules and episode countdowns.
    4. **Perfil (`library_screen.dart`)**: User profile stats, AniList account, collection lists.
- **Airing Calendar Responsive Overhaul (`airing_calendar_screen.dart`, `widgets/calendar/`)**:
  - **Full-Width Header with Animated Sliding Line Indicator (`calendar_day_tabs.dart`)**:
    - The date header spans 100% of the screen width, rendering the 7-day schedule with `M/d` on top (15.5px bold) and weekday below (`Hoy`/`Today`, `Lun`, `Mar`, etc. or `Próx. Lun`).
    - Equipped with a smooth sliding 40px tab line indicator ("dot tipo línea / pestaña") powered by `AnimatedPositioned` with `Curves.easeOutCubic`, dynamically gliding underneath the tapped or swiped day.
  - **Desktop Multi-Column Schedule Layout (`calendar_desktop_view.dart`)**:
    - Displays all days side-by-side in responsive columns, mirroring the reference desktop design.
    - Each column scales with `math.max(totalWidth / 4.5, 290.0)` ensuring generous width, comfortable reading, large thumbnails (56x56), bold 13px air times, and smooth horizontal scrolling across the week.
    - Clicking any day in the header animates the tab line indicator and automatically scrolls the view to center/focus that column.
    - Features a real-time **Current Time Marker** (`calendar_now_marker.dart` with `🕒 HH:mm` and subtle gradient divider) inserted chronologically between past and future episodes in today's column.
  - **Mobile Day-by-Day Swipe Layout (`calendar_mobile_view.dart`)**:
    - Focuses strictly on one day at a time utilizing a smooth `PageView.builder`.
    - Bidirectional synchronization between horizontal finger swipes and the top 7-day sliding line indicator.
    - Includes `RefreshIndicator` and the current time marker.
  - **Multi-Page Airing Schedule Fetching (`seanime_repository.dart`)**:
    - `getAiringSchedule` paginates up to 250 items to ensure all 7 days of the broadcast week are thoroughly populated without being truncated by AniList's 50-item limit.
- **100% User-Library Feeds Architecture (`feed_screen.dart`, `manga_feed_screen.dart`)**:
  - **Exclusivity of User Content**: Feeds are strictly dedicated to user activity, history, and personalized recommendations. Generic exploration content (such as global Trending carousels and infinite scrolling Discover / Popular grids) has been completely removed from both feeds and consolidated into the Explore tab (`search_screen.dart`).
  - **Anime Continue Watching (`ContinueWatchingCard`, `playback_progress_preferences_provider.dart`)**:
    - Replaced the previous AniList-level progress fraction with **exact local video playback progress** (`PlaybackProgressNotifier`, backed by `local_episode_playback_progress_v1` in `SharedPreferences`).
    - **New User / Unwatched Behavior**: When an episode has not yet been played locally in the app, no progress bar is rendered—displaying only the clean episode card.
    - **In-Progress Tracking & Episode Isolation (`continue_watching_card.dart`, `playback_progress_preferences_provider.dart`, `video_player_screen.dart`)**:
      - As the user watches the video, `PlayerProgressManager` updates the local position (`mediaId_episodeNumber` -> `positionMs`, `durationMs`, `fraction`). `ContinueWatchingCard` displays a smooth progress bar for fractions between 1% and 98%.
      - **Strict Episode Progress Isolation**: `getProgress(mediaId, episodeNumber)` and `ContinueWatchingCard` strictly match playback progress against the exact requested episode (`mediaProgress.episodeNumber == epNum`). When a user completes Episode 1 and AniList advances to Episode 2, Episode 2 starts at 0% with no phantom progress bar and opens at 00:00 rather than inheriting Episode 1's finished position.
      - **Future Episode & Completion Filtering**: Animes marked as `COMPLETED` or where `progress >= totalEpisodes` are excluded from Continue Watching. If the next episode has not yet aired (and is not present on disk), it is withheld from Continue Watching while remaining cleanly in "Viendo Actualmente" (Currently Watching) until release.
      - **Movie & Single-Episode Tracking**: In `OfflineLibraryService` and `SeanimeRepository`, movies (`totalEpisodes: 1`) and single-episode media are kept as `CURRENT` during playback rather than prematurely transitioning to `COMPLETED` on episode start (`epNum >= totalEpisodes`), ensuring they appear in both Continue Watching and Currently Watching with real-time playback progress until finished. Automatic self-healing re-promotes active unfinished media from `COMPLETED` to `CURRENT`.
    - **AniZip Persistent Metadata Caching (`FeedCacheService`, `seanime_repository.dart`)**: AniZip metadata (16:9 real episode thumbnails, official localized titles, and air dates) is cached in RAM (`_aniZipMemoryCache`) and local storage (`saveAniZipRaw` / `getAniZipData`), eliminating repetitive API requests and ensuring instant 0ms episode loading.
    - **Server-First Multi-Device Synchronization & Offline Fallback (`app_providers.dart`, `feed_screen.dart`, `manga_feed_screen.dart`, `seanime_repository.dart`)**:
      - Whenever the server is online (`serverState.isOnline == true`, whether hosted locally or accessed remotely over LAN from phone/tablet), the server's database and library collections (`/api/v1/library/collection`, `/api/v1/continuity/watch-history`) are the single source of truth for `animeCollectionProvider`, `continueWatchingProvider`, `mangaCollectionProvider`, and `continueReadingMangaProvider`.
      - Removed the erroneous `if (!isLoggedIn) return OfflineLibraryService...` guard that previously forced devices to bypass the server and display out-of-sync local device databases when AniList was unauthenticated or simulated.
      - `OfflineLibraryService` is preserved strictly as an offline fallback when `serverState.isOnline == false`.
    - **Anti-CLS & Offline Cache Fallback (`feed_screen.dart`, `seanime_repository.dart`)**:
      - `continueWatchingEntries` uses memory-cached entries immediately on frame 0 while revalidation runs in the background. If the user is on a cold start without cache, the feed skeleton is preserved until both continue watching and library collections settle, eliminating layout shift (CLS).
      - If network/AniList is offline, `getContinueWatching()` and `getContinueReadingManga()` fall back to cached data without wiping local storage with empty arrays `[]`.
    - **Remote Server & LAN Discovery Resilience (`lan_discovery_service.dart`, `server_manager.dart`, `app_providers.dart`, `server_settings_screen.dart`)**:
      - **Android Socket `reusePort` Hardening**: On Android, `RawDatagramSocket.bind` rejects `reusePort: true` with `Dart Socket ERROR: socket_linux.cc: reusePort not supported on this platform`. Set to `reusePort: !Platform.isWindows && !Platform.isAndroid`, allowing mobile clients to listen for UDP discovery beacons sent by desktop servers on the local Wi-Fi without crashing.
      - **Circular Dependency Elimination in `ServerNotifier`**: Feed provider invalidations (`_invalidateFeedProviders()`) are scheduled via `Future.microtask`, and `state = ServerStateModel(state: _manager.state, ...)` is committed prior to invalidating feeds. This prevents Riverpod's `CircularDependencyError` when feed providers evaluate `serverNotifierProvider` during server transitions.
      - **Non-Blocking Server UI State**: `checkConnection()` and `switchToLocal()` are wrapped in comprehensive `try/catch` handlers guaranteeing that server state never gets locked indefinitely in `ServerState.starting`. If the server is in `starting`, the "Detener Servidor" button remains active, and the "Iniciar Servidor Local" button reflects progress without becoming permanently unresponsive.
      - **Connection Check Robustness**: Increased HTTP health-check timeout to 3000ms for stable LAN resolution over Wi-Fi, improved error feedback in `ServerManager._lastError`, and added asynchronous toasts informing users whether remote connection succeeded or failed.
      - **Dedicated Aniting Server Ports & Complete Seanime Coexistence Isolation (`AppConstants.defaultPort`, `server_manager.dart`, `lan_discovery_service.dart`, `seanime_repository.dart`, `config.go`)**:
        - **Port Independence**: Completely decoupled Aniting from Seanime's default port range (`43211`-`43214`) by establishing Aniting's dedicated default ports: HTTP API (`43311`), UDP LAN Discovery (`43312`), Torrent Client (`43313`), and Torrent HTTP Streaming Server (`43314`).
        - **Zero Process & Port Collision**: Eliminates the previous conflict where running both Seanime and Aniting concurrently caused port binding failures (`address already in use`), or where Aniting accidentally probed and connected to Seanime's server on 43211—unintentionally sharing AniList credentials, databases, and extension installations.
        - **Isolated Data & Database Storage**: Default database name set to `aniting` (`aniting.db` with auto-migration from legacy `seanime.db` in `~/.config/aniting` / `%APPDATA%\Aniting`), distinct SharedPreferences keys (`aniting_server_*`), and dedicated temporary MPV cache paths (`aniting/mpv_cache`). Both applications can now run simultaneously on the same machine with 100% independence.
    - **Detail Mode Persistence & Tab Restoration (`anime_detail_screen.dart`)**:
      - Persists user mode selection (`local`, `torrent`, `online`) per anime in `SharedPreferences` (`pref_anime_detail_mode_${mediaId}`) with a global fallback (`pref_anime_detail_last_mode`).
      - Restores the exact mode on screen initialization without forcefully resetting the user to Online or Local mode.
    - **Zero-Shift Anime Detail Layout & Repository In-Memory Cache (`seanime_repository.dart`, `anime_detail_screen.dart`, `anime_detail_desktop_layout.dart`)**:
      - **Elimination of Title & Episode List Jump (Anti-Jank Layout)**: Removed the erroneous `ConstrainedBox(minHeight: 360)` with `MainAxisAlignment.end` in `AnimeDetailDesktopLayout` that previously shoved the title and action bar to the bottom of the poster box when metadata was unloaded, causing an abrupt jump upwards when details arrived. `DesktopHeader` is now pinned directly to the top, aligned level with the poster, keeping title and action bar rock-solid at all times.
      - **Repository In-Memory Detail & Episode Caching**: Added synchronous in-memory caches `_animeDetailsCache`, `_onlinestreamProvidersCache`, `_onlinestreamEpisodesCache`, and `_mangaDetailsCache` to `SeanimeRepository`.
      - **Frame-0 Instant Rendering**: In `AnimeDetailScreen.initState()` and `AnimeDetailDesktopLayout.initState()`, cached `AnimeDetails`, `AniZipData`, and online episodes are restored synchronously on Frame 0 before the first frame builds. When revisiting previously loaded media, 100% of the UI (title, synopsis, genres, score, action buttons, and episode grid) renders immediately in its final geometry without loading spinner flashes or mid-transition layout reflows, ensuring buttery 120 FPS route transitions.
    - **Card Sizing Parity Across Feeds and Explore (`search_screen.dart`, `feed_screen.dart`, `manga_feed_screen.dart`, `explore_skeleton.dart`)**:
      - Unified anime and manga card dimensions across both desktop and mobile platforms between the Home feed and Explore screens (`cardWidth: isDesktop ? 180.0 : 135.0`, `carouselHeight: isDesktop ? 320.0 : 252.0`, `carouselSpacing: isDesktop ? 14.0 : 10.0`).
      - In `search_screen.dart`, updated curated rows (`_buildCuratedAnimeSection` and `_buildCuratedMangaSection`) to remove rigid nested constraints, utilize standard `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)` with `clipBehavior: Clip.none`, and allocate full generous sizing matching `feed_screen.dart`.
    - **Explore Hero Carousel Desktop Sidebar Blend & Synopsis (`explore_hero_carousel.dart`, `explore_carousel_config.dart`)**:
      - **Desktop Left-Edge Vignette Blend**: When in classic sidebar mode (`DesktopNavStyle.sidebar` on desktop), the hero banner incorporates a slide-level horizontal gradient (`stops: [0.0, 0.22, 0.44, 0.68, 0.88, 1.0]`) dynamically tinted with `theme.scaffoldBackgroundColor` positioned strictly in the background layer behind the logo and metadata. This completely eliminates the harsh, abrupt cut ("corte seco") against the left sidebar rail, producing a seamless, diffused cinematic transition without obscuring foreground text or logos.
      - **AniList Description Integration**: In desktop sidebar navigation mode, displays the official media description beneath the logo/title (cleaned of HTML tags, capped at 3 lines with `maxLines: 3` and clamped width to preserve poster artwork vibrance), resolving from `ExploreCarouselItem.description` or lazily querying `animeDetailsFamilyProvider(mediaId)`.
    - **ExoPlayer Plain-Text Subtitle Pipeline & Stroke Outlining (`ExoPlayerPlugin.kt`, `player_viewport.dart`)**:
      - Transmits plain-text subtitle cues (SRT, VTT) from Android Media3 `ExoPlayer` via `eventSink` stream to Flutter.
      - Rendered in Flutter with high-fidelity vector stroke outlining (`PaintingStyle.stroke`, `StrokeJoin.round`) rather than blurry shadow filters or opaque boxes, matching the visual quality of `.ass` subtitles and YouTube/Netflix player overlays.
    - **Cover Poster Cache Consistency (`anime_details.dart`, `anime_detail_mobile_layout.dart`, `anime_detail_desktop_layout.dart`)**:
      - Aligned image resolution precedence across models (`large` -> `extraLarge` -> `medium`), preserving `initialEntry.coverImage` to eliminate image reloading and flickering when transitioning from card to detail view.
    - **Search Duplication Safeguards & Two-Column Catalog Search (`search_screen.dart`, `widgets/catalog_search/`)**:
      - Debounce timer is strictly cancelled upon search submission (`onSubmitted`), preventing concurrent requests for page 1.
      - Applied `mediaId` set deduplication when appending pagination results.
      - **Advanced Two-Column Catalog Search Overhaul (`CatalogSearchView`, `CatalogFilterSidebar`, `CatalogCard`, `CatalogFilterDropdown`)**:
        - Replaced basic search slivers with a dedicated 2-column catalog view matching desktop reference design:
          - Top breadcrumb button `[🧭 Discover series]` / `[🧭 Descubrir series]` to return to Explore smoothly with back animation.
          - Large section header reflecting current query or sort (e.g., `Highest rated shows` / `Series mejor valoradas`).
          - Left filter sidebar (~220px fixed width): Title search input, media type selector (Anime/Manga), sort selector (`Highest score`, `Trending`, `Popularity`, `Start Date`), genres dropdown, tags dropdown, formats dropdown, seasons dropdown, year dropdown (`Timeless`), statuses dropdown, minimum score dropdown (`All scores`, `80+`, `70+`, etc.), Adult (+18) switch toggle, and reset button.
          - Right content grid: Modern cards with 3:4 aspect ratio, rounded corners, bottom-left episode count pill badge, bottom-right rating/star badge, title clamped to 2 lines, and season + year subtitle (e.g., `Fall 2023`).
        - **Explore Mode Simplification**: Removed horizontal genres chip strip from `search_screen.dart` to declutter Explore view; full genres remain accessible through the header category icon button.
    - **Default Downloads Storage Path (`AppStoragePaths`, `DownloadPreferencesNotifier`)**:
      - Changed default base downloads directory to `Documents/Anime/aniting/` on both Desktop (`~/Documents/Anime/aniting/`) and Android (`/storage/emulated/0/Documents/Anime/aniting/`).
      - Dedicated subfolders for media: `Documents/Anime/aniting/Anime` for anime downloads and `Documents/Anime/aniting/Manga` for manga downloads.
      - Added automatic preference migration in `DownloadPreferencesNotifier` to safely upgrade legacy `Downloads/Aniting/Downloads` paths to the new documents location without affecting user config or database.
  - **Missed Sequels Full Uncapped List (`backend/internal/api/anilist/list.go`, `feed_screen.dart`)**:
    - Previously, the Go backend capped missed sequels at `len(idsSlice) > 10`. This hardcoded slice was removed and replaced with a batched query pipeline (50 IDs per GraphQL chunk via `SearchBaseAnimeByIdsDocument`), returning 100% of missed sequels for the user.
    - The UI displays the full collection count badge in the section header.
  - **Manga Continue Reading & Recommendations (`ContinueReadingCard`, `manga_feed_screen.dart`, `seanime_repository.dart`)**:
    - `ContinueReadingCard` renders a progress bar calculated from `progress / totalChapters` (only when `totalChapters > 0`).
    - The subtitle below the title clearly displays `${l10n.chapter} $nextChapter - $totalCaps` (e.g. `Capítulo 71 - 150`).
    - Added dedicated Manga Recommendations pipeline (`getMangaRecommendationsForUser`, `kCacheMangaRecommendations`, `mangaRecommendationsProvider`) mirroring anime recommendations.
  - **Unauthenticated & Empty / Offline Library State Architecture (`feed_empty_state.dart`, `feed_screen.dart`, `manga_feed_screen.dart`)**:
    - Dedicated `FeedEmptyState` widget rendered inside `SliverFillRemaining`:
      - **Compact & Top-Aligned**: Aligned towards the top (`Align(alignment: Alignment.topCenter)`) with a compact ~85px cute illustration (`assets/images/confused.png`), avoiding invasive full-screen centering or oversized elements.
      - **Offline Mode (`isOffline: true`)**: When internet is unreachable or server fails, renders "Sin conexión a internet" with a retry button (`onRetry`) instead of asking the user to log in.
      - **Unauthenticated Mode**: "Conecta tu cuenta de AniList para sincronizar tus listas" identically in both anime and manga feeds.
      - **Minimalist Action Buttons**: Compact pills with reduced density and visual footprint: primary "Conectar con AniList" / "Reintentar" and secondary "Explorar".
  - **Explore Hub Trending & Genre Overhaul (`search_screen.dart`, `app_providers.dart`)**:
    - Replaced static "Popular ahora mismo" with "En tendencia ahora" sorted by `TRENDING_DESC` with extended 25-item carousels (`perPage: 25`).
    - Replaced fantasy row with curated trending genre carousels: "Romance en tendencia", "Acción en tendencia", and "Comedia en tendencia" (`genre: 'Romance'|'Action'|'Comedy'`, `sort: 'TRENDING_DESC'`, `perPage: 25`).
    - Mirroring identical trending structure for manga explore curation.
  - **Explore Hero Carousel Remote Configuration & HQ Assets (`explore_carousel_config.dart`, `explore_carousel_service.dart`, `explore_hero_carousel.dart`, `data/explore_carousel.json`)**:
    - **Remote JSON GitHub Source**: Featured hero carousel entries are dynamically controlled via `data/explore_carousel.json` (hosted at `https://raw.githubusercontent.com/anyyting-es/aniting/main/data/explore_carousel.json`), allowing instant updates without app recompilation.
    - **Startup-Only Synchronization**: Verification executes strictly **once at application startup** (`ExploreCarouselNotifier.syncOnStartup()` triggered in `MainShell.initState()`), never pinging the network on tab switches to Explore.
    - **SWR & Local Offline Cache**: Employs bundled asset fallback (`assets/data/explore_carousel.json` / `defaultFallbackConfig`) and `SharedPreferences` caching (`explore_carousel_config_json_v1`). Renders frame 0 instantly with 0ms delay.
    - **HQ TMDB Assets, Prominent Logos & Cinematic Layout Overhaul**:
      - **Expanded Cinematic Dimensions & Framing**: Height dynamically scales to **~70% of screen height (clamped between 620–760dp) + topPadding on Desktop** and **~58% of screen height (470–580dp) + topPadding on Mobile**, commanding the viewport like Netflix/Apple TV+. Vertical image framing is tuned to `y = -0.42` on desktop horizontal backdrops, completely eliminating character head cropping and revealing the full artwork composition.
      - **In-Place Dissolve & Fixed Logo Stability**: Crossfades between slides in-place using `Transform.translate(counterOffset)` and `Opacity(smoothOpacity)` without physical page sliding. Logos are anchored inside a constant-height container (`SizedBox(height: isDesktop ? 120 : 65)`) with `bottomLeft` alignment and `fadeInDuration: Duration.zero`, eliminating vertical jumps (CLS) during slide transitions.
      - **Persistent Viewport Bottom Blend & Subpixel Bridge**: Anchored on the outer `ExploreHeroCarousel` Stack, a persistent static bottom gradient (`68dp` desktop / `44dp` mobile) and a 2.5px subpixel seam bridge permanently seal the carousel foot to `theme.scaffoldBackgroundColor`. This prevents slide `Opacity` from fading the bottom shadow mid-animation, completely stopping backdrop artwork colors from bleeding at the seam or creating an ugly separating line of color before the following section.
      - **Prominent Transparent PNG Logos**: Scaled up to 120dp maxHeight (Desktop) and 65dp (Mobile), with fallback to stylized title typography if loading or absent.
      - **Refined Horizontal Vignette & Eased Shadows**: Softened left-to-right gradient scrim to maximize character vibrancy on the left while ensuring 100% logo and typography contrast. Smooth cubic 320dp bottom feather into background.
      - **Desktop Navigation Arrows**: Discrete circular floating Prev/Next chevron buttons for smooth mouse interaction on desktop monitors.
      - **Interactive Details Action Button**: Direct `FilledButton.icon` ("Detalles" / "Details") linking straight to `AnimeDetailScreen`.
      - **0% Idle GPU & RAM Texture Optimizations (`optimizeTmdbImageUrl`, `AnimeCard`, `ExploreHeroCarousel`)**:
        - Removed continuous 24/7 Ken Burns pan animation controllers in `_HeroBannerSlide`, rendering the backdrop statically so the GPU sits at 0% when idle instead of spinning at 60% with continuous 144Hz repaints.
        - **TMDB Native Downscaling Pipeline (`optimizeTmdbImageUrl`)**: Replaces heavy uncompressed 4K `original` endpoints (which weighed 1.14 MB compressed and decoded to ~33.1 MB RGBA each) with native TMDB endpoints (`w1280` backdrops on desktop, `w780` on mobile; `w500` logos on desktop, `w300` on mobile). This reduces texture payload by >90% and logo size by 99.5% (from 2.9 MB to 15 KB), eliminating GPU texture upload hitches ("tirones de lag").
        - **Offscreen Slide Pruning in Carousel**: Early returns `SizedBox.shrink()` whenever `pageOffset.abs() >= 1.0` or `opacity <= 0.005`, completely preventing Flutter from creating offscreen Skia GPU layers and painting heavy textures for non-visible carousel items.
        - **AniList Cover Downscaling (`large` over `extraLarge`)**: In `AnimeEntry.fromJson` and `MangaEntry.fromJson`, prioritizes `cover['large']` (~350x500) over `cover['extraLarge']` (~1000x1400), slashing raw bitmap memory by >80% across all lists, grids, and cards.
        - **Right-Sized Card Cache Bounds**: Reduced `memCacheWidth` / `memCacheHeight` in `AnimeCard` and `MangaCard` from 440x640 to 220x310 (compact) / 280x390, matching actual display bounds and saving ~75% RAM per card. Added `cacheExtent: 150` to curated Explore rows and removed unnecessary startup genre precaching.
        - **Offscreen Auto-Play Pausing**: Guarded `_autoPlayTimer` with `TickerMode.of(context)` so the carousel never cycles or forces repaints in the background while the user is viewing other tabs.
        - **Zero Startup Eager Allocations**: Eliminated aggressive startup pre-caching from `ExploreCarouselNotifier.syncOnStartup()`, ensuring baseline app startup memory remains lean until the user actively browses Explore.
  - **Dual-Mode Desktop Navigation Architecture (`desktop_nav_style_provider.dart`, `mobile_floating_nav.dart`, `main_shell.dart`, `personalizacion_settings_screen.dart`)**:
    - Introduced user-configurable desktop navigation mode via `desktopNavStyleProvider` (`desktop_nav_style_v1` in `SharedPreferences`), allowing users on desktop and wide screens (>= 720dp) to choose their preferred navigation paradigm:
      - **Sidebar Clásico (`DesktopNavStyle.sidebar`, predeterminado)**: Classic vertical icon sidebar (`DesktopSidebar`) fixed to the left rail.
      - **Dock Flotante (`DesktopNavStyle.floating`)**: Enables full-bleed canvas width (`extendBody: true`) where hero carousels and multi-column feeds span 100% of the display, coupled with a bottom-centered floating dock pill and hero resume companion.
    - **Ultra-Wide Desktop Geometry Adaptation (`mobile_floating_nav.dart`)**: On desktop resolutions (e.g. 1920x1080, 2K, 4K), the resume companion width is capped to `math.min(availableWidth, 560.0)` and horizontally centered symmetrically above the centered dock pill, ensuring balanced, modern aesthetic proportions.
    - Configurable from Settings -> Personalización -> Estilo de navegación en escritorio (`desktopNavStyle`).
  - **Zero-Width & Negative Constraints Protection in Floating Navigation (`mobile_floating_nav.dart`, `floating_resume_companion.dart`)**:
    - During initial window frames (e.g. Waydroid initialization or Android split-screen mapping), `constraints.maxWidth` can transiently report `0.0`. Subtracting margins (`totalWidth - marginH * 2`) previously created negative box constraints (`w=-52.0`), throwing a Flutter `BoxConstraints has a negative minimum width` rendering assertion.
    - Added guard conditions: `totalWidth <= 0 || constraints.maxHeight <= 0` yields `SizedBox.shrink()`, `availableWidth` and `resumeWidth` are clamped to `math.max(0.0, ...)`, and `FloatingResumeCompanion` Container enforces non-negative width/height, eliminating initialization crashes.
  - **Desktop Sidebar Profile Avatar (`desktop_sidebar.dart`, `main_shell.dart`)**:
    - `DesktopSidebarItem` supports an optional `avatarUrl`.
    - When logged in with an AniList avatar, the sidebar renders a circular avatar image with an active selection ring; if unavailable, it smoothly falls back to the profile icon.
  - **Desktop & Web Smooth Mouse Scrolling System (`smooth_scroll_controller.dart`, `app_scroll_behavior.dart`)**:
    - Built a high-performance, browser-grade smooth scroll engine (inspired by Chromium, Firefox, and Lenis) via `SmoothScrollController`, `SmoothScrollPosition`, `SmoothTrackingScrollController`, and `DynMouseScroll`.
    - **Single Ticker with Exponential Smoothing (`1.0 - exp(-smoothingFactor * dt)`)**: Replaced jerky per-tick animation-restart loops with a continuous vsync Ticker. Wheel ticks update future target pixels without restarting animations from 0, producing identical fluid physics to modern web browsers.
    - **Mechanical Mouse Wheel Encoder Bounce Filter**: Faulty or worn mouse wheels frequently send accidental micro-reverse ticks (< 35px) while scrolling in one direction; these hardware bounce glitches are automatically filtered out, eliminating stutter.
    - **Precision Touchpad & Trackpad Heuristic**: Sub-4px continuous deltas are identified as touchpad signals and bypass the ticker for instantaneous 1:1 direct tracking, eliminating touchpad lag or molasses resistance.
    - Direct gesture interruptions (touch dragging, scrollbar dragging, programmatic `jumpTo`) immediately stop the ticker and grant 1:1 control with zero resistance.
    - Integrated across primary application views: `FeedScreen`, `MangaFeedScreen`, `SearchScreen`, `LibraryScreen`, `AnimeDetailDesktopLayout`, `MangaDetailDesktopLayout`, and `GenreDetailScreen`.
- **Comprehensive Subtitle Customization & Styling Architecture (`subtitle_style_preferences_provider.dart`, `subtitle_style_view.dart`, `ExoPlayerPlugin.kt`, `mpv_player_service.dart`, `player_playback_coordinator.dart`)**:
  - **Universal Preference Store (`subtitle_style_preferences_provider.dart`)**:
    - Centralized `SubtitleStylePrefs` state stored in `SharedPreferences` (`subtitle_style_prefs_v1`) managing: font family, font size scale (0.7x - 2.0x), bold, italic, text color (HEX ARGB), background box color & opacity (none, subtle, medium, solid), border & shadow style (`none`, `outline`, `dropShadow`, `raised`, `depressed`), border/shadow size (0 - 6px), and `overrideAss` flag.
    - Includes one-tap `resetToDefaults()` and helper getters for Flutter `TextStyle`, text shadows, and MPV color formatting (`&HAABBGGRR`).
  - **ExoPlayer Pipeline (Android Native Media3 & LibASS)**:
    - Android platform bridge (`ExoPlayerPlugin.kt`): method `"setSubtitleStyle"` dynamically builds a native `CaptionStyleCompat` specifying edge type, edge color, foreground color, background color, and window color, alongside fractional text sizing (`setFractionalTextSize`).
    - **Dual Subtitle View Coordination & ASS Override Control**: When `overrideAss` is disabled (default), original `.ass` styles are strictly preserved via `assSubtitleSurfaceView` and plain-text fallback cues are suppressed. When `overrideAss` is enabled, `.ass` view is muted and native `standardSubtitleView` applies the user's custom typography, colors, and shadows to all subtitles.
    - Viewport overlay (`player_viewport.dart`): Cues rendered directly in Flutter are dynamically styled using `ref.watch(subtitleStylePreferencesProvider)` with matching multi-directional text shadows.
  - **MPV Engine Pipeline (Desktop & Fallback Engine)**:
    - `applySubtitleStyle` in `mpv_player_service.dart` sets properties dynamically: `sub-font`, `sub-font-size`, `sub-bold`, `sub-italic`, `sub-color`, `sub-back-color`, `sub-border-color`, `sub-border-size`, `sub-shadow-offset`, and `sub-ass-override` (`'force'` when overridden, `'no'` to preserve `.ass` typesetting).
  - **Playback Orchestration (`player_playback_coordinator.dart`, `video_player_screen.dart`)**:
    - Active engine (`ExoPlayer` or `MPV`) applies the user's subtitle styling upon initialization and live-updates during playback whenever preferences change via Riverpod listener.
  - **Modular Settings & In-Player UI (`subtitle_style_view.dart`, `player_settings_sheet.dart`, `player_settings_screen.dart`)**:
    - Accessible both inside the video player settings sheet and from the global App Settings > Player subpage.
    - Features a real-time live preview card with video aspect ratio, ASS override toggle card, font family chips, font size slider, bold/italic toggles, 7 text color presets, 4 background transparency options, 5 border/shadow styles, border size slider, reset button with confirmation modal, and complete i18n support.
- **Mobile Beta 1.0.0 Defaults & UI Refinements (`mobile_nav_style_provider.dart`, `resume_bar_preferences_provider.dart`, `theme_provider.dart`)**:
  - **Floating Dock Navigation as Default**: Mobile navigation style is defaulted to `MobileNavStyle.floating` for a sleek, non-intrusive bottom navigation dock.
  - **Resume Companion Disabled by Default**: The "Sigue donde estabas" resume companion is turned off by default (`resume_bar_enabled = false`) to keep the interface clean and spacious for first-time users.
  - **OLED Pure Black as Default Theme**: Default theme mode is dark with OLED True Black enabled (`isOled: true`, `paletteId: AppPalettes.oledBlackId`). Selecting another palette dynamically disables OLED mode and adopts the chosen palette's colors.
  - **Anime Detail Mobile Action Bar**:
    - Clean horizontal action cluster: Primary "Comenzar a ver" / "Continuar" pill button flanked by Trailer, AniList Status Edit, and Favorites toggle icons.
    - Minimalist mode dropdown (`PopupMenuButton` anchored below the mode button with compact options "Online" and "Torrent").
- **System UI Overlay & Status Bar Synchronization Architecture (`main.dart`, `main_shell.dart`, `theme_provider.dart`, `anime_detail_mobile_layout.dart`, `manga_detail_mobile_layout.dart`)**:
  - **Global & Shell `AnnotatedRegion<SystemUiOverlayStyle>`**: Configured persistent `AnnotatedRegion` at `MaterialApp.builder` and `MainShell` matching the active theme's brightness and scaffold background. Guarantees that when returning from detail pages, video players, or settings, the system status bar icon brightness immediately and faithfully snaps back to the theme color scheme instead of remaining stuck on white/dark icons.
  - **Scroll-Aware Transparent AppBars**: In `AnimeDetailMobileLayout` and `MangaDetailMobileLayout`, `SliverAppBar` explicitly provides a dynamic `systemOverlayStyle` adapting between light icons (over the dark ambient banner at the top) and dark icons (when scrolled past the banner in light mode), with back/action icons responding in tandem.
  - **Player & Reader Exit Cleanup**: `PlayerWindowManager` and `MangaReaderScreen` dispose callbacks safely restore standard edge-to-edge orientation and status bar overlay styles reflecting the current theme.
- **Desktop Player Default Viewport Optimization (`video_player_screen.dart`)**:
  - `_isSidePanelCollapsed` defaults to `true` on desktop platforms (`!Platform.isAndroid && !Platform.isIOS`), allowing the player viewport to claim 100% of the window width by default while retaining the collapsible sidebar toggle button.
- **Batch Torrent Precision Detection & Built-In Torrent Client Downloads (`torrent_selector_sheet.dart`, `torrent_batch_files_sheet.dart`, `seanime_repository.dart`, `desktop_action_bar.dart`, `anime_detail_mobile_layout.dart`)**:
  - **Batch Misdetection Fix (`S3-04` and Single-Episode Releases)**:
    - Addressed root cause of false-positive batch labeling where releases formatted like `S3-04`, `S03E04`, `S1 - 04`, `Ep 04`, or `Capítulo 04` were wrongly flagged as batches due to an overly broad season range regex (`(?:s|season)?\d{1,2}[-~](?:s|season)?\d{1,2}`) matching single season + episode notation as a season range (`Season 3 to Season 4`).
    - Aligned batch detection logic with official Seanime (`5rahim/seanime`): single episode patterns (`\b[sS]\d{1,2}\s*[-_eE]\s*\d{1,3}\b`, `\b(?:ep|eps|e|cap|capitulo|cap[ií]tulo|episodio)\.?\s*0*(\d{1,4})\b`, `\s+-\s+0*(\d{1,3})(?:v\d+)?\b`) are checked first, and if present without multi-episode ranges or explicit batch keywords (`\b(batch|complete\s*series?|completa|completo)\b`), strictly disqualify the release from being a batch.
    - Multi-season range regex now strictly requires `s` or `season` on both sides (`\b[sS]\d{1,2}\s*[-~]\s*[sS]\d{1,2}\b` or `\b(?:season|temporada)\s*\d{1,2}\s*[-~]\s*(?:season|temporada)?\s*\d{1,2}\b`), eliminating false positives.
  - **In-Sheet Episode Selector Dropdown (`TorrentSelectorSheet`)**:
    - The top header now features an integrated Episode Dropdown Selector allowing users to jump directly between episodes (`Ep 1`, `Ep 2`, ..., `Todos / Batches`) without closing and re-opening the sheet.
    - Selecting an episode automatically updates the search query and re-triggers torrent search. Selecting "Todos / Batches" sets `_showOnlyBatches = true` and searches for complete releases.
  - **Compact Filter Controls Bar**:
    - Consolidated provider and quality selection into sleek, compact side-by-side dropdowns alongside the Batch toggle chip, Smart Search toggle button, and Refresh icon, saving significant vertical screen real estate.
  - **Built-in Torrent Client Background Downloads (`/api/v1/torrent-client/download`)**:
    - Integrated direct download actions into every torrent card (`Icons.download_rounded`), batch files bottom action sheet, and anime detail desktop/mobile action bars.
    - Tapping download triggers `repo.downloadTorrentToClient(...)` which queues background downloading in the embedded Seanime BitTorrent client directly into the anime library folder, accompanied by confirmation snackbars.
- **Feed Initial Loading Barrier, Cache-First & SWR Anti-CLS Architecture (`feed_screen.dart`, `FeedCacheService`, `app_providers.dart`)**:
  - **Zero Content Layout Shift (CLS) via Persistent SWR**:
    - Rather than letting fast public providers (`trendingAnimeProvider`, `popularAnimeProvider`) resolve first and render at the top while slow private providers (`continueWatchingProvider`, `animeCollectionProvider`) pop in seconds later to violently push content down, the feed employs a high-performance **Stale-While-Revalidate (SWR) cache-first pipeline**:
    - `FeedCacheService` stores critical user and public feeds in RAM (for synchronous 0ms lookups) and persists them to `SharedPreferences` (JSON serialization via `AnimeEntry.toJson()` and `ServerStatus.toJson()`).
    - **Instant Warm Starts (0ms latency)**: On app launch or feed opening, providers immediately serve cached content (`continueWatching`, `collection`, `trending`, `serverStatus`). The user's "Seguir Viendo" and "Viendo Actualmente" are rendered in their exact positions from frame 1 with **0px layout shift**.
    - **Background Revalidation (SWR)**: As soon as the server connection is confirmed (`serverState.isOnline`), `fetchFresh()` updates the cache quietly in the background without clearing or flashing widgets.
    - **First-Run Synchronized Barrier**: When the app opens for the very first time (cache empty), `loadAnimeWithCacheAndSwr` suspends completion during `ServerState.starting` instead of emitting a premature false-empty `[]`. `showFeedSkeleton` remains active until all sections for the current user state have finished their real fetch, rendering the entire feed all at once ("todo de una") without partial or displaced renders.
  - **Elimination of Server Startup Flash**: The server offline banner is gated strictly to `ServerState.stopped` and `ServerState.error`. When `ServerNotifier` starts in `ServerState.starting`, no false "Iniciar Servidor" banner flashes.
- **AniList Sync & Login Rate-Limit Resilience (`seanime_repository.dart`)**:
  - Extended Dio `receiveTimeout` to 90 seconds for `/auth/login` and `/anilist/collection` to accommodate Go backend's automatic 60-second retry loop upon hitting AniList's 90 req/min rate limit (HTTP 429).
  - Clear and informative user-facing exceptions distinguishing between actual invalid tokens vs temporary AniList rate limits / connection timeouts.
- **Torrent Streaming Swarm Resolution Resilience, Safe Player Dispose & Mobile Deadlock Prevention (`seanime_repository.dart`, `video_player_screen.dart`, `backend/internal/torrentstream/stream.go`)**:
  - **Embedded Go Server Deadlock Prevention on Mobile**:
    - Previously, exiting the video player triggered `stopTorrentStream` (`/api/v1/torrentstream/stop`). In the Go backend, `StopStream` attempted to stop desktop media players via `r.client.repository.mediaPlayerRepository.Stop()`. On Android/iOS mobile runtimes, desktop media players are uninitialized (`nil`), triggering a panic (`invalid memory address or nil pointer dereference`).
    - While `recover()` caught the panic, it aborted `r.client.mu.Unlock()`, permanently leaving the Go client mutex locked. When starting any subsequent torrent, `StartStream -> ResetBaselines()` blocked forever on `c.mu.Lock()`, leaving the UI spinning indefinitely until Dio aborted at 90 seconds.
    - **Dual-Layer Fix**:
      1. `seanime_repository.dart`: `stopTorrentStream()` now skips calling `/api/v1/torrentstream/stop` on Android and iOS. The embedded Go server already automatically drops previous excess torrents and purges storage during `startTorrentStream -> dropExcessTorrents()`.
      2. Go Backend (`stream.go`): `r.client.mu.Unlock()` is now deferred (`defer r.client.mu.Unlock()`) and `mediaPlayerRepository` is guarded with `if r.client.repository.mediaPlayerRepository != nil` in both `StopStream` and `DropLastTorrent`, making the Go backend impervious to mutex leaks.
  - Extended Dio `receiveTimeout` to 90 seconds (from the default 15s) for `startTorrentStream` (`/api/v1/torrentstream/start`). BitTorrent DHT discovery, tracker queries, peer handshakes, and file piece prioritization frequently exceed 15 seconds on less active swarms. The previous 15s timeout caused premature client abortions while the Go engine was still connecting, leading to infinite retry timeout loops.
  - In `video_player_screen.dart`, wrapped `LastSessionNotifier.saveSession()` inside `Future.microtask(...)` and guarded `_savePlaybackProgress()` / `_syncAnimeProgressIfNeeded()` with `try/catch` during `dispose()`. Prevents Riverpod's `Tried to modify a provider while the widget tree was building` exception from aborting the player widget unmount sequence and skipping native controller / coordinator cleanup.
- **Torrent Batch Inspection & Intelligent Episode Auto-Matching Architecture (`torrent_batch_files_sheet.dart`, `torrent_selector_sheet.dart`, `seanime_repository.dart`, `torrent_file_preview.dart`)**:
  - **Batch Identification & Badging**: Automatically identifies batch torrents via `torrent.isBatch == true` or regex pattern matching on title (`[01-12]`, `Batch`, `Complete`, `Season`, etc.) and renders an expressive purple "Batch" badge.
  - **Pre-Flight File Inspection (`/api/v1/torrentstream/torrent-file-previews`)**:
    - When tapping a batch torrent (or pressing the dedicated "Ver archivos" folder button on any torrent card), the app queries the Go backend to inspect all torrent files before starting the stream.
  - **Intelligent Episode Auto-Matching (`TorrentBatchFilesSheet.findBestMatch`)**:
    - 4-tier comparison pipeline:
      1. Server-parsed `isLikely == true` flag.
      2. Exact parsed `episodeNumber == targetEpisodeNumber`.
      3. Client-side regex heuristic on filename (e.g. `E02`, `- 02 `, `[02]`, `Ep 2`).
      4. Fallback to first video file (`.mkv`, `.mp4`, `.avi`, etc.).
    - The matching file is pre-selected by default and badged with a gold "Episodio actual" chip.
  - **User Flexibility & Manual File Selection**:
    - Displays the complete file list with search filter input (`Filtrar archivos o episodio...`), file names, parsed episode titles, and radio selection.
    - User can seamlessly tap any other file (e.g., OVAs, movies, or alternative episodes) to override selection.
  - **Targeted File Streaming (`fileIndex`)**:
- **Android 14+ Foreground Service, SECCOMP Syscall Emulation & Crash Resilience (`AssKt.c`, `SeanimeServerService.kt`, `SeanimeServerRuntime.kt`, `MainActivity.kt`, `welcome_screen.dart`)**:
  - **Android 14 FGS Type Requirement (`FOREGROUND_SERVICE_TYPE_DATA_SYNC`)**:
    - Under Android 14 (API 34+ / `UPSIDE_DOWN_CAKE`), calling `startForeground(id, notification)` without specifying the declared foreground service type throws a fatal `MissingForegroundServiceTypeException` and terminates the application process.
    - Updated `SeanimeServerService.onStartCommand()` with a version-guarded `startForeground(..., ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)` call wrapped in `runCatching`, protecting low-RAM and Android 14/Android Go devices (e.g. Infinix Smart 9, Transsion XOS, MIUI).
  - **Android 14 SECCOMP Syscall Emulation for Pure-Go SQLite (`android/libass/src/main/cpp/AssKt.c`)**:
    - **Problem**: Android 14's kernel `seccomp-bpf` filter traps deprecated 64-bit syscalls (such as `lstat` [6], `stat` [4], `unlink` [87], `open` [2], `access` [21], etc.) that are no longer used by Android's Bionic C library, raising a `SIGSYS` (`SYS_SECCOMP`) signal. The Go backend's embedded SQLite driver (`modernc.org/sqlite` via `modernc.org/libc`) invokes `unix.Syscall(unix.SYS_LSTAT, ...)` on x86_64 Linux targets without fallback. Merely catching `SIGSYS` and returning `-ENOSYS` caused SQLite's VFS to fail immediately (`SQLITE_CANTOPEN: unable to open database file: out of memory (14)`), triggering `logger.Fatal` and killing the whole process with `os.Exit(1)`.
    - **Solution**: Inside `sigsys_filter_handler` (`AssKt.c`), registered via `JNI_OnLoad` before `gojni` loads:
      - Uses thread-local reentrancy guards (`s_in_sigsys`) to prevent signal handler recursion.
      - Intercepts trapped filesystem syscalls on x86_64 (`lstat`, `stat`, `fstat`, `open`, `access`, `unlink`, `rmdir`, `mkdir`, `rename`, `readlink`, `chmod`, `chown`, `pipe`, `dup2`) and transparently emulates them using modern, Bionic-permitted POSIX `*at` system calls (`fstatat(AT_FDCWD, path, buf, AT_SYMLINK_NOFOLLOW)`, `openat`, `unlinkat`, `mkdirat`, etc.).
      - For unhandled or modern syscalls probed by Go runtime (e.g., `clone3`, `pidfd_open`, `close_range`), gracefully returns `-ENOSYS`, enabling the Go runtime's internal fallback mechanisms without terminating the application.
  - **Platform Channel & Service Launch Exception Safety**:
    - Wrapped `startForegroundService` in `SeanimeServerRuntime.start()` with `runCatching` to gracefully handle `ForegroundServiceStartNotAllowedException` or battery optimization kills without tearing down Flutter.
    - Wrapped MethodChannel handlers in `MainActivity.kt` (`startServer`, `stopServer`, `getStatus`) in `try/catch` blocks.
    - Added safe fallback for notification icons (`stat_notify_sync`) in case `applicationInfo.icon` is null or invalid.
  - **Zero-Collision Declarative Navigation (`welcome_screen.dart`, `main.dart`)**:
    - Removed redundant `Navigator.pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()))` on onboarding completion. Since `MaterialApp.home` watches `onboardingProvider`, switching `onboardingProvider` declaratively updates the root route, eliminating duplicate `MainShell` instances, double server starts, and navigator stack corruption.
- **Autonomous Offline Library & Guest Feed Architecture (`OfflineLibraryService`, `app_providers.dart`, `feed_screen.dart`, `manga_feed_screen.dart`, `edit_entry_modal.dart`)**:
  - **Zero-Login Required for Feeds & Continuity**:
    - Users can start browsing, streaming anime (online or torrent), and reading manga without connecting an AniList account or starting a remote media server.
    - As soon as the user starts playing an episode or reading a chapter, `OfflineLibraryService` automatically records the entry into persistent local storage (`local_offline_anime_entries_v1` and `local_offline_manga_entries_v1` via `SharedPreferences` + synchronous 0ms in-memory cache).
  - **Dynamic Feed Self-Assembly**:
    - **Continue Watching / Continue Reading**: Automatically populates `continueWatchingProvider` and `continueReadingMangaProvider` with next episode/chapter numbers, AniZip titles/thumbnails, and exact playback progress bars.
    - **Currently Watching / Reading**: Local collection entries with status `'CURRENT'` or `'WATCHING'` / `'READING'` immediately populate the "Viendo Actualmente" and "Leyendo Actualmente" carousels.
    - **Personalized Recommendations**: `recommendationsProvider` and `mangaRecommendationsProvider` inspect local watched media IDs and query public AniList GraphQL (`getRecommendationsForUser` / `getMangaRecommendationsForUser`), dynamically assembling the "Te podría gustar" recommendation row without needing an AniList authentication token.
  - **Empty State & Call-to-Action Refinement (`FeedEmptyState`)**:
    - When unauthenticated with 0 watched items, the empty state displays friendly exploration copy: "Comienza a explorar / Explora el catálogo o reproduce cualquier serie para armar tu feed automáticamente, o conecta tu cuenta de AniList".
    - The primary button is "Explorar" (`FilledButton.icon`), smoothly redirecting the user to the exploration hub to start watching, with "Conectar con AniList" as a clean secondary option (`OutlinedButton.icon`).
  - **Offline List Management (`EditEntryModal`)**:
    - If the user changes status (Watching, Completed, Planning, Dropped), score, or progress via `EditEntryModal` while unauthenticated or offline, the modal saves directly to `OfflineLibraryService` and informs the user with "Guardado en tus listas locales", preventing false error snackbars.
- **Explore Hub "Populares del momento" Priority (`search_screen.dart`, `popularAnimeProvider`, `popularMangaProvider`)**:
  - In `search_screen.dart`, the curated section "Populares del momento" (`l10n.popularOfTheMoment`) is positioned as the very first line/row immediately below the genre filter chips for both Anime and Manga modes.
  - Tapping "Ver más" seamlessly expands into a paginated full grid filter.
- **Manga & Anime Detail Desktop Architecture Refinements (`desktop_action_bar.dart`, `desktop_manga_action_bar.dart`, `desktop_manga_header.dart`, `desktop_manga_characters_section.dart`, `desktop_manga_recommendations_row.dart`, `manga_detail_desktop_layout.dart`)**:
  - **Unified Brand Icon Buttons (AniList & MyAnimeList)**:
    - In both Anime and Manga Desktop Action Bars, brand icons (`_HoverBrandIcon`) are wrapped in rounded button containers (`borderRadius: BorderRadius.circular(10)`, padding 8, size matching neighbor `_HoverIconButton` at ~38-40px).
    - Image assets feature rounded clipping (`ClipRRect(borderRadius: BorderRadius.circular(5))`) and consistent hover scale and background highlights.
  - **Manga Desktop Read Button (`_HoverReadButton`)**:
    - The "Continuar Leyendo" button is rendered as a sleek, non-stretched compact pill (`minimumSize: Size(0, 38)`, `padding: (18, 8)` horizontal/vertical) with tactile shadow.
  - **Zero-Rebuild Scroll Architecture (60-120 FPS Fluidity)**:
    - Eliminated root `setState` calls in `_onScroll` across both `MangaDetailDesktopLayout` and `AnimeDetailDesktopLayout`.
    - Dissolve animation of `DesktopHeroBanner` is driven via isolated `ValueNotifier<double> _scrollProgressNotifier` consumed inside `ValueListenableBuilder<double>`, eliminating whole-tree rebuilds during scroll and locking frame rates to 60-120 FPS.
  - **Single-Column Chapter List (`DesktopMangaChaptersTab`)**:
    - Replaced multi-column grid with full-width single-column `ListView.separated` (1 chapter per row) for clear legibility and faster layout passes.
  - **Unboxed & Enlarged Character Cards (`DesktopMangaCharactersSection`)**:
    - Removed container boxes, borders, and dark rectangular cards ("unboxed").
    - Enlarged character photo (60×80px) and typography (`fontSize: 14` for name, `fontSize: 12` for role/CV).
  - **Prominent Bottom Horizontal Similar Works (`DesktopMangaRecommendationsRow`)**:
    - Removed decorative leading icon from the "Obras similares" header.
    - Enlarged card dimensions from 130px to 165px width (~290px row height) with 0.70 aspect ratio artwork for rich cover previews.
  - **Continuous Chapter List & Compact Search (`DesktopMangaChaptersTab`, `manga_detail_mobile_layout.dart`)**:
    - Removed 30-chapter block jump boxes and block pagination, displaying a continuous chapter list starting from the next chapter to read.
    - "Ocultar vistos" is enabled by default (`_hideRead = true`), rendered as a sleek `IconButton` in the mobile header without bulky chips.
    - Mobile manga detail search bar is streamlined to a slim, low-profile input (`height: 36`) and aligned with the provider dropdown.
  - **Airing Calendar Unboxed & Theme-Consistent Architecture (`airing_calendar_screen.dart`)**:
    - Unboxed the horizontal day selector chips: removed container background boxes, borders, and colors; dates are rendered as clean typography with an active indicator dot beneath the selected day, respecting OLED and palette themes.
    - Eliminated card boxes, grey borders, and boxed badge containers from schedule list items, rendering clean typography (`Ep. X • HH:mm • en Y`) with subtle divider lines.
  - **Anime Downloads Local Disk Filtering (`downloads_screen.dart`, `seanime_repository.dart`, `downloadedAnimeProvider`)**:
    - Fixed an issue where the Downloads screen previously watched `animeCollectionProvider` (cloud watchlist), showing unwatched and streaming anime as downloaded.
    - Introduced `downloadedAnimeProvider` querying `getDownloadedAnime()`, inspecting `hasLocalFiles` and `mainFileCount > 0` (from `libraryData` / `nakamaLibraryData`) to strictly display media stored on the local filesystem.
  - **Universal Navigation Profile Avatar (`floating_dock_pill.dart`, `mobile_nav_dock.dart`, `main_shell.dart`)**:
    - Extended `FloatingDockPill`, `MobileNavDock`, and the classic `NavigationBar` in `MainShell` to render the user's AniList profile avatar (`CachedNetworkImage` with fallback to `AppIcons.profile`) identically to `DesktopSidebar`.
- **In-Player Streaming Provider Switching Architecture (`player_source_card.dart`, `player_info_panel.dart`, `video_player_screen.dart`, `app_providers.dart`)**:
  - **Direct Provider Switching in Playback**: Users can tap `PlayerSourceCard` while an episode is actively searching for sources (`isResolvingSources`), during error states, or during active playback to open the playback sources modal.
  - **Installed Providers Picker**: The modal renders a top row with installed online stream providers (`onlinestreamProvidersProvider`) using clean `ChoiceChip` widgets.
  - **Seamless Re-resolution (`_switchOnlineStreamProvider`)**: Selecting a new provider calls `_switchOnlineStreamProvider(newProviderId)` in `_VideoPlayerScreenState`, updating the active provider, clearing stale sources, and invoking `_sourceController.resolveInitialSources(preservePosition: true)` to automatically resolve and start streaming from the newly selected provider without exiting the player or losing playback position.
- **In-App GitHub Releases Auto-Updater Architecture (`AppUpdateService`, `AppUpdateDialog`, `app_update_provider.dart`, `MainActivity.kt`, `file_paths.xml`)**:
  - **Zero-Cost GitHub Releases Pipeline**: Queries `https://api.github.com/repos/anyyting-es/aniting/releases/latest` directly to retrieve semantic version tags (`vX.Y.Z`), changelog markdown, and attached `.apk` binaries.
  - **Dynamic Platform Version Resolution**: Added `"getAppVersion"` to `MainActivity.kt` MethodChannel so `AppUpdateService.getInstalledAppVersion()` dynamically queries Android's `packageManager.getPackageInfo().versionName`, eliminating hardcoded version desyncs between builds.
  - **Semantic Version Checking & Beta Tag Support**: `AppUpdateInfo.isVersionNewer` reliably parses `major.minor.patch`, pre-release suffixes (`-beta`, `-rc`), and build numbers, comparing versions across releases without breaking on pre-release strings.
  - **In-App Interactive Modal & Live Download**: `AppUpdateDialog` displays version tags, formatted release notes, and real-time linear download progress (`received / total` bytes and percentage).
  - **Native Android APK Installation**:
    - Configured `androidx.core.content.FileProvider` (`authorities="${applicationId}.fileprovider"`) with `@xml/file_paths` (`cache-path`, `external-cache-path`, `files-path`).
    - Handled `installApk`, `canRequestPackageInstalls`, and `openInstallPermissionSetting` in `MainActivity.kt` using `Intent(Intent.ACTION_VIEW)` with `application/vnd.android.package-archive` and `FLAG_GRANT_READ_URI_PERMISSION`.
    - Added `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />`.
- **Permanent Release Signing & In-App Auto-Update Integrity (`android/app/release.jks`, `android/app/build.gradle.kts`)**:
  - **Cryptographic Signature Stability**: Previously, `buildTypes.release` defaulted to `signingConfigs.getByName("debug")`, signing APKs with the local machine's ephemeral `~/.android/debug.keystore`. When `debug.keystore` was regenerated or built across different machines, Android Package Manager blocked in-app updates with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` ("No se instaló la app").
  - **Dedicated Release Keystore & Multi-Scheme Signatures (v1 + v2 + v3)**: Added a permanent, reproducible release keystore (`android/app/release.jks`) configured under `signingConfigs.create("release")` in `build.gradle.kts` and whitelisted in `.gitignore`. Explicitly enabled `isV1SigningEnabled = true` and `isV2SigningEnabled = true`, preventing OEM package installers (One UI, HyperOS/MIUI) from rejecting APKs with `INSTALL_PARSE_FAILED_NO_CERTIFICATES` ("App not installed as package appears to be invalid"). All APK builds produce identical cryptographic signatures (`SHA-256: 7e7960daf8...`), ensuring seamless in-app auto-updates for all users.
- **LAN Server Sharing & Zero-Config Auto-Discovery (`LanDiscoveryService`, `lan_sharing_provider.dart`, `ServerLanSharingCard`, `ServerDiscoveredListCard`)**:
  - **Zero-Config UDP Broadcast Protocol**: Implemented `LanDiscoveryService` (`lib/core/server/lan_discovery_service.dart`) utilizing UDP broadcast beacons on port `43212` (~120 bytes every 3 seconds). Broadcasts magic header `ANITING_SRV`, custom server display name, local Wi-Fi IP, API port, and core version. Stale servers are automatically evicted after 10 seconds of silence.
  - **Host Mode ("Compartir Servidor en Red")**:
    - Controlled by `lanSharingProvider` and `lanServerNameProvider` (`lib/core/preferences/lan_sharing_provider.dart`), persisted in `SharedPreferences`.
    - When enabled, `ServerManager.startLocalServer()` dynamically passes `host: '0.0.0.0'`.
    - Desktop: `DesktopServer` binds `--host 0.0.0.0` allowing connections across local subnets.
    - Android: `SeanimeServerRuntime.kt` dynamically patches `config.toml` (`host = '0.0.0.0'`) and accepts `extraHost` via `MethodChannel`.
    - Active broadcasting status displays real-time local Wi-Fi IP and port (`ServerLanSharingCard`).
  - **Client Mode ("Servidores en la Red" & TV Auto-Connect)**:
    - `discoveredServersProvider` automatically listens for LAN beacons.
    - `ServerDiscoveredListCard` displays discovered servers with real-time status badges, version info, and 1-click connect (`serverNotifier.checkConnection(host: ip, port: port)`).
    - Remote connection host and port are permanently persisted (`AppConstants.keyServerHost`, `AppConstants.keyServerPort`) in `SharedPreferences` so client devices (including Android TV) automatically re-connect to the LAN host on subsequent launches without manual IP entry.
- **Official Package ID & Namespace Migration (`com.anyyting.aniting`)**:
  - Replaced legacy `com.seanime.app.seanime_app` application ID and Gradle namespace with the official brand package name `com.anyyting.aniting` matching the GitHub organization (`anyyting-es/aniting`).
  - Refactored Kotlin sources into `android/app/src/main/kotlin/com/anyyting/aniting/`, updated MethodChannels (`com.anyyting.aniting/server`, `com.anyyting.aniting/exo_player`), and updated foreground notification branding to "Servidor Aniting".
- **Low-Memory & 3GB RAM Resilience Architecture (`AndroidManifest.xml`, `main.dart`, `video_player_screen.dart`)**:
  - Added `android:largeHeap="true"` to `<application>` in `AndroidManifest.xml` to allow the Dalvik/ART virtual machine to allocate up to 512MB heap on resource-constrained devices.
  - Added `WidgetsBindingObserver.didHaveMemoryPressure()` hook in `AnitingFlutterApp` (`lib/main.dart`) to immediately clear decoded in-memory bitmaps (`imageCache.clear()` and `imageCache.clearLiveImages()`) upon receiving OS low-memory trims.
  - Automatically flushes unrendered feed image bitmaps upon opening `video_player_screen.dart` (`initState`), dedicating 100% of RAM to ExoPlayer hardware decoder surfaces, torrent chunk streaming, and Media3 buffers.
- **Android Permissions Transparency & Clean Audit**:
  - Confirmed 0 intrusive permissions (no Camera, no Audio/Microphone, no Location, no Contacts).
  - Strict minimal set: `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `MANAGE_EXTERNAL_STORAGE`, `REQUEST_INSTALL_PACKAGES`.
- **Header Alignment between Feeds**:
  - `feed_screen.dart` and `manga_feed_screen.dart` share an identical vertical layout hierarchy:
    - Top spacer (`topPadding + 6`), `CompactSearchBar` (`Padding(horizontal: 16, vertical: 4)`), separator (`SizedBox(height: 8)`).
    - `_SectionHeader` uses a standardized `SizedBox(height: 36)` with `theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.2)`.
    - Guarantees zero vertical layout shift/jump when switching tabs between Anime and Manga.
- **Top Search Bars on Feeds (`CompactSearchBar`)**:
  - Located at the very top of both `feed_screen.dart` and `manga_feed_screen.dart` inside the `CustomScrollView`.
  - **Design Principles**:
    - **Compact & Discreet**: Low-profile height (~40dp) with comfortable horizontal padding.
    - **Semi-Transparent / Frosted**: Non-distracting, translucent background (`surfaceContainerHighest.withValues(alpha: 0.35)` or `Colors.white.withValues(alpha: 0.055)`), subtle outline (`outlineVariant.withValues(alpha: 0.22)`).
    - **No Loud Colors**: Neutral typography and monochrome icon (`Icons.search_rounded`).
    - **Responsive Width**: Bounded to `maxWidth: 540` on desktop to prevent awkward stretching across widescreen displays.
    - **Element Stability & Zero-Focus-Drop Pipeline**:
      - `CompactSearchBar` maintains a permanent 3-slot `Row` structure with explicit `ValueKey` identifiers (`compact_search_leading_slot`, `compact_search_expanded_slot`, `compact_search_trailing_slot`, and `compact_search_text_field`).
      - Leading and trailing `IconButton` widgets use non-traversable, non-requesting focus nodes (`canRequestFocus: false, skipTraversal: true`).
      - This prevents Flutter's `MultiChildRenderObjectElement.updateChildren` from unmounting the `TextField` or recreating `_TextFieldState` when toggling the back and clear buttons upon the first keystroke, eliminating on-screen keyboard dismissals and focus loss across mobile and desktop.
    - **In-Page Search (No Modal Sheet)**:
      - Tapping the search bar activates the text field without obscuring the background feed while query is empty.
      - As soon as the user types, the screen smoothly transitions in-place from the feed into a live debounced search view (~350ms) rendering a responsive grid of `AnimeCard` or `MangaCard` items.
      - When searching, the search bar displays a leading back button (`Icons.arrow_back_rounded` / Lucide arrow left) and trailing clear button (`Icons.close_rounded` / Lucide close).
      - Tapping the back button (or triggering Android back gesture via `PopScope`) clears the query and immediately restores the feed.
- **Explore Screen Architecture (`search_screen.dart`)**:
  - **Compact Eased Bottom Shadow & High-Contrast Typography**: The bottom shadow is compact (only ~115dp mobile / ~140dp desktop) and employs non-linear cubic easing stops (`[0.0, 0.22, 0.45, 0.68, 0.86, 1.0]`) to softly feather behind the title and metadata into `scaffoldBackgroundColor`, eliminating any harsh cuts, dark blocks, or banding lines. Full-screen horizontal vignettes and duplicate seam gradients were eliminated, keeping the upper ~60% of the artwork completely pure and vivid. The title and metadata (`Title`, `Year • Format • ★ Score • Genres`) are rendered in front on Layer 4 with crisp white typography and subtle drop shadows.
  - **Clean Inline Metadata (No Explorar Button)**: The top is completely unobstructed. The bottom displays clean inline typography with bullet dividers (`•`) and gold star score indicator.
  - **Tranquil Ambient Pan (Ken Burns)**: Wide banners pan smoothly and slowly across the screen (`_panAnimation`, 28s duration, `Curves.easeInOutSine`), providing peaceful, cinematic depth.
  - **In-Place Crossfade Dissolve & Infinite Forward Looping**: Slide transitions feature an in-place dissolve. Rather than sliding sideways like turning book pages, horizontal translation is completely neutralized (`counterOffset = pageOffset * width`) while opacity smoothly crossfades (`Curves.easeInOut`). When reaching the last element, the carousel loops seamlessly forward to the first item using virtual index modulo without any fast backward rewinding or flashing slides, both during automatic 7s auto-advance and manual gesture dragging.
  - **Controls Header Below Carousel**: The navigation controls (`MediaTypeToggle` on the left; Search, Filter with badge, Airing Calendar, Genres Hub on the right) sit cleanly **below** the carousel in Explore mode.
  - **Expandable In-Place Search**: Tapping the search icon smoothly hides the hero banner and activates search mode with `CompactSearchBar` and in-place debounced live results grid. Pressing back (or Android back gesture via `PopScope`) smoothly restores Explore mode.
  - **MediaTypeToggle (`media_type_toggle.dart`)**: Uses animated pill segments with `softWrap: false` and dedicated spacing, preventing any line-wrapping ("Anim\ne" / "Mang\na") on all screen sizes and languages.
- **Top Status Bar Gradient Protection (`TopStatusBarGlass`)**:
  - Provides subtle, lightweight gradient protection over the system status bar when the screen is scrolled down (`_isScrolled > 10px`), ensuring high readability of system status icons while content smoothly glides underneath.
  - **Zero GPU Overhead (No BackdropFilter / No ShaderMask)**: Completely eliminated expensive `BackdropFilter` Gaussian blur passes and `ShaderMask` offscreen saveLayers that previously forced GPU framebuffer readbacks on every single vertical scroll frame. Uses a high-contrast multi-stop solid gradient with zero GPU penalty.
- **Scroll Performance, Ticker Isolation & Zero-Jank Architecture (60–120 FPS Mobile Optimization)**:
  - **ValueNotifier Scroll State Isolation**:
    - Previously, crossing the 10px scroll threshold triggered `setState(() => _isScrolled = scrolled)` on the parent state, causing the entire 1,100+ line widget trees of `FeedScreen`, `MangaFeedScreen`, `SearchScreen`, and `LibraryScreen` to rebuild.
    - All screens now use `ValueNotifier<bool> _isScrolledNotifier` consumed locally by `ValueListenableBuilder<bool>`, completely isolating status bar animations from the scroll viewport.
    - Eliminated duplicate `NotificationListener` scroll handlers that were firing redundant `setState` calls alongside `ScrollController`.
  - **IndexedStack Ticker Isolation (`MainShell`)**:
    - Inactive tabs in `IndexedStack` are now wrapped in `TickerMode(enabled: _currentIndex == i)` and isolated with `RepaintBoundary`.
    - Offscreen animation controllers (such as the 28-second repeating Ken Burns loop in `ExploreHeroCarousel`, shimmer skeletons, and card tickers) are completely frozen when the user is on another tab, reclaiming 100% of inactive CPU/GPU cycles.
  - **Mobile Navigation Zero-Blur Dock (`MobileFloatingNav`, `MobileNavDock`)**:
    - Removed dual concurrent `BackdropFilter` layers from floating navigation capsules. At 90–95% surface opacity, background blur was visually imperceptible but imposed two full Gaussian blur passes per scroll frame.
  - **ServerStateModel Value Equality Contract (`app_providers.dart`)**:
    - Implemented `operator ==` and `hashCode` on `ServerStateModel`.
    - Eliminates catastrophic cascading rebuilds across all 11 SWR providers (`animeCollectionProvider`, `trendingAnimeProvider`, `continueWatchingProvider`, etc.) that previously occurred on identical state assignments due to Dart's default reference identity.
  - **Feed Memoization & SWR Layout Stability**:
    - `_getMixedList` and `_getSortedContinueWatching` memoize composite and sorted lists against reference identity, avoiding $O(N \log N)$ date/string parsing and list copying on every build frame.
    - In `_FeedLoadingSkeleton`, the large mock list structure is created once as a static `child` of `AnimatedBuilder`, animating a single `Opacity` wrapper rather than allocating hundreds of mock widgets and `ListView`s per frame.
  - **Static Card Placeholders (`AnimeCard`, `MangaCard`)**:
    - Replaced animated `CircularProgressIndicator` with static `ColoredBox` in `CachedNetworkImage` placeholders. Prevents dozens of concurrent 60/120fps animation tickers from churning CPU during image prefetching and scrolling.
  - **Background Isolate Cache Persistence (`FeedCacheService`)**:
    - Feed serialization (`jsonEncode`) is offloaded to background worker isolates via `compute(_encodeJson, ...)` in `saveAnimeList` and `saveMangaList`, preventing 50–120ms UI thread freezes during active feed navigation.
    - Synchronous getters return `UnmodifiableListView` to eliminate defensive list copying and reduce Garbage Collector allocation churn.
  - **Genres Hub Zero-Jank & Low-End Device Architecture (`genres_screen.dart`, `search_screen.dart`)**:
    - **TMDb Image Dimension Optimization (`w300` vs `w500`)**:
      - Genre backdrop URLs were upgraded from `w500` to standard TMDb backdrop thumbnail resolution `w300`.
      - Decreases network payload from ~1.8 MB to ~350 KB across the 18 genre cards (~4x smaller payload), cutting download times drastically on mobile data/Wi-Fi and reducing JPEG decode CPU latency on budget mobile processors.
    - **Route Transition Synchronization (`ModalRoute.of(context)?.animation`)**:
      - When opening `GenresScreen`, `SlideRightToLeftPageRoute` executes a 300ms slide-in animation.
      - Previously, `GridView.builder` with `cacheExtent: 600` immediately triggered 18 simultaneous network requests and bitmap decodes during the slide, completely starving the UI isolate and GPU rasterizer and causing severe jank / stuttering ("a tirones").
      - `GenresScreen` now defers image rendering until the route transition finishes (`AnimationStatus.completed` or fallback post-frame delay). During the slide, cards render instantly with zero latency using their native background colors, icons, and typography. Once settled, visible images fade in smoothly without dropping a single animation frame.
    - **Memory Cache Constraints & Bilinear Filter Quality**:
      - Constrained `CachedNetworkImage` with `memCacheWidth: isDesktop ? 360 : 260`, `memCacheHeight: isDesktop ? 220 : 160`, and `maxWidthDiskCache: 300 / maxHeightDiskCache: 200`.
      - Reduces uncompressed bitmap memory consumption by >60% (from ~436 KB down to ~160 KB per card in RAM), preventing GC allocation pauses and Out-Of-Memory spikes on low-RAM devices.
      - Configured `filterQuality: FilterQuality.low` (hardware-accelerated bilinear) to avoid costly multi-tap bicubic GPU filtering.
    - **Render Layer Isolation (`RepaintBoundary`) & Viewport Restraint**:
      - Wrapped each `_GenreCard` in a `RepaintBoundary`, preventing individual card image loads or fade-ins from triggering full-screen repaints of the `GridView` or scaffold.
      - Reduced `cacheExtent` from 600 to 100 on mobile (`300` on desktop), ensuring Flutter only mounts and loads the visible 6–8 viewport cards on initial presentation rather than instantiating the entire list at once.
    - **Background Pre-caching on Explore Hub Idle**:
      - When `SearchScreen` mounts, an idle `addPostFrameCallback` asynchronously precaches the top 6 genre thumbnails (`kAppGenres.take(6)`) in the background, ensuring the initial visible rows load with 0ms delay when the user taps into the Genres hub.
- **Desktop Floating Icon-Only Navigation Rail (`desktop_sidebar.dart`)**:
  - **Pure Floating Icons (No Enclosing Boxes)**: Eliminates wrapping box containers, background fills, borders, and text labels below icons, presenting pure icons floating effortlessly on the left side of the display.
  - **Clean, Matte Color States (No Glowing Halos / No Shadows)**:
    - **Hover / Focus**: Scales up smoothly (`scale: 1.15`, 140ms `Curves.easeOutCubic`) and brightens adaptively: solid `Colors.white` in dark mode, and high-contrast `theme.colorScheme.onSurface` in light mode (preventing icons from disappearing against light/white backgrounds).
    - **Selected Destination**: Crisp `colors.accent` with `item.selectedIcon`.
    - **Unselected**: Rendered in tranquil, matte `colors.textSecondary.withValues(alpha: 0.7)`.
  - **Icon Differentiation**:
    - **Perfil**: Uses `AppIcons.profile` (`user` / `person_rounded`) rather than star.
    - **Continuar sesión**: Uses `AppIcons.play` for anime and `AppIcons.bookmark` (marcapáginas) for manga to avoid repeating the book icon from the Manga tab.
  - **System Navigation Inset Extension**: Automatically queries `MediaQuery.of(context).viewPadding.bottom` and adds it to the bottom padding (`24 + bottomInset`), ensuring the sidebar canvas extends fully behind the system gesture navigation bar on Android foldables, tablets, and convertibles with zero bottom gaps.
  - **Desktop Tooltips**: Hovering any destination (Search, Home, Manga, Profile, Continue Watching/Reading, Settings) displays a standard desktop `Tooltip` after 400ms for instant identification without visual clutter.
  - **Full Keyboard / DPAD Support**: Full focus traversal and activation handling (`Enter`, `Select`, `Space`, gamepad `A`).
- **Mobile Anime Detail Architecture & Minimalist Inline Action Hub (`anime_detail_mobile_layout.dart`, `AnimeDetailModePopup`, `AnimeDetailSourcePopup`, `AnimeDetailAdvancedSheet`)**:
  - **Compact Primary Play Button ("Primerito")**:
    - Prominent primary action button (`FilledButton.icon`, height 41dp, `BorderRadius.circular(22)`, `Icons.play_arrow_rounded` size 21) placed directly beneath the header metadata.
    - Dynamic label (`▶ Continuar Ep. X`, `▶ Comenzar a ver`, or `↺ Ver de nuevo` upon completion).
    - Tapping launches immediate playback without requiring extra navigation.
  - **Dynamic Next Airing Episode Badge**:
    - Removed redundant static tags like `FINALIZADO` / `EN EMISIÓN` next to the poster. When an anime is currently airing and has schedule data, dynamically displays a gentle badge (e.g. `Ep. 5 pronto`).
  - **Minimalist Dropdown Chips Row**:
    - Located directly below the play button in a horizontal scrollable row:
      1. **Mode Dropdown Chip**: Displays active mode (`🌐 Online ▾`, `⚡ Torrent ▾`, or `📁 Local ▾`). Tapping opens `AnimeDetailModePopup` with a bouncy spring animation (`Curves.easeOutBack`).
      2. **Provider & Audio Dropdown Chip** (Online mode): Shows active provider and audio tag (`AnimeFlv • SUB ▾` / `DUB`). Tapping opens `AnimeDetailSourcePopup`.
      3. **AniList Status Chip**: Displays watch status and progress (`🔖 Viendo • Ep. 4/12`). Tapping opens the edit modal.
    - **Zero Default Clutter**: Eliminates bulky mid-screen tab bars and intrusive dropdown containers; all controls are compact and open on demand.
  - **Bouncy Spring Expressive Popups (`AnimeDetailModePopup`, `AnimeDetailSourcePopup`)**:
    - Opens with a lively bounce/spring transition using `Curves.easeOutBack` (scale 0.75 -> 1.0).
    - **Mode Popup (`AnimeDetailModePopup`)**: Fast 1-tap switching between Streaming Online, Torrents, and Local Media.
    - **Sources Popup (`AnimeDetailSourcePopup`)**: Displays ONLY available providers with clear radio selection without distracting controls.
    - **Advanced Options Sheet (`AnimeDetailAdvancedSheet`)**: Accessible via the "Opciones avanzadas" button at the bottom of the source popup. Hosts Sub/Dub audio toggle pills, manual linking (`Vincular`), cache refresh (`Recargar`), and extension marketplace navigation.
  - **Unobstructed Episode List & Natural Scroll**:
    - Completely eliminates bottom floating docks so episodes and pagination controls flow cleanly and unobstructed from top to bottom with standard bottom inset padding (`bottomPadding + 24`).
  - **Banner Blur Containment & Stationary Gradient Architecture (`anime_detail_mobile_layout.dart`, `manga_detail_mobile_layout.dart`, `desktop_hero_banner.dart`)**:
    - **Zero-Bleed Blur Clipping**: `ImageFiltered(imageFilter: ImageFilter.blur(...), child: Transform.scale(scale: 1.25, ...))` is strictly wrapped inside an internal `ClipRect`, preventing the 1.25x scaled blurred image from spilling beyond the 345px banner box bounds.
    - **Stationary Multi-Stop Gradient Anchor**: The bottom gradient into `scaffoldBackgroundColor` is decoupled from the parallax translation so it remains permanently anchored to the bottom of the banner viewport, guaranteeing the solid theme background never pulls upward or leaves unmasked color gaps during scroll.
    - **Scroll-Driven Darkening**: Added a smooth scroll-driven darkening overlay (`theme.scaffoldBackgroundColor.withValues(alpha: (scrollOffset / 200.0).clamp(0.0, 1.0))`), dissolving the banner seamlessly into the theme background as foreground content scrolls over it.
- **SliverGrid Zero-Width Viewport Protection (`feed_screen.dart`, `manga_feed_screen.dart`)**:
  - Wrapped `SliverGrid.builder` elements inside `SliverLayoutBuilder`. When initial window frames (e.g. Linux GTK, Windows launch before mapping) or tiled layouts supply `constraints.crossAxisExtent <= 32.0`, it returns an empty `SliverToBoxAdapter` rather than triggering Flutter's `assert(constraints.crossAxisExtent > 0.0)` layout assertion crash.
- **Card Typography & Japanese Fallback Font Pipeline (`theme_provider.dart`, `AnimeCard`, `MangaCard`)**:
  - **Global CJK Fallback Integration**: `kJapaneseFontFallbacks` (`Noto Sans JP`, `Noto Sans CJK JP`, `Hiragino Sans`, `Hiragino Kaku Gothic ProN`, `Yu Gothic`, `Meiryo`, `sans-serif`) is bound to `ThemeData.fontFamilyFallback` and `textTheme.apply(fontFamilyFallback: ...)`.
  - **Elimination of Faint / Hairline Japanese Glyphs**: Guarantees that Japanese Kanji, Hiragana, and Katakana glyphs render at bold `FontWeight.w700` with full stroke thickness rather than falling back to hairline or light weights.
  - **High-Contrast Dark Ink in Light Themes**: On light themes (`Brightness.light`), card titles are rendered with deep high-contrast ink (`const Color(0xFF111418)`), eliminating washed-out or opaque Japanese text on cream/light palettes (such as Solarized Light, Tokyo Day, Catppuccin Latte).
- **Profile / Library Screen Unboxed Architecture (`library_screen.dart`)**:
  - **Unboxed & Minimalist Aesthetic**: Completely eliminates enclosed container boxes/cards with heavy borders. The user profile header, navigation items ("Mis Listas", "Descargas de Anime", "Descargas de Manga", "Extensiones", "Configuración"), and quick settings render cleanly and openly without artificial container boxes.
  - **Quick Marketplace Shortcut**: Includes a direct "Extensiones" tile in "Mi Colección" pointing straight to `ExtensionsMarketplaceScreen()`, providing immediate one-tap access to installed and community extensions without having to navigate into Settings.
  - **Title-Only Layout (No Subtitle Clutter)**: Redundant descriptions/subtitles were removed, displaying clean, legible titles.
  - **No Trailing Chevrons**: Eliminates unnecessary arrow indicators (`chevron_right_rounded`) across all profile navigation tiles and settings items for a cleaner, cleaner look.
  - **Widescreen Constraint**: Constrains scrollable content to a responsive `maxWidth: 820` centered with `Align(alignment: Alignment.topCenter)` on widescreen / desktop displays to prevent stretching while maintaining full mobile responsiveness.
- **Settings Screen Unboxed Architecture (`settings_screen.dart`, `pixel_settings_widgets.dart`)**:
  - Unboxed, open section layout replacing boxed card containers (`PixelContainerCard` removed in favor of direct transparent flow).
  - Clear section headers (`theme.textTheme.titleSmall` with `colorScheme.primary`).
  - Items display concise titles and controls without unnecessary subtitle descriptions.
- **Desktop Anime Detail Architecture (`AnimeDetailDesktopLayout`, `DesktopEpisodesTab`)**:
  - **Sequential Full-Width Vertical Flow Architecture**:
    - **Top Metadata Section**: Displays the anime poster and metadata at the top: Left column contains `DesktopSidebar` (clean cover poster with smooth hover scale); Right column contains `DesktopHeader` (season/year kicker, title, clean floating metadata row with format, live status dot, episode count, duration, studio, and score badge separated by subtle bullets `•` without rigid cube boxes, soft genre pills, and synopsis constrained to `maxWidth: 820` for comfortable reading).
    - **Action Bar Across Content Width (`DesktopActionBar`)**: Located directly below the poster and header row across the full content width, featuring floating pill play button, circular bookmark, share, trailer, external AniList/MAL icons, and the Online/Torrent `GlassSegmentedControl` switch (Local toggle removed from the action bar since downloaded episodes natively display their `LOCAL` badge and stream from disk directly).
    - **Full-Width Episodes Section (`DesktopEpisodesTab`)**: Positioned cleanly below the action bar without a redundant section title header. Episode cards are notably enlarged with wider 16:9 thumbnails (`crossAxisCount = clamp(2, 5)` in grid mode, 2-column layout in list mode with 240px thumbnails), providing comfortable, cinematic viewing.
    - **Sequential Relations Section (`DesktopRelationsTab`)**: Positioned directly underneath the episodes section, showing relations with responsive card grid and poster covers.
    - **Sequential Recommendations Section ("Te podría gustar", `DesktopRecommendationsTab`)**: Positioned directly underneath relations, displaying personalized and community recommendations.
    - **Sequential Characters Section (`DesktopCharactersTab`)**: Positioned cleanly at the bottom, presenting character portraits, names, and roles.
  - **Liquid Glass (`GlassCard`) Action Bar, Floating Navigation Dock & Modals**:
    - `DesktopActionBar` buttons (`_HoverPlayButton`, `_HoverIconButton`, `_HoverBrandIcon`) utilize circular `GlassCard` and floating shapes with specular borders, responsive hover depth, and translucent theme tinting without heavy square boxes.
    - `FloatingDockPill` and `FloatingResumeCompanion` in `MobileFloatingNav` (Android floating navigation dock) are wrapped with `DecoratedBox` elevation shadows, `ClipRRect`, native 18.0 sigma `BackdropFilter` Gaussian blur, and `GlassCard`, featuring specular borders (`alpha: 0.20` dark / `alpha: 0.45` light) and rich translucent theme tinting (`alpha: 0.35` dark / `0.48` light). This ensures posters and content scrolling underneath remain vividly blurred and unmistakable, with zero-cost fallback to solid `surfaceContainer` when glass effects are disabled in settings.
    - `EditEntryModal`, `AnimeDetailModePopup`, and `AnimeDetailSourcePopup` utilize `GlassCard` with specular borders, soft shadow, and frosted backdrop blur. In light mode, modal dialogs and control fields (`EditEntryStatusDropdown`, `EditEntryScoreSlider`, `EditEntryStepper`, `EditEntryDatePicker`) feature crisp pure white surfaces with subtle shadows and clean borders, eliminating dull "plomo" grey tones and removing fluorescent glowing halos.
  - **Desktop Header Typographic Hierarchy & Metadata Zoom (`DesktopHeader`, `AnimeDetailDesktopLayout`)**:
    - Generous typography and balanced metadata hierarchy inspired by reference designs:
      - **Main Title**: 32px bold (`FontWeight.w900`) commanding header presence.
      - **Subtitle**: 16px medium (`FontWeight.w500`) secondary title (Romaji / English / Native).
      - **Metadata Row 1 (15.5–16.5px)**: Format (`TV`, `Movie`), progress/episodes counter (`4/12` bold or `12 Eps`), interactive clean status pill (`[Watching]` / `[Viendo]` with pencil icon and no neon glow), vertical divider `|`, and airing season with calendar icon (`Jul 2026 - Summer`).
      - **Metadata Row 2 (15px)**: Score with neutral heart outline (`♡ 8.4`, no yellow neon background/text), studio in bold, and plain text genres separated by whitespace without boxy cyan containers.
  - **Downward-Opening Provider Menu & Streamlined Episode Toolbar (`DesktopEpisodesTab`)**:
    - Provider selector popup explicitly opens **downwards** anchored below the trigger button (`offset.dy + size.height + 6`), adapting dynamically to light mode (crisp pure white, clean outline, subtle shadow) and dark mode (sleek `#1E2228` surface).
    - Removed redundant "Episodes" counter header above episode cards per UI design, maximizing vertical breathing room.
  - **Source-Specific Episode Engine**:
    - **Torrent Mode (`AnimeDetailTab.torrent`)**: Always loads 100% of the official AniList / AniZip episode list (`aniZipEps`, `fallbackEps`, or `totalEpisodes`), ensuring complete fidelity with release schedules and metadata.
    - **Online Streaming Mode (`AnimeDetailTab.online`)**: Dynamically queries the selected extension/source provider (`getOnlinestreamEpisodes`). When changing providers in the dropdown or toggling between Subbed and Dubbed audio, `DesktopEpisodesTab` re-fetches and renders the exact episode list from the active provider with an inline loading state and empty fallback.
    - **Real Canon Episodes Engine ("Solo EP Reales")**: In both Torrent and AniZip sources, filters out extra specials, openings, endings (`ncop`/`nced`), previews, teasers, and recaps (`isRealMainEpisode`). Enforces episode deduplication by number (`seenTorrent`, `seenOnline`) and bounds to `totalEpisodes`, eliminating duplicate cards and spin-off shorts ("Oni and Momo Too") between canon episodes. Harmonized with mobile by applying `hasEpisodeAired` (filtering out unreleased future TV stubs with future `airDate` / `nextAiringEpisode` unless downloaded locally on disk).
  - **Dimmed Watched Episodes ("Sin icono de visto")**:
    - Completely eliminates checkmark badges/icons on episode cards.
    - Watched episodes are styled with subdued opacity (`0.45` rest, elevating to `0.75` on hover) via `AnimatedOpacity`, providing instant, non-intrusive visual distinction between watched and unwatched episodes.
  - **High-Performance 20-Episode Pagination**:
    - Limits rendering to a maximum of 20 episodes per page (`_episodesPerPage = 20`) across both Grid and 2-Column List modes.
  - **Desktop Anime Detail Hover & Micro-interactions (`DesktopGridEpisodeCard`, `DesktopListEpisodeCard`, `DesktopCharactersTab`, `DesktopRelationsTab`, `DesktopRecommendationsTab`)**:
    - **Snappy Inner Image Hover**: Removed whole-card scaling and jarring shadow hops. Cards retain stable dimensions while only the inner thumbnail/poster image quickly scales (`1.0 -> 1.06`, 140ms `Curves.easeOutCubic` on enter, 100ms `Curves.easeInQuad` on exit), creating an ultra-responsive, crisp micro-interaction.
    - **Elimination of Hover Play Icon**: Removed the artificial floating play button overlay on episode thumbnails.
    - **Clean Tab Headers & Minimalist Controls**: Converted hardcoded dark boxes in `DesktopEpisodesTab` (EP counter, provider dropdown, grid/list view toggles, ascending/descending) and `DesktopActionBar` (Online/Torrent pill switch) into sleek typography labels, translucent theme-aware pills, and native compact icon buttons with subtle hover feedback.
  - **D-Pad Focus vs Mouse Hover Border Architecture (`AnimeCard`, `MangaCard`, `ContinueWatchingCard`, `ContinueReadingCard`, `FocusCard`)**:
    - Disentangled `_isHovered` from `_isFocused`. The thick 2px white outline frame is strictly reserved for D-Pad / keyboard navigation (`_isFocused`), ensuring that mouse cursor hovering does not produce jarring white border flashes across any card in the application.

- **Desktop Manga Detail Architecture (`MangaDetailDesktopLayout`, `DesktopMangaChaptersTab`)**:
  - **Modular Dual-Column Layout (1580px max-width)**:
    - **Left Sidebar (`DesktopMangaSidebar`)**: Large high-res cover poster (240x350px), format, status, release year, score, total chapters and volumes, plus read progress card with AniList modal trigger.
    - **Right Column (`DesktopMangaHeader`, `DesktopMangaActionBar`)**: Language-preference title, cyan/accent genres pills, expandable synopsis, big "Continuar Leyendo • Cap. X" pill button, bookmark button, batch download button, and external AniList / MAL links.
  - **4-Tab Navigation**:
    - **Capítulos**: Integrated chapter management with extension provider dropdown, live search ("Buscar o N° de cap..."), ascending/descending toggle, quick reload button, filter chips ("Ocultar leídos", "Solo descargados", "Descargar lote"), 30-chapter block pagination bar, and responsive multi-column slim minimalist chapter strips (44px height, single-line title and scanlator, download action, and dimmed read state without bulky boxes).
    - **Personajes**: Characters grid (`DesktopCharactersTab`) with character portraits, names, and roles.
    - **Relaciones**: Relations grid (`DesktopRelationsTab`) with smart bidirectional routing: navigates to `MangaDetailScreen` when the relation is Manga, or `AnimeDetailScreen` when Anime.
    - **Obras similares**: Community recommendations grid (`DesktopRecommendationsTab`).
  - **Dimmed Read Chapters**:
    - Chapters already read are subdued (`opacity: 0.45`), smoothly brightening to `0.85` on hover.
  - **Dynamic Cover Color Theming**:
    - When `themeSettings.animeDynamicTheme` is active, extracts `coverColor` from AniList manga metadata to dynamically tint the scaffold background and color scheme.

- **Solid Material Design 3 Floating Navigation Dock & 2-Phase Zero-Overlap Resume Companion (`MobileFloatingNav`, `FloatingDockPill`, `FloatingResumeCompanion`)**:
  - **Zero Transparency / Solid M3 Aesthetic**:
    - Completely eliminates all glassmorphism, blur, and opacity washes in the floating dock and resume companion.
    - Uses 100% opaque `theme.colorScheme.surfaceContainer` with crisp outline border (`outlineVariant`) and Material 3 elevation shadow.
  - **Selected Pill with Text to the Right & Fluid Pill Animation (`FloatingDockPill`)**:
    - **Contracted Intrinsic Width & Zero Dead Space**: Dock tightly hugs its navigation destinations without stretching across the viewport or creating awkward empty margins beside the outer icons. In standalone and expanded modes, the pill width is calculated intrinsically (`FloatingDockPill.calculateWidth`) and bottom-centered with uniform 8dp padding surrounding the lateral buttons.
    - **Proportions & Ergonomics**: Compact height (`68.0dp`) with capsule border radius (`34.0dp`). Navigation elements are generously sized to eliminate excessive dead white space: larger icons (26.5dp), prominent button targets (50dp height, 52dp base width), and crisp typography (14.5sp `FontWeight.w600`).
    - **Fluid Animated Pill Expansion**: Tapping a destination smoothly expands its width (`TweenAnimationBuilder`, 280ms, `Curves.easeOutCubic`) while gracefully pushing neighboring icons outward; deselecting smoothly contracts back to a compact button.
    - **Standalone / Expanded Mode**: Unselected items display clean monochrome icons only. The selected item expands into an active pill (`theme.colorScheme.secondaryContainer`) revealing `[Icon]  [Label]` with text deployed to the right of the icon.
    - **Collapsed Companion Mode (Sharing Bottom Row)**: When the resume companion sits in the bottom row beside the dock, the dock contracts and all destinations switch to **icon-only mode** with an active pill indicator (`[Icon]`), preventing text deployment and layout crowding. Both the dock and the 68x68 companion are centered together as a compact pair.
  - **Resume Companion Card Architecture (`FloatingResumeCompanion`)**:
    - **Coordinated Dimensions**: Height: 68dp with 34dp capsule radius. Poster thumbnail: 40x52dp (`borderRadius: 9dp`). Typography: bold 13.8sp main title and 11.5sp subTitle. Action button: 42x42dp circular target with 24dp play icon.
    - **Cover Poster Only**: Exclusively displays the anime or manga cover poster (`coverImage`), omitting character art.
    - **Title Hierarchy**:
      - Top line (bold 13.8sp): Episode title/number for anime; Manga title for manga.
      - Bottom line (11.5sp `onSurfaceVariant`): Anime series title for anime; Chapter info for manga.
    - **Full-Width Bottom Progress Bar**: Spans 100% of the card width along the bottom edge with `LinearProgressIndicator` (height: 3dp).
    - **Distinctive Play Action Button**: Prominent circular play action button (`primaryContainer` / `onPrimaryContainer`) on the far right edge clearly indicating continuation.
  - **2-Phase Staged Zero-Overlap Trajectory**:
    - Completely eliminates trajectory overlap where the card previously flew or rendered over the navigation dock.
    - **Phase 1 (Horizontal Shrink/Expand, value 0.5 to 1.0)**:
      - When scrolling down, the resume card first shrinks horizontally into a compact 68x68 square on the right side while remaining parked above the dock (`bottom: _kDockHeight + _kVerticalGap`).
      - Simultaneously, the dock contracts its width and smoothly hides the selected label to enter icon-only mode.
    - **Phase 2 (Vertical Drop/Rise, value 0.0 to 0.5)**:
      - The compact 68x68 square glides vertically straight down into the empty column beside the dock without ever crossing or passing over any pixel of the dock.
      - When scrolling up, it rises vertically in that slot before expanding horizontally across the top.
    - **Gestures**: Tap resumes playback (`FloatingResumeBar.resumePlayback`); swipe down clears the session with haptic feedback.
  - **Fast-Path Local PC Resume & Revived Torrent Stream Architecture (`FloatingResumeBar`, `DesktopSidebar`, `MobileFloatingNav`, `AnimeDetailDesktopLayout`, `AnimeDetailTvLayout`)**:
    - **Local PC Library 0ms Fast-Path**: When resuming playback via the floating resume bar or tapping the primary "Reproducir Siguiente" button, the app queries Seanime's local library first (`repo.getAnimeLibraryEntry(mediaId)`). If a matching episode is found on the local PC disk (`localFilePath`), playback launches instantly at 0ms via `mediastream/file?path=...` (`isLocalFile: true`), bypassing online scrapers, network lag, and torrent start overhead.
    - **Torrent Stream Reactivation (Elimination of Infinite "Cargando Torrent" Freeze)**: Previously, exiting a video player terminated the Go server's torrent stream (`stopTorrentStream`), leaving the URL in `LastSessionItem` dead. Clicking resume attempted to load the inactive `/api/v1/torrentstream/stream/video.mkv`, leading to an infinite buffering spinner and stalled "Torrent..." top bar. `FloatingResumeBar.resumePlayback` now calls `repo.startTorrentStream(mediaId, epNum, autoSelect: true)` with an attached `onDispose` cleanup callback to revive the torrent stream before launching `VideoPlayerScreen`. If the stream cannot be auto-selected, it safely routes the user to `AnimeDetailScreen` to pick a torrent source rather than freezing.

### 4.2. Video Player Architecture
Inspired by **Plezy** (`edde746/plezy`), the player focuses on high performance, clean UX, and non-cluttered controls:
- **Clean Viewport**: No oversized buttons in the center of the video screen. Center is reserved for playback and buffering/seek toasts.
- **Dynamic Icon Pack Theming (`iconPackProvider` & `AppIcons`)**:
  - The video player subsystem (`PlayerTopBar`, `PlayerBottomBar`, `VolumeSlider`, `PlayerGestureOverlay`, `SeekFeedbackToast`, `PerformanceStatsOverlay`, `PlayerInfoPanel`, and all `PlayerSettingsSheet` sub-views: chapters, audio/subtitle tracks, sync offset, speed, shaders, fit modes, torrent metrics) uses `AppIcons` and dynamically updates when switching between **Lucide** and **Material** icon packs in real time.
- **Theme Consistency**: No hardcoded colors. Sliders and controls use `Theme.of(context).colorScheme.primary` or Material 3 container colors.
- **Top Bar**: Minimalist layout: Back button, Anime Title, Episode Title, and unified settings gear.
  - **Harmonized Icon Sizing (`PlayerTopBar`)**: Top bar action icons are optically calibrated to match the controls row with balanced breathing room:
    - **Material (Desktop)**: `back` (`arrow_back_rounded`): 30dp, `settings` (`settings_rounded`): 29dp, `sidebar` (`view_sidebar_rounded`): 28dp.
    - **Lucide (Desktop)**: `back`: 26dp, `settings`: 25dp, `sidebar`: 24dp.
    - **Balanced Spacing**: Uses `SizedBox(width: 8)` between the sidebar toggle and settings gear, and `SizedBox(width: 10)` after the back button, preventing upper controls from crowding together.
  - **Centered Torrent Metrics Overlay (`PlayerTopBar`)**: Layered via a 2-layer `Stack`. Right-hand buttons (side panel toggle and settings button) remain strictly pinned to the far right, while torrent download metrics (download speed, seeders, progress percentage, ETA) sit independently in the horizontal center of the top bar without shifting or moving the settings button. Uses standard clean typography (`fontSize: 12, fontWeight: FontWeight.w600`) without monospace distraction.
  - **Fullscreen Margin & Cutout Neutralization**: `SafeArea` in `PlayerTopBar` and `PlayerBottomBar` explicitly sets `left: false, right: false`. On Android phones in landscape mode, this prevents Flutter from injecting redundant 60-90dp display cutout padding into the left of the timeline slider, play button, and back icon, allowing controls to naturally and cleanly span across the screen width.
- **Bottom Bar & Volume Control**:
  - **Enlarged Timeline Seek Bar (`TimelineSlider`)**:
    - **6dp Track Height ("Un pelín más ancha")**: Seek track height scaled from 4dp to 6dp with matching 6dp buffer indicator and 7dp thumb radius.
    - **Solid Black Background Track**: Includes a base black background track container (`color: Colors.black.withValues(alpha: 0.75)`, `borderRadius: BorderRadius.circular(3)`) and `inactiveTrackColor: Colors.black.withValues(alpha: 0.6)`, replacing the faint white background for clear contrast against bright or dark video scenes.
    - **Visual MKV Chapter Ticks**: Sized at 2.5px width and 8px height with deep black color (`alpha: 0.9`), notching 1dp beyond the 6dp track for clear chapter boundaries.
  - **Controls Row & Unified Icon Sizing**:
    - **Streamlined Minimalist Controls (No Redundant ±10s Buttons)**: Eliminates redundant onscreen ±10s seek buttons in favor of natural native interactions (double-tap seek gestures on mobile, arrow keys on desktop/keyboard, and DPAD on TV). Leaves a clean, focused control row: `[Play/Pause]`, `[Next Episode]` (if available), `[Volume]`, `[Timestamp]`, `[Chapter Label]`, and `[Fullscreen]`.
    - **Optical Sizing Compensation & Desktop Calibration (Material vs Lucide)**: Because Material icons have substantial internal glyph padding (particularly `Icons.skip_next_rounded` which only spans ~12dp vertically in a 24dp viewBox), optical scaling is applied per icon pack while preserving relative dimension differences:
      - **Desktop Dimensions (Material)**: Calibrated at a balanced, non-cramped sweet spot:
        - `play` / `pause`: 32dp.
        - `skipNext`: 34dp (+2dp delta preserved relative to play/pause).
        - `fullscreen`: 32dp (equal to play/pause).
        - `volume`: 28dp (-4dp delta preserved relative to play/pause).
      - **Desktop Dimensions (Lucide)**: Proportional scaling: `play`: 28dp, `skipNext`: 26dp, `fullscreen`: 27dp, `volume`: 23dp.
      - **Mobile Standard Dimensions**: `play`/`fullscreen`: 28dp (Material) / 26dp (Lucide), `skipNext`: 30dp (Material) / 24dp (Lucide), `volume`: 24dp (Material) / 22dp (Lucide).
    - **Increased Button Separation**: Dedicated horizontal spacing (`4dp` between play and next, `6dp` before volume, `10dp` before timestamp) avoids cramped controls.
    - **Zero-Displacement Compact Padding (`padding: EdgeInsets.all(2)`)**: Button padding is trimmed to 2dp with `MaterialTapTargetSize.shrinkWrap`, allowing icons to comfortably fill the 36x36 touch bounding boxes without increasing row height or shifting the timeline seek bar upward.
    - **Uniform Bright White Colors**: All controls use solid `Colors.white`, unifying visual hierarchy.
  - **Desktop Volume Control (`VolumeSlider`)**: Hovering over the volume button (or scrolling with the mouse wheel) smoothly unfolds a compact **Material 3 Expressive vertical capsule recuadro** (width: 42dp, height: ~170dp) anchored at `Alignment.bottomCenter`.
    - **Thumb-Free Continuous Capsule ("Sin palito")**: `M3ExpressiveVerticalSlider` supports `showThumb: false`, rendering a seamless, elegant filled capsule track where active color fills from the bottom up to the current level without any divider bar or gap.
    - **Large Clean Volume Readout**: Displays the raw volume number without `%` suffix (e.g. `100`, `50`) with larger, bolder typography (13sp w700) for instant legibility without clutter.
    - **Hover & Interaction Lock (`onHoverChanged` / `_isInteractingWithVolume`)**: `VolumeSlider` communicates with `PlayerBottomBar`, `PlayerViewport`, and `video_player_screen.dart` via `onHoverChanged(bool)`. While hovering or actively dragging (`onChangeStart`/`onChangeEnd`), `_isInteractingWithVolume` inhibits the auto-hide timer (`_startHideTimer`) and ignores player viewport exit events (`_onMouseExit`). This prevents the player controls from flickering or disappearing when interacting with the `OverlayPortal` layer. Includes a 300ms exit grace period, continuous hover tracking (`onHover`), and mouse wheel scroll deduplication between the anchor button and the popover.
  - **Mobile Controls Optimization**: Hides the redundant on-screen volume button on mobile devices (`if (_isDesktop)`), freeing up bottom bar space for chapter titles and timestamps while relying on physical volume keys and edge gesture swipes. The "Next Episode" button is placed directly adjacent to Play/Pause when a next episode exists, or leaves only Play/Pause when none exists.
- **Desktop Fullscreen**:
  - Uses native window manager fullscreen via `defaultEnterNativeFullscreen()` and `defaultExitNativeFullscreen()` from `media_kit_video`.
- **Linux Video Playback Smoothness & Non-Blocking Lifecycle (`video_output.cc`, `mpv_player_service.dart`)**:
  - **Non-Blocking Background Disposal**: In `packages/media_kit_video/linux/video_output.cc`, `video_output_dispose` unregisters the texture on the main GTK thread and delegates heavy context teardown (`mpv_render_context_free` and `eglDestroyContext`) to a detached background worker thread (`std::thread(...).detach()`). This eliminates the previous ~1-second synchronous GTK UI freeze when popping the player route, matching Windows performance with silky-smooth 120 FPS pop transitions.
  - **Prioritized HWDEC Sequence**: On Linux, `hwdec` defaults to `'vaapi,vaapi-copy,nvdec,nvdec-copy,auto-safe'` across `VideoControllerConfiguration` and `MpvPlayerService`. This prevents libmpv on modern Linux / Wayland systems from probing unsupported Vulkan (`VK_KHR_video_decode_queue`) and CUDA extensions that previously triggered repetitive timeout stalls and a ~1-second enter freeze.
  - **Dedicated Linux Audio Sync**: Uses `video-sync: 'audio'` on GNU/Linux with EGL texture sharing to prevent the compositor frame drops and audio resampler stalls associated with `display-resample`.
- **Direct Zero-Copy Hardware Acceleration & RAM Optimization (`MpvPlayerService`)**:
  - Uses direct `d3d11va` (Windows) and `vaapi`/`nvdec` (Linux) instead of copyback modes (`d3d11va-copy`). Keeps 10-bit HEVC (p010) decoded surfaces directly in GPU VRAM, preventing hundreds of megabytes of frame buffers from copying back into host system RAM.
  - Tuned demuxer RAM cache (`demuxer-max-bytes: 32MB`, `demuxer-max-back-bytes: 10MB`, `demuxer-readahead-secs: 15s`, `bufferSize: 16MB`) and Flutter `imageCache` (`50MB` / `250` entries) to stabilize working set memory.
- **Adaptive Online Streaming Engine (`isOnlineStream` in `MpvPlayerService`)**:
  - Dynamically detects and tunes `libmpv` when opening remote HLS / m3u8 streams vs local / torrent files:
    - **Ultra-Fast Probing**: Reduces `demuxer-lavf-probesize` from 5MB to 64KB (`65536`) and `demuxer-lavf-analyzeduration` from 5.0s to `0.5s`, starting video playback within ~100ms instead of waiting seconds.
    - **HTTP Keep-Alive / Persistent Connections**: Sets `stream-lavf-o` with `multiple_requests=1,http_persistent=1,reconnect=1` so HLS `.ts` / `.m4s` segments reuse the open HTTPS socket without incurring repeated TCP + TLS 1.3 handshakes for every 2-second chunk.
    - **Lag-Free Seeking (`hr-seek: no`)**: Uses keyframe-direct seeking for online streams to eliminate multi-second network freezes during ±10s seeking, while preserving frame-accurate `hr-seek: yes` for local high-fidelity files.
    - **CDN SSL Resilience**: Disables `tls-verify` to prevent connection stalls on anime CDNs with non-standard SSL certificate chains.
- **Native libass Subtitles & Multi-Track Audio/Subs**:
  - **Android (ExoPlayer + libass)**:
    - Powered by native `libass-android` bridge via `AssSubtitleSurfaceView` and `AssHandler`.
    - **Header Normalization & Format Alignment (`AssHeaderParser.kt`)**: Matroska CodecPrivate subtitle headers are normalized to strip malformed/missing `[Events]` sections and enforce canonical column ordering (`Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text`). This resolves `Bad timestamp` and `Warning: no style named '0' found, using 'Default'` errors by ensuring libass's `ass_process_chunk` token skips align with the author's ASS styles.
    - **Accurate Dialogue Duration (`AssTrackOutput.kt`)**: Fixes duration calculation by evaluating `(endTimeUs - timeUs) / 1000` from Media3 subtitle sample tokens (with a 5000ms safety fallback) rather than passing raw end timestamps as durations.
    - **Precise Track Selection (`AssHandler.kt`)**: Fixes `getSelectedAssTrack` to inspect all formats across track groups and return the exact matching SSA track format rather than forcing index `0`.
    - **Zero Duplicate Text Cues (`ExoPlayerPlugin.kt`)**: Tracks whether the active subtitle track is ASS (`isCurrentSubAss`). When ASS is active, plain text cues from Media3 are suppressed from both native `standardSubtitleView` and Flutter's overlay, ensuring only the styled, positioned `AssSubtitleSurfaceView` renders without ugly plain-text duplication.
    - **Mobile Zero-Jump & Orientation Transition Pipeline (`ExoPlayerPlugin.kt`, `video_player_screen.dart`)**:
      - **Elimination of Initial Center Glitch & Initial Black Screen ("Video en negro al entrar")**:
        - Previously, `ExoPlayerPlugin` initialized its native `surfaceContainer` as full screen (`MATCH_PARENT, MATCH_PARENT`). In portrait mode, this centered the 16:9 video in the dead center of the vertical screen, jumping up to the top a frame later once Flutter's `addPostFrameCallback` sent `setSurfaceBounds`.
        - When passing `initialTop` and `initialHeight` directly to `exo.initialize(top, height)`, a subsequent call to `openMedia` invoked `ensureInitialized()` with default arguments (`top: 0, height: -1`). In `ensureInitialized()`, an improper check `(initialTop == 0 && initialHeight == -1)` reset the container back to `MATCH_PARENT, MATCH_PARENT`. This pushed the video to the center of the vertical screen directly behind the opaque `PlayerInfoPanel`, leaving the transparent 16:9 viewport at the top displaying the black letterbox until entering and exiting fullscreen forced a bounds recalculation.
        - **Fix**: `ensureInitialized()` now checks `if (exoPlayer != null) { if (initialHeight > 0) { ... } return; }`, strictly preserving the initial explicit bounds and preventing `openMedia` from wiping out container dimensions. Additionally, `VideoPlayerScreen.initState()` avoids pre-populating `_lastExoTop` and `_lastExoHeight`, guaranteeing that `_updateExoSurfaceBounds` always synchronizes exact MediaQuery bounds on the very first frame.
      - **Synchronous Surface Refit (`fitSurface`)**:
        - Removed `container.post` delay when `layoutParams.height` is explicit, calculating surface dimensions synchronously on the same UI frame with display metrics fallback.
      - **Orientation Transition Synchronization**:
        - `_toggleFullscreen` no longer prematurely sets `setSurfaceBounds(top: 0, height: -1)` while the device is physically held in portrait.
        - `_updateExoSurfaceBounds` evaluates `effectiveFullscreen = _isFullscreen || _isTvActive || isPhysicalLandscape` synchronously inside `build` and in `addPostFrameCallback`, guaranteeing that fullscreen landscape bounds (`top: 0, height: -1`) apply only when landscape orientation actually arrives, and portrait bounds (`top: top, height: height`) apply immediately without flashing intermediate full-screen portrait states.
  - **Dual-Engine Fallback Execution (`PlayerPlaybackCoordinator`)**:
    - When ExoPlayer encounters an unrecoverable format or playback error on Android, `triggerFallbackToMpv` disposes the native ExoPlayer instance and seamlessly activates `MpvPlayerService` on-the-fly at `fallbackPos`. The player viewport immediately transitions to MPV's `Video` texture without leaving the user stuck on an indefinite loading spinner with null controllers.
    - Caches playback parameters (`_videoUrl`, `_title`, `_episodeTitle`, `_headers`, `_startPosition`, `_externalSubtitles`, `_activeShaderPreset`, `_isOnlineStream`) so engine fallback preserves title, start position, shaders, and external subtitles seamlessly.
  - **Torrent Streaming Resilience (`mpv_player_service.dart`, `ExoPlayerPlugin.kt`, `handler.go`, `repository.go`)**:
    - `backend/internal/torrentstream/repository.go`: Default torrentstream cache working directory updated from `seanime/torrentstream` to `aniting/torrentstream` (`getDefaultDownloadPath`).
    - `AutoDeletePreviousTorrents`: Defaulted to `true` across database models (`default:true`), core initial settings, and UI (`streaming_settings_screen.dart`), automatically purging temporary torrent chunks from prior streams to conserve device storage without requiring manual user toggling.
    - `mpv_player_service.dart`: Prioritizes `isTorrentStream` over `effectiveOnlineStream`. Prevents torrent streams on local network IPs (e.g. `http://192.168.1.x:.../api/v1/torrentstream/...`) from being misclassified as remote HLS online streams with restrictive 10s network timeouts. Sets `network-timeout: 60` and `demuxer-lavf-probesize: 1MB`.
    - `ExoPlayerPlugin.kt`: Sets 60s connect and read timeouts on `DefaultHttpDataSource` for torrent streams, applies `DefaultLoadErrorHandlingPolicy(6)` for automatic retry while pieces buffer, and prevents erroneous HLS manifest retries on torrent streams.
    - `handler.go`: Adds a 15-second polling window in `ServeHTTP` before returning 404, eliminating race conditions when players connect immediately after `torrentstream/start` before initial metadata is fully populated.
  - Supports external subtitle streams via `OnlinestreamVideoSource.subtitles`.
- **Manga Explore & Carousel Fault-Tolerant Resilience (`search_screen.dart`, `app_providers.dart`, `seanime_repository.dart`, `manga.go`)**:
  - `loadMangaWithCacheAndSwr` and `loadAnimeWithCacheAndSwr`: Explore/curated public feeds (`requireAuth == false`) no longer abort with empty `[]` when the embedded/LAN server is starting or offline, allowing `fetchFresh()` to query AniList directly.
  - `seanime_repository.dart`: `getTrendingManga()`, `getPopularManga()`, and `searchManga()` now seamlessly fall back to direct AniList GraphQL queries (`discoverManga`) if the server is offline or fails, ensuring the Manga explore carousel and curated sections load 100% reliably.
  - `backend/internal/handlers/manga.go` & `anilist.go`: Safely allocate pointers for `Page` and `PerPage` when omitted, preventing nil pointer dereferences.
- **In-Player Online Source Resolution & Live Switching Pipeline (`PlayerSourceCard`, `video_player_screen.dart`, `OnlineStreamView`, `anime_detail_desktop_layout.dart`)**:
  - **Zero Outside Delay (~0ms Instant Navigation)**:
    - Previously, clicking an episode in `AnimeDetailScreen` (mobile `OnlineStreamView` and desktop `AnimeDetailDesktopLayout`) displayed a loading spinner on the detail screen while awaiting `repo.getOnlinestreamSource(...)`, followed by a modal bottom sheet/dialog to pick a server/quality before navigating to the player.
    - Now, tapping an episode immediately pushes `VideoPlayerScreen.route(videoUrl: '', ...)` with zero delay, zero waiting outside, and no modal picker on the detail screen.
  - **In-Player Background Resolution & Auto-Stream**:
    - Inside `VideoPlayerScreen`, when `videoUrl` is empty, the player viewport immediately displays a clean, focused loading spinner against the black letterbox background (`isLoadingNextEpisode: _isLoadingNextEpisode || _isResolvingSources`) while `_resolveInitialSources()` resolves the selected provider's sources asynchronously in the background.
    - As soon as sources arrive from the selected provider, the player **immediately auto-plays the first available source found** without waiting for manual user intervention ("no va a esperar a que lleguen todas las opciones, va a transmitir el primero que encuentre").
  - **Modular Source Card (`PlayerSourceCard`) in Info Panel**:
    - Embedded directly in `PlayerInfoPanel` (rendered on both mobile embedded watch page and desktop side panel).
    - **Visual Hierarchy & State**: Displays active server and quality badge (e.g. `GOGOANIME`, `1080p`), provider name, total loaded options, and dynamic resolution status ("Buscando opciones...", "Reproduciendo primera opción encontrada", or error message).
    - **On-Demand Reload Action**: Features a reload icon button (`Icons.refresh_rounded` / `AppIcons.refresh`) with tooltip (`l10n.reloadSourcesTooltip`), allowing users to refresh and re-fetch sources at any time directly from the info panel.
    - **In-Player Live Switching Modal**: Tapping the card opens a Material 3 modal sheet listing all loaded servers and qualities with HLS badges and active playback checkmarks. Tapping any source switches playback seamlessly on-the-fly while preserving the current playback position (`startPosition: _position`).
- **Modular Player Architecture & Services Decomposition (`video_player_screen.dart` & `services/`)**:
  - To respect the project's strict `<400–500` lines guideline, `video_player_screen.dart` was decomposed from an initial monolithic >1,660 lines into dedicated single-responsibility domain services in `lib/presentation/widgets/player/services/`:
    - **`PlayerProgressManager`**: Manages periodic playback continuity updates every 20s, local `LastSessionItem` persistence, and the AniList watched sync latch threshold (~80% watched or within 120s of end).
    - **`PlayerWindowManager`**: Orchestrates fullscreen transitions, desktop native windowing, mobile orientation rotation stabilization (preventing intermediate landscape layout overflows), Android ExoPlayer surface layout synchronization (`setSurfaceBounds`), and clean exit sequences.
    - **`PlayerSourceController`**: Coordinates online stream source discovery, initial auto-streaming of first found sources without outside waiting, live in-player server/quality switching, seamless episode transitions, and background prefetching.
    - **`VideoPlayerScreen`**: Retained strictly as a clean coordinator wiring viewport controls, layouts (`PlayerDesktopLayout`, `PlayerMobileLayout`), and state notifiers.
  - **Zero-Stutter Entry & Exit Pipeline (`VideoPlayerScreen.route`, `MpvPlayerService`, `PlayerWindowManager`)**:
    - **Organic Route Transitions**: Replaced instantaneous zero-duration route switches with smooth, physical fade transitions (`transitionDuration: 180ms`, `reverseTransitionDuration: 150ms` using `Curves.easeOutCubic`), eliminating abrupt cutouts and dropped frames.
    - **Post-Frame Engine Deferral (Elimination of Tap Event Freezes / "Espasmos")**: Heavy native playback engine instantiation (`libmpv` / ExoPlayer, OpenGL texture creation, EGL context setup) and source resolution are deferred to `WidgetsBinding.instance.addPostFrameCallback`. Frame 0 renders immediately with zero gesture-thread contention or button-click freezing.
    - **Desktop Exit Streamlining (Elimination of Black Flash & Hangs)**: On desktop, the black curtain intended for mobile 90° orientation masking is bypassed (`!isDesktop && _isExiting`), progress saving runs asynchronously in the background (`unawaited(onSaveProgress())`), and playback pauses immediately before popping, producing a silky, 120 FPS exit back to the detail view.
    - **Linux Hybrid Hardware Decoding (`hwdec: auto-safe`)**: Set Linux hardware decoding to `auto-safe` instead of forcing `vaapi,auto`, preventing driver probe stalls on hybrid GPU setups (e.g. Intel UHD + NVIDIA RTX) without VA-API configured.
- **MKV Chapters & Segments**:
  - **Cross-Engine Support (Desktop libmpv & Android ExoPlayer)**:
    - **Desktop (libmpv)**: Auto-extracted via `chapter-list` property into `PlayerChapter` models.
    - **Android (ExoPlayer / Media3)**: EBML chapter atoms are intercepted directly during demuxing in `AssMatroskaExtractor.kt` (`ID_CHAPTERS = 0x1043A770`, `ID_EDITION_ENTRY = 0x45B9`, `ID_CHAPTER_ATOM = 0xB6`, `ID_CHAPTER_TIME_START = 0x91`, `ID_CHAPTER_TIME_END = 0x92`, `ID_CHAPTER_DISPLAY = 0x80`, `ID_CHAP_STRING = 0x85`). Timestamps are converted from nanoseconds to milliseconds, contiguous boundaries are populated, and finalized chapters are dispatched to `AssHandler` and forwarded to Flutter via `EventChannel` (`"event": "chapters"`) and `MethodChannel` (`"getChapters"`).
    - `ExoPlayerService`, `PlayerPlaybackCoordinator`, and `video_player_screen.dart` subscribe to chapters dynamically, unlocking chapter ticks on the timeline slider and the floating "Saltar Opening / Ending" skip button on mobile devices.
  - Floating "Saltar Opening / Intro / Ending" pill button appears when playback enters a skippable chapter.
- **Unified Settings Modal & Responsive Presentation (`PlayerSettingsSheet`)**:
  - Sub-navigation for MKV Chapters, Audio Tracks, Subtitle Tracks, Subtitle/Audio Sync offset (±50ms, ±500ms), Playback Speed, Shaders (OFF by default), Aspect Ratio, Performance Stats, and Torrent Download Progress.
  - **Shaders Subview, MPV Engine Integration & Clean Localization (`ShadersView`, `ShaderPreset`, `PlayerShaderService`, `ShaderAssetLoader`)**:
    - **Engine-Aware Visibility**: In `PlayerSettingsSheet`, the Shaders option is strictly guarded by `if (!widget.isUsingExoPlayer)` so it is completely hidden when using Android ExoPlayer, surfacing only when running on the MPV engine.
    - **Native GLSL Execution Pipeline**: `PlayerShaderService` extracts bundled shader assets (`assets/shaders/anime4k/`, `assets/shaders/artcnn/`, `assets/shaders/nvscaler/`) to the application cache directory (`getApplicationCacheDirectory()/shaders/`) via `ShaderAssetLoader`. It dispatches native libmpv commands through `MpvPlayerService.command` (`['change-list', 'glsl-shaders', 'clr', '']` and `['change-list', 'glsl-shaders', 'append', shaderPath]`), verified with presets for Anime4K (Modes A, B, C), NVScaler, and ArtCNN C4F16.
    - **Clean Theme & Wizard Localization**: Theme descriptions were removed from theme selection cards (`welcome_step_theme.dart` and `theme_settings_screen.dart`), displaying clean palette names without unnecessary verbose descriptions. Hardcoded wizard strings (AniList synchronization titles, corner radius slider, settings feedback snackbars, and marketplace hints) are 100% localized through `translations.dart`, `en.dart`, and `es.dart`.
  - **Mobile Embedded Mode (`isBottomSheet: true`)**: When the player is in portrait embedded mode ("modo video pequeño"), settings opens as a sleek **modal bottom sheet** (`showModalBottomSheet`) with a top drag handle indicator and swipe-down-to-dismiss ("de arriba pa abajo"). Bounded to ~70% screen height so the 16:9 video player at the top remains fully visible and playing.
  - **Desktop Windowed / Small Mode (`rightOffset: 380`)**: When the side panel (`PlayerInfoPanel`) is visible on desktop, the settings sheet opens **adjacent to the side panel** rather than overlapping it ("por encima del panel"), featuring floating rounded corners (`BorderRadius.circular(16)`) and crisp borders on both sides. In fullscreen or when side panel is collapsed, it docks smoothly against the screen edge (`rightOffset: 0`).
  - **Fullscreen Mode**: Slides in smoothly from the right edge as a dedicated media control drawer.
- **Real-Time Torrent Download Progress & Minimal Indicators (`torrentStreamStatusProvider` / `PlayerTopBar` / `PlayerSettingsSheet`)**:
  - **Contextual Torrent Visibility**: When streaming a torrent (`isTorrent` detected via video source label, URL endpoint `/torrentstream/`, or active status), the player settings sheet reveals a dedicated "Progreso del Torrent" menu item that navigates into its own sub-section.
  - **Dedicated Settings Sub-Page (`_SettingsSection.torrent`)**:
    - **Monochrome & Minimalist**: Formatted with clean dark container (`#151518`), subtle border (`white.withValues(alpha: 0.08)`), and strictly monochrome typography (white, white70, white54, monospace font for numbers, no loud rainbow colors).
    - **Indicator Toggle**: Clean switch to activate or deactivate the floating indicator on the video player viewport (`_isTorrentProgressVisible`).
    - **Live Real-Time Metrics**:
      - Download percentage (`65.4%`) and downloaded vs total size (`820 MB / 1.25 GB`).
      - Minimal monochrome linear progress bar (white indicator, `white10` track).
      - Download speed (`↓ 2.4 MB/s`) and upload speed (`↑ 150 KB/s`).
      - Connected peers/seeders count (`👥 14 peers`).
      - Estimated time remaining / ETA (`⏱️ 3m 45s` or `Completado` when 100%).
  - **Floating Minimalist On-Screen Indicators (`PlayerTopBar`)**:
    - Rather than an intrusive floating box/card over the media playback, stats are integrated directly into the top bar as clean, floating, background-less monochrome icons and labels: `↓ speed • 👥 seeders • % (ETA)` centered cleanly between the anime/episode title on the left and the window/settings buttons on the right.
    - Soft drop shadows ensure crisp legibility over any video background without obscuring the scene.
  - **Lifecycle Cleanup**: Resets status state upon player disposal, avoiding stale metrics when transitioning between episodes or providers.
- **Mobile Fullscreen & Dynamic Aspect Ratio (ExoPlayer & libmpv)**:
  - **Dynamic Layout Synchronization (`ExoPlayerPlugin.kt`)**: Replaced static one-time sizing with a persistent `View.OnLayoutChangeListener` on `surfaceContainer`. When toggling between portrait embedded player and landscape fullscreen, `videoSurfaceView`, `assSubtitleView`, and `standardSubtitleView` automatically refit to the new display bounds.
  - **Fit Modes Support**: Full dynamic calculation for `contain` (letterbox/pillarbox), `cover` (fill with aspect crop), and `fill` (stretch). Fallback to `MATCH_PARENT` when video dimensions are not yet available prevents zero-sized or stale viewports.
  - **Orientation-Aware Metric Gating & Fullscreen-to-Portrait Stabilization (`video_player_screen.dart`)**:
    - When switching from fullscreen (landscape) to embedded portrait ("screen corta"), the player gates the layout via `effectiveFullscreen = isFullscreen || (!isDesktop && isPhysicalLandscape)` and `_isTransitioningOrientation`.
    - Intermediate landscape frames during physical device rotation render the stable fullscreen player viewport instead of prematurely mounting the portrait `Column` with `AspectRatio(16/9)`, completely eliminating violent layout jumps, 500px aspect-ratio overflows, and disarranged controls.
    - Controls visibility and interaction are suppressed during the 380ms rotation transition, delivering a rock-solid, smooth transition to portrait.
  - **View Tight Constraints (`_buildPlayerViewport`)**: Viewport uses `Positioned.fill` with `SizedBox.expand` so neither ExoPlayer nor `media_kit` views shrink-wrap into centered boxes.
  - **Dual-Engine Subtitle Pipeline (ASS & SRT/WebVTT) & Auto-Selection (`ExoPlayerPlugin.kt`, `player_viewport.dart`, `video_player_screen.dart`)**:
   - **ASS Subtitles (`text/x-ssa`)**: Rendered natively via Plezy's `libass` pipeline with `AssSubtitleSurfaceView` using a hardware composited `SurfaceView` overlay (`setZOrderMediaOverlay(true)`).
   - **Video Frame Callback & VSync Rendering Hook (`ExoPlayerPlugin.kt`, `AssHandler.kt`)**: MediaCodec video frames fire `VideoFrameMetadataListener`, which invokes `handler.videoFrameCallback`. In `ensureInitialized()`, `videoFrameCallback` is wired to `assSubtitleView.requestRender(presentationTimeUs - (subtitleDelayMs * 1000L), releaseTimeNs)`, triggering `AssAtlasPipeline` rendering for every decoded video frame with exact presentation time alignment.
   - **Android 36+ Composition Order (`FlutterOverlayHelper.kt`, `ExoPlayerPlugin.kt`)**: Applies `setCompositionOrder` explicitly: Video SurfaceView (-2) < ASS Subtitle SurfaceView (-1) < Parent / Flutter View (+1). Guarantees that on Android 16/SDK 36+ the ASS subtitle surface is composited directly above the video layer without being obscured behind the video or parent canvas.
   - **Pause, Seek & Track Invalidation**: When paused or seeking (where new video frames are not emitted by MediaCodec), `assSubtitleView.invalidateSubtitles()` forces an immediate re-render of the last subtitle position, ensuring subtitles remain visible while scrubbing or paused.
   - **Accurate Dialogue Duration Parsing (`AssTrackOutput.kt`)**: MatroskaExtractor writes `blockDurationUs` into token 1 of `subtitleSample` (`"%01d:%02d:%02d:%02d"`). `parseTimecodeUs(rawDuration)` decodes the exact event duration directly to milliseconds (`durationUs / 1000`). This completely eliminates the previous false comparison (`endTimeUs > timeUs`) that fell back to a forced 5000ms duration, preventing dialogues from stacking or lingering on screen.
   - **ExoPlayer Subtitle Delay**: Added `setSubtitleDelay` platform channel method and Dart bindings (`ExoPlayerService.setSubtitleDelay` and `PlayerPlaybackCoordinator.setSubtitleDelay`), adjusting timestamps dynamically in `videoFrameCallback` and triggering instant invalidation.
   - **SRT & WebVTT Plain-Text Subtitles (`SubtitleCueLayout.kt`, `ExoPlayerPlugin.kt`)**:
      - Ported Plezy's `SubtitleCueLayout` to stack unpositioned cues (`stackUnpositioned`) and calculate vertical bounds (`applyPosition`), preventing SRT lines from overlapping or colliding.
      - Enabled Media3's native `standardSubtitleView` with hardware-accelerated canvas text rendering, clean outline styles (`CaptionStyleCompat.EDGE_TYPE_OUTLINE`), and dynamic fractional sizing (`setFractionalTextSize(38f * fontSizeMultiplier / 720f)`).
      - Removed redundant Flutter text overlay box to eliminate blurry shadow artifacts and dark background rectangles.
   - **Android libmpv Subtitle Font Resolution (`mpv_player_service.dart`)**:
      - Configured direct system font directory mapping (`sub-fonts-dir=/system/fonts`, `sub-font=Roboto`, `sub-font-provider=none`) on Android for libmpv. This resolves the missing fontconfig fallback on Android SoCs, allowing libmpv to render plain-text SRT and VTT subtitles natively.
   - **Intelligent Subtitle Auto-Selection**: For both torrents and streams with embedded or external tracks, when no subtitle is selected by default, `video_player_screen.dart` automatically selects:
     1. Default external subtitle (if flagged default)
     2. Preferred Spanish track (`es`, `spa`, `español`, `castellano`, `latino`)
     3. Preferred English track (`en`, `eng`, `english`)
     4. First available subtitle track
   - **Zero Duplicate Text Cues & BLASTBufferQueue Hardening (`ExoPlayerPlugin.kt`, `AssSubtitleSurfaceView.kt`, `AssHandler.kt`)**:
     - **BLASTBufferQueue Stability**: `AssSubtitleSurfaceView` maintains a constant full-screen `MATCH_PARENT` layout across all fit modes (`contain`, `cover`, `fill`). Instead of resizing the native SurfaceView (which previously triggered `BLASTBufferQueue: rejecting buffer: active_size vs requested_size` crashes and black screens), video margins are calculated dynamically and dispatched to libass via `assHandler.setMargins(top, bottom, left, right)`.
     - **Robust ASS/SSA Format Detection & Safe Track IDs**: Enhanced `isAssSubtitleFormat()` across `ExoPlayerPlugin.kt`, `AssSubtitleParserFactory.kt`, `AssTrackOutput.kt`, and `AssHandler.kt` to recognize all variations of ASS/SSA (`text/x-ssa`, `text/x-ass`, `application/x-ass`, codec `ass`/`ssa`, and format IDs). Made `createTrack` and `updateTrack` resilient to null or mismatching track IDs with single-track fallback.
     - **Suppression of Unstyled Cues**: When an ASS track is selected (`isCurrentSubAss == true`), plain text cues from Media3 are suppressed, preventing `player_viewport.dart` and `standardSubtitleView` from painting unstyled text with black background rectangles.
     - **Track Selection Race-Condition Protection**: `selectTrack` guards against premature calls (`index >= refs.size`) so that subtitle auto-selection during media preparation never accidentally disables subtitle tracks.
     - **State Reset on Open**: `openMedia` clears previous text track disabled overrides so subsequent video playbacks start with active subtitle selection.
  - **Media3 Subtitle Decoding & libmpv Auto-Fallback Pipeline (`PlezyRenderersFactory.kt`, `ExoPlayerPlugin.kt`)**:
    - In Android Media3 1.5+, subtitle decoding migrated to parsing during extraction (`application/x-media3-cues`), with legacy decoding disabled by default in `TextRenderer`.
    - Streams providing raw `text/vtt` (such as HLS streams or external subtitles via `SingleSampleMediaSource`) throw `IllegalStateException: Legacy decoding is disabled, can't handle text/vtt samples` if not explicitly enabled.
    - `PlezyRenderersFactory` overrides `buildTextRenderers` to configure `TextRenderer.experimentalSetLegacyDecodingEnabled(true)`.
    - `DefaultHlsExtractorFactory` in `ExoPlayerPlugin.kt` configures `setSubtitleParserFactory(subtitleParserFactory)` for both initial load and HLS fallback retries.
    - If any unexpected native ExoPlayer runtime failure occurs, `VideoPlayerScreen` catches code `1004` and seamlessly falls back to `libmpv` at the exact current timestamp.
- **Movie Detection & Episode Navigation (`PlayerInfoPanel` / `VideoPlayerScreen`)**:
  - Automatically identifies movie formats (`format == 'MOVIE'` or `totalEpisodes == 1` with single entry).
  - Movies display clean "Película" headers without awkward `EP 1 • Complete Movie` prefixes.
  - Prevents "Siguiente episodio" and previous episode controls from synthesizing or appearing on movies.
  - `AniZipData.getEpisode(int)` strictly queries main non-special episodes (`!isSpecial`), ensuring specials (e.g. `S2` promotional clips/music videos) never masquerade as a normal "EP 2". Dedicated `getSpecial(int)` is used for specials.
- **Modular Player Architecture (`PlayerPlaybackCoordinator`, `PlayerDesktopLayout`, `PlayerMobileLayout`, `PlayerSettingsLauncher`)**:
  - `video_player_screen.dart` was streamlined from an monolithic 1,767-line file into decoupled, modular components:
    - **`PlayerPlaybackCoordinator`** (`lib/presentation/widgets/player/services/player_playback_coordinator.dart`): Coordinates dual-engine video playback (Android ExoPlayer vs libmpv desktop/fallback). Encapsulates stream listening (position, duration, buffer, playing, buffering, ended, tracks, cues), track parsing, subtitle auto-selection, delay, shaders, and seamless error fallback to MPV without polluting widget state with dozens of `StreamSubscription` fields.
    - **`PlayerDesktopLayout`** (`lib/presentation/widgets/player/layouts/player_desktop_layout.dart`): Houses desktop windowed video presentation with animated collapsible side info panel (380dp) on the right.
    - **`PlayerMobileLayout`** (`lib/presentation/widgets/player/layouts/player_mobile_layout.dart`): YouTube-style mobile watch page with 16:9 player viewport at the top and expandable episode/details panel below.
    - **`PlayerSettingsLauncher`** (`lib/presentation/widgets/player/sheets/player_settings_launcher.dart`): Computes responsive layout offsets and launches `PlayerSettingsSheet` (modal bottom sheet on mobile portrait, docked media drawer on desktop/fullscreen).
- **Instant Episode Switching & Background Stream Prefetching (`video_player_screen.dart`, `PlayerEpisodeResolver`, `PlayerViewport`, `MpvPlayerService`)**:
  - **Zero-Flicker Instant Video Purge**: When the user taps "Siguiente episodio" or "Episodio anterior", `_coordinator.stop()` and `_coordinator.pause()` are triggered synchronously from frame 0, instantly cutting audio and clearing previous video frames into an unblemished black surface with a clean native loading spinner (`isLoadingNextEpisode: true`). Old video frames and lingering audio never persist while the new stream resolves.
  - **In-Memory Stream Caching & Request Deduplication**: `PlayerEpisodeResolver` maintains an in-memory cache and in-flight `Future` tracking for resolved episode streams (local and online providers), allowing immediate 0ms playback transitions when a stream has already been fetched.
  - **Automatic Background Prefetching**: After 12 seconds of playback, `_schedulePrefetchNextEpisode()` quietly requests and resolves the subsequent episode in the background without stealing foreground network priority, making transitions to the next episode instantaneous when clicked.
  - **Complete On-Screen Notice / OSD Suppression**:
    - Removed the intrusive on-screen `Cargando EP X...` text toast (`SeekFeedbackToast` suppressed during episode load).
    - Hardened `MpvPlayerService` with `osd-level=0` and `osd-playing-msg=""`, preventing libmpv from painting internal "Chapter / Capítulo" OSD messages onto the video canvas.
- **AniList Anime Episode Progress Sync (Auto-Mark as Watched)**:
  - **Pipeline**: Mirrors the manga reader's chapter completion sync. When the user watches ~80% of an episode's duration OR is within 2 minutes of the end, the player auto-syncs the episode as watched on AniList via `POST /api/v1/library/anime-entry/update-progress`.
  - **Idempotency Latch**: `_hasUpdatedAnimeProgress` boolean in `video_player_screen.dart` ensures each episode only triggers one sync call. Resets to `false` when switching episodes via `_switchVideoSource`.
  - **Provider Invalidation**: After successful sync, `animeCollectionProvider` and `continueWatchingProvider` are invalidated for immediate feed refresh.
  - **Repository Method**: `seanime_repository.dart` → `updateAnimeProgress({mediaId, episodeNumber, totalEpisodes})` → `ApiEndpoints.animeUpdateProgress`.
  - **Backend**: `HandleUpdateAnimeEntryProgress` in `anime_entries.go` already handles AniList GraphQL mutation, auto-completion detection, and collection cache refresh. No backend changes needed.
- **Watched Episode Visual Indicator (UI)**:
  - **`isWatched` Parameter**: `EpisodeListItem` and `EpisodeGridItem` (`episode_item_widget.dart`) accept `isWatched: bool` to render watched state.
  - **List View (`EpisodeListItem`)**: Watched episodes show a semi-transparent dark overlay on the thumbnail with a check badge, dimmed EP number (from `primary` to `onSurfaceVariant` at 0.5 alpha), dimmed title (0.55 alpha), and dimmed synopsis (0.4 alpha).
  - **Grid View (`EpisodeGridItem`)**: Watched episodes show a subtle accent tint background (`primary.withValues(alpha: 0.08)`), a check icon before the EP number, and dimmed title text.
  - **Progress Source**: `anime_detail_screen.dart` reads live progress from `animeCollectionProvider` (for real-time sync updates) with fallback to `_details?.progress` and `widget.initialEntry?.progress`. Passed via `progress` parameter to `OnlineStreamView`, `AniZipEpisodeListView`, and `LocalLibraryView`, which compute `isWatched: ep.number <= progress && ep.number > 0`.
- **AniList Canonical Collection & Continue Watching Pipeline (`seanime_repository.dart`)**:
  - **Backend Local File Filtering Nuance**: In the Seanime Go backend (`backend/internal/library/anime/collection.go:210`), `/api/v1/library/collection` **strictly filters out any media without local `.mkv`/`.mp4` files on disk** (`if slices.Contains(mIds, entry.Media.ID)`). If users stream exclusively online or track entries on AniList, their media does not appear in `/library/collection`.
  - **Canonical Collection (`getLibraryCollection`)**: Refactored to query `/api/v1/anilist/collection` as primary source (fetching all user entries across all AniList lists: CURRENT, PLANNING, COMPLETED, PAUSED, DROPPED, REPEATING), extracting canonical `mediaId`, AniList status, user progress, and score, then merging any local files/episodes from `/library/collection`.
  - **Continue Watching for Online & Tracked Anime (`getContinueWatching`)**: Queries both `/library/collection` and `/anilist/collection` concurrently. For animes in the user's AniList `CURRENT`, `WATCHING`, or `REPEATING` list with `progress < totalEpisodes`, it synthesizes next-episode continue watching cards (`episodeNumber = progress + 1`), auto-enriches each card with AniZip metadata (16:9 thumbnail, episode title, air date), and deduplicates against local library episodes.
  - **Model Field Normalization (`AnimeEntry`, `AnimeDetails`)**:
    - `AnimeEntry.fromJson`: Uses `(val as num?)?.toInt()` for `progress`, `totalEpisodes`, `mediaId`, and `id` to prevent `TypeError` exceptions during dynamic JSON parsing, guaranteeing `id` maps to the canonical media ID rather than AniList list entry ID.
    - `AnimeDetails`: Added `progress`, `userStatus`, and `userScore` fields, parsed from `listData` in `AnimeDetails.fromJson`.
- **AniList List Entry Edit Modal (`EditEntryModal` & `widgets/edit_entry/`)**:
  - **Purpose**: Allows users to view, edit, or delete the tracking state of an Anime or Manga entry directly on AniList or local offline storage from `AnimeDetailScreen` and `MangaDetailScreen`.
  - **Liquid Glass & Motion Overhaul**:
    - **Top-to-Bottom Window Animation**: Opens via `showGeneralDialog` with an expressive 320ms top-to-bottom drop-in transition (`SlideTransition` from `Offset(0, -0.16)` to `Offset.zero` with `Curves.easeOutCubic`, paired with smooth fade and subtle scale).
    - **Noticeable Frosted Glass Window**: Wrapped in `DecoratedBox` ambient drop shadow, `ClipRRect`, `BackdropFilter` (sigma 22.0), `GlassCard`, and translucent theme tinting with a delicate specular rim (`Colors.white.withValues(alpha: 0.22)`).
    - **Window Header**: ANIME / MANGA glowing badge chip, prominent title in bold typography, and liquid glass circular close `[x]` button.
    - **Modular Architecture (`lib/presentation/widgets/edit_entry/`)**:
      - `EditEntryStatusDropdown`: Status selector built with `g1455` `GlassPopoverAnchor` and `GlassMenuController`, clipped to prevent scrollbar leakage, featuring live status color badges (green for Watching, blue for Planning, purple for Completed, orange for Dropped, etc.) and checkmark indicators.
      - `EditEntryScoreSlider`: Replaces raw text inputs with a modern 0.0 to 10.0 liquid glass slider (0.1 precision), featuring an amber star badge, live score readout, and quick `[-]` / `[+]` 0.5 step buttons with haptic feedback.
      - `EditEntryStepper`: Liquid glass stepper for Progress (with visual progress fill bar when `totalCount` is known, and tap-to-input direct number dialog) and Repeats. Flex-safe header prevents label overflow.
      - `EditEntryDatePicker`: Frosted glass date pills with calendar icon, ISO formatted date string, and clear `[x]` button for Start and Completion dates.
    - **Bottom Action Bar**: Responsive `Wrap` layout preventing horizontal overflow across any screen width; includes context-aware delete button on the left, and cancel & primary accent `Save changes` button on the right.
    - **Dynamic Theming (No Hardcoded Colors)**: All surfaces, input field fills, borders, dropdown menus, text, icons, and buttons dynamically consume `Theme.of(context).colorScheme` and `context.themeColors.borderRadius`.
  - **Endpoints & Persistence**:
    - `POST /api/v1/anilist/list-entry`: Updates status, score, progress, start date, and completion date for both anime and manga, triggering automatic backend collection refresh. AniList GraphQL schema strictly requires `scoreRaw` to be an integer (defaults to `0` when unscored).
    - `DELETE /api/v1/anilist/list-entry`: Removes the entry from AniList.
    - `POST /api/v1/library/anime-entry/update-repeat`: Updates repeat count for anime.
    - `GET /api/v1/library/anime-entry/{id}` & `GET /api/v1/manga/entry/{id}`: Retrieves existing `listData` (dates, repeat, score) on open.
  - **Provider Invalidation**: On save or delete, invalidates `animeCollectionProvider` / `continueWatchingProvider` or `mangaCollectionProvider` / `continueReadingMangaProvider` and immediately reloads `_loadDetails()` for instant UI refresh.

### 4.3. Extensions & Marketplace Architecture
- **Plugin Exclusion**: Desktop/chromedp web `plugin` extension types are **NOT** supported and are filtered out of all marketplace listings and filters.
- **Supported Provider Types**: `anime-torrent-provider`, `manga-provider`, `onlinestream-provider`, `custom-source`.
- **Extension Source Code Viewer**: `Icons.code_rounded` button opens `ExtensionCodeModal` fetching JS payload via `GET /api/v1/extensions/payload/{id}`.
- **Extension Updates**: Handled via `POST /api/v1/extensions/all` with `{"withUpdates": true}`.
- **Spanish & Multi-Language Video Extractor Suite (`extensions/jkanime/`, `extensions/tioanime/`, `scripts/aniting_play.py`, `VIDEOS.md`)**:
  - **Reverse-Engineered Video Extractors (Detailed in `VIDEOS.md`)**:
    - **AnimeX (`https://animex.one`)**: Direct AniList GraphQL mapping -> `pp.animex.one` REST API -> `cdnx.aniwatchtv.site/uwu/<token>` proxy with static XOR cipher (`10b06cdc1ca48c9fb0b94af97cc040cf`) and automatic intro/outro chapter markers. Supports Sub & Dub in 1080p with `--demuxer-lavf-format=hls`.
    - **Kawaii Animes Local DB (`~/.cache/aniting/kawaii.db`)**: Replicated SQLite catalog (36k+ eps, 104k+ player streams) with native support for **Subtitulado** (`lang=0`), **Audio Latino** (`lang=1`), and **Audio Castellano** (`lang=2`). Extracts **LuluStream / Epsilon** (`luluvdoo.com`) into master HLS 1080p via Dean Edwards unpacking with strict `--referrer` and `--user-agent` enforcement.
    - **Anime Nexus Analysis (`https://anime.nexus`)**: Reverse-engineered catalog API (WinterCMS) and Turnstile / HMAC WireProof DRM challenge; documented resolution via Seanime's Goja ChromeDP bindings or authenticated user sessions.
    - **Dean Edwards JS Unpacker (`_unpackJs`)**: Ported from Kawaii Animes `JsUnpacker` algorithm supporting base 36/62 radix dictionary word replacement (`eval(function(p,a,c,k,e,d)...)`). Unpacks obfuscated script blocks into clean master `.m3u8` playlists for **StreamWish** and **Vidhide** hosts.
    - **JK Native Player Extractor**: Scrapes `/jkplayer/um` and `/jkplayer/umv` iframes, extracting ultra-fast direct `.m3u8` streams from `nika.playmudos.com` with zero ads and instant playback.
    - **Mp4Upload & YourUpload Direct Scrapers**: Direct regex extraction of high-speed MP4 video sources with correct `Referer` headers and 302 redirect tracking.
    - **VOE Multi-Stage Extractor**: Handles redirect delivery hops, decoding base64 / rot13 payloads.
  - **Multi-Server Cascade Resilience**: Both JKAnime and TioAnime providers implement resilient multi-server fallback: if the requested server fails or is unavailable, the provider automatically falls back through priority hosts (JK -> StreamWish -> Vidhide -> Mp4upload -> YourUpload -> Voe) to ensure zero playback failures.
  - **Local Deployment**: Extensions are synchronized across `extensions/` (repository), `~/.config/aniting/extensions/`, and `~/.config/Seanime/extensions/`.
  - **Terminal Player Tool (`scripts/aniting_play.py` / `aniting-play`)**: CLI utility integrating AniList GraphQL API, real-time multi-server scrapers (AnimeX, Kawaii Animes with 3 languages, JKAnime, TioAnime), and direct `mpv` execution with custom HTTP headers and chapter markers for rapid testing and zero-overhead playback.

### 4.4. Theming, Media Center & Focus Navigation
- **Decoupled Modern Web / Media Center Styling**:
  - Sleek 10-12px geometry with crisp 1.0px borders (`AppThemeColors.border`).
- **Unboxed & Sectioned Settings UI (`settings_screen.dart` & `pixel_settings_widgets.dart`)**:
  - **No Enclosing Boxes ("Sin cajones, todo suelto")**: Replaced card containers (`PixelSettingsGroupCard`, `PixelCardContainer`) and heavy tile borders with completely unboxed, open layouts.
  - **Titles Only (No Redundant Short Descriptions)**: Category items in `SettingsScreen` present clean, concise titles (`Tema y Colores`, `Apariencia e Interfaz`, `Extensiones`, `Reproductor de Video`, `Lector de Manga`, `Servidor Seanime y Red`, `Acerca de Aniting`) without cluttered subtitles.
  - **Clean Section Separation**: Clearly grouped and separated by semantic sections (*Preferencias*, *Sistema*, *Información*) with prominent headers and breathing room.
  - **Smooth Selection & Hover States**: Transparent background in rest state; subtle accent tint (`primary.withValues(alpha: 0.12)`) when selected in dual-pane desktop mode; smooth hover highlight on pointer devices.
  - **Loose Profile & Search Elements**: AniList profile and settings search bar adopt the borderless, unboxed design language.
- **Crisp DPAD, TV Remote & Keyboard Focus System**:
  - DPAD arrows, TV remote `Select` / `Enter`, and mouse hover.
  - **Solid White Focus Border**: Clean, crisp solid white outline (`Colors.white`, width: 2.0px) for maximum readability and neutral aesthetics.
  - No vertical card-scaling animations that cause clipping against horizontal `ListView` ceilings.
- **Community & Material Design 3 Themes (`lib/core/theme/app_palette.dart`)**:
  - **Dark Community Themes**: Tokyo Night, Catppuccin Mocha, Dracula, Nord, OLED True Black, Cyberpunk, Midnight Navy, Gruvbox Dark, Rosé Pine.
  - **Light Community Themes**: Catppuccin Latte, Tokyo Day, Nord Snow, Dracula Light, Sakura, Solarized Light, Clean Slate.
  - **Material Design 3 Palettes**: Purple, Blue, Green, Orange, Crimson, Teal (dynamically generated via `ColorScheme.fromSeed` for both Dark and Light modes).
  - **Counterpart Matching**: `AppThemeBuilder` automatically maps dark community palettes to their matching light counterparts (and vice-versa) when toggling between dark and light modes, preventing dark backgrounds from persisting in light mode.
  - **Dynamic Palette Accent & Custom Accent Management**:
    - Each theme palette provides its own curated signature accent color (e.g. Tokyo Night blue, Nord frost, Dracula purple, Cyberpunk amber, Rosé Pine rosé, Gruvbox amber, Sakura pink, Material green/orange/blue).
    - Selecting any theme palette automatically updates the primary/accent color of the application (`scheme.primary` and `colors.accent`) and clears any previous custom accent override, ensuring the theme's authentic design is applied.
    - An optional custom accent override can still be applied from Settings under "Color de acento", with an option to restore "Predeterminado del Tema" (Theme Default) at any time.
  - Auto-detects Linux Dank Material Shell / Matugen colors (`~/.config/gtk-3.0/dank-colors.css`).
- **Icon Pack System (`lib/core/icons/app_icons.dart`)**:
  - Fully reactive icon system supporting **Lucide Web/Desktop icons** (`lucide_icons_flutter`) and **Material Symbols** (`Icons.*`).
  - Configurable via `iconPackProvider` (`IconPackNotifier`) with persistent `SharedPreferences` cache.
  - All screens and subsystems (`SettingsScreen`, `LibraryScreen`, `SearchScreen`, `DownloadsScreen`, `FeedScreen`, `MangaFeedScreen`, `AboutSettingsScreen`, `CompactSearchBar`, `DesktopSidebar`, `MobileNavDock`, `VideoPlayerScreen` & all player controls/overlays/sheets, `MangaReaderScreen` & `MangaReaderSettingsSheet`) dynamically react to icon pack switching.
  - `AppIcons` provides over 95 semantic icon mappings (navigation, media, playback, gestures, volume/brightness HUD, chapter tags, sync offsets, shaders, fit modes, torrent stats, manga reading modes, arrows, server, offline states) with optional `[AppIconPack? pack]` parameters defaulting to the synchronously cached active pack.
- **Branding & About Screen (`about_settings_screen.dart`)**:
  - Official logo located at `assets/icons/logo.png` integrated into hero cards, developer badges, Android launcher mipmaps (`mipmap-mdpi` through `mipmap-xxxhdpi`), and native Windows icon (`windows/runner/resources/app_icon.ico` supporting 16x16 up to 256x256).
  - Streamlined "Sobre Aniting" view: Developer information and a single concise "Créditos" link acknowledging Seanime media server backend (`https://seanime.app`).
- **Integrated Desktop Titlebar (`DesktopTitleBar` & `window_manager`)**:
  - Hides native OS titlebar frame via `window_manager` (`TitleBarStyle.hidden`) across all desktop platforms (Windows, macOS, and Linux).
  - **Linux Custom Titlebar & The "Double Titlebar" Resolution**:
    - *The Issue*: Previously, Linux was restricted to `TitleBarStyle.normal` because calling `windowManager.setTitleBarStyle(TitleBarStyle.hidden)` from Dart produced a duplicate titlebar (both the system OS titlebar and Flutter's in-app titlebar appeared simultaneously). In Linux GTK, Flutter shows the window on the first frame callback (`first_frame_cb -> gtk_widget_show`). When mapped, Wayland compositors (GNOME Mutter, KDE KWin) lock in native decorations. Asynchronous undecoration requests from Dart run after mapping and are ignored by Wayland compositors.
    - *The Native C++ Fix (`linux/runner/my_application.cc`)*: Calls `gtk_window_set_decorated(window, FALSE);` synchronously when the `GtkWindow` is created, before realization or mapping. This forces GTK and Wayland compositors to spawn the window without system decorations from frame zero, eliminating the double titlebar entirely.
    - *Dart Configuration (`lib/main.dart`)*: Uses `titleBarStyle: TitleBarStyle.hidden` unconditionally for all desktop platforms (`Platform.isWindows || Platform.isMacOS || Platform.isLinux`).
    - *Window Resizing with `DragToResizeArea` (`lib/presentation/widgets/desktop_title_bar.dart`)*: Undecorated GTK windows lose system resize handles. `DesktopWindowFrame` wraps the app in `DragToResizeArea` on Linux, providing transparent 8dp hitboxes across all borders and corners that hook into native `windowManager.startResizing(edge)` (`gtk_window_begin_resize_drag`).
  - **Transparent Stack Overlay Architecture (`DesktopWindowFrame`)**:
    - Embedded as a floating `Positioned` overlay atop a `Stack` (`lib/presentation/widgets/desktop_title_bar.dart`), allowing media content (Anime Detail hero banners, Video Player viewport, and Explore hero carousels) to bleed edge-to-edge behind the titlebar with zero solid gaps or white bars.
    - Draggable `DragToMoveArea` spans the client area while leaving interactive navigation elements (e.g. back buttons, sidebar icons, search bars) with comfortable top clearance (~38-42dp).
    - Windows caption buttons feature adaptive contrast (`desktopTitleBarBrightnessOverrideProvider`) so video playback enforces crisp white caption controls even when the global theme is Light mode.
    - **`DesktopSafeAppBar` (`desktop_title_bar.dart`)**: A universal `PreferredSizeWidget` wrapper that adds `DesktopTitleBar.height` (34.0px) top padding on desktop platforms (Windows, Linux, macOS) while preserving exact zero-overhead mobile layouts. Prevents standard `AppBar` back buttons and titles from colliding with `DragToMoveArea` across all pushed views (`GenreDetailScreen`, `GenresScreen`, `AnimeFullDetailsScreen`, `ExtensionsMarketplaceScreen`, `AiringCalendarScreen`, `SettingsScreen`, and mobile fallback of `MyListsScreen`).
    - **Settings & Subpages Titlebar Clearance (`pixel_subpage_scaffold.dart`, `settings_screen.dart`)**: In `PixelSubpageScaffold` and `PixelPageHeader`, added `extraDesktopTop` (`DesktopWindowFrame.isDesktopPlatform ? DesktopTitleBar.height : 0.0`) to top padding, ensuring back buttons are positioned at `y = 42.0` (fully clear of the 34px titlebar) for effortless clicking without window drag interference. Wrapped both settings sidebar and mobile fallback AppBars in `DesktopSafeAppBar`.
  - **Desktop My Lists Overhaul (`MyListsDesktopLayout`, `lib/presentation/widgets/my_lists/my_lists_desktop_layout.dart`)**:
    - Replaced the oversized, mobile-like stretched tab view on desktop with a dedicated desktop library experience.
    - **Top Action Bar**: Safe 42dp top clearance below the custom titlebar, hover-animated back button, prominent bold screen title, non-wrapping `MediaTypeToggle` pill switcher (Anime / Manga), real-time title search box, and collection refresh button.
    - **Live Status Badges**: Filter pills compute real-time counts from the library (e.g., `Viendo (12)`, `Completados (45)`, `Planeados (20)`, `Todos (77)`) with active primary accents, subtle hover states, and smooth filter switching.
    - **Responsive Media Grid**: 200px max cross-axis card grid with `childAspectRatio: 0.53` ensuring zero render flex overflows on multiline titles, smooth wheel scrolling with `SmoothTrackingScrollController`, and responsive empty states.
  - **Desktop Extensions & Marketplace Redesign (`ExtensionsDesktopLayout`, `lib/presentation/widgets/extensions/extensions_desktop_layout.dart`, `installed_tab_view.dart`)**:
    - Modeled directly after the official Seanime desktop client.
    - **Top Bar**: Safe 42dp desktop top clearance below the custom titlebar, hover back button, screen title, and centered segmented pill switcher (`[ 📦 Installed (N) ] [ 🏬 Marketplace ]`) with responsive badges.
    - **Marketplace Header & Actions**: Header display with repository source link, quick action buttons (`Refresh`, `Change repository` / `Check for updates`, `Reload all`), category filter pills, language selector, and search input.
    - **Multi-Column Card Grids**: Responsive grid for installed extensions (`maxCrossAxisExtent: 440, mainAxisExtent: 172`) and marketplace items (`maxCrossAxisExtent: 380, mainAxisExtent: 180`) on desktop displays (`width >= 650`), avoiding stretched full-width rows and prevent layout overflows.
  - **Desktop Offline Downloads Overhaul (`DownloadsDesktopLayout`, `lib/presentation/widgets/downloads/downloads_desktop_layout.dart`, `downloads_screen.dart`)**:
    - Replaced the narrow 820px phone column with a wide desktop layout (`maxWidth: 1600`).
    - **Top Action Bar**: Safe 42dp titlebar clearance, back button, screen title, segmented `MediaTypeToggle` pill (`Anime` / `Manga`), quick access pill to `DownloadManagerScreen` ("Gestor de descargas") with live active download badge, local folder scan action, and folder directory launcher.
    - **Responsive Header Layout**: Uses `LayoutBuilder` so action buttons smoothly wrap below the title on widths under 950px, preventing horizontal overflows.
    - **Multi-Column Card Grid**: Wide card grid (`maxCrossAxisExtent: 200, childAspectRatio: 0.53`) with inline deletion dialogs and instant offline playback navigation.
  - **Desktop Anime Detail Experience (`anime_detail_desktop_layout.dart`)**:
    - **Bottom-Aligned Header**: Season, title, genres, and synopsis sit in a `ConstrainedBox(minHeight: 360)` with `MainAxisAlignment.end`, aligning perfectly above the action bar and tabs at the bottom of the poster without empty white space when synopsis is short.
    - **Adaptive Theme Typography**: Title, season, synopsis, sidebar metadata rows, and tab indicators seamlessly adapt between dark and light themes (high-contrast text in light mode rather than washed-out white text).
    - **Multiple Online Sources Modal**: Clicking an episode in online mode with multiple servers/qualities opens a sleek desktop selection modal instead of immediately jumping to the first source, harmonized with mobile behavior.
    - **External Card Titles for Relations & Recommendations**: `_DesktopRelationCard` and `_DesktopRecommendationCard` place anime titles and relation badges outside the poster container, conforming to standard `AnimeCard` styling.
- **Linux Wayland & Desktop Integration (`linux/runner/my_application.cc`)**:
  - Implements automatic `setup_application_icons(window)` on startup to guarantee reliable icon display across all Wayland compositors (KDE KWin, GNOME Shell) and X11:
    - **Wayland `app_id` Integration**: Auto-installs `com.seanime.app.seanime_app.png` into `~/.local/share/icons/hicolor/256x256/apps/` and generates `~/.local/share/applications/com.seanime.app.seanime_app.desktop` if not present. Solves the fallback "W" Wayland placeholder icon in KDE's titlebar and Alt-Tab window switcher.
    - **Frameless CSD & Custom Titlebar**: Replaced bulky GTK3 `GtkHeaderBar` and native system titlebars with `gtk_window_set_decorated(window, FALSE)` in `my_application.cc`, seamlessly unifying Flutter's `DesktopTitleBar` with Wayland window dragging and edge resizing.
  - **Build Dependencies**: Compiling `media_kit_video` on Linux requires `mpv` (`libmpv.so` and `mpv.pc` for CMake `PkgConfig::mpv`). On Arch/CachyOS: `sudo pacman -S mpv`. On Debian/Ubuntu: `sudo apt install libmpv-dev mpv`.

### 4.5. Onboarding & Welcome Flow (`welcome_screen.dart`)
- **State Management & Persistence**:
  - `onboardingProvider` (`lib/core/preferences/onboarding_provider.dart`): Riverpod `Notifier<bool>` tracking whether the user has completed the onboarding flow.
  - Persisted in `SharedPreferences` under key `'has_completed_onboarding_v1'`.
  - Cached synchronously during startup in `main()` via `OnboardingNotifier.setCachedPrefs(prefs)`, preventing layout pop-in or flash.
  - If incomplete, the app launches into `WelcomeScreen()`. Once finished or skipped, `has_completed_onboarding_v1` is set to `true` and the UI seamlessly transitions to `MainShell()`.
- **Modular Architecture (`lib/presentation/widgets/welcome/`)**:
  - `WelcomeScreen` acts as a lightweight orchestrator (~370 lines) managing page index, animation transitions, bottom controls, and extension fetching state.
  - The 5 steps and auxiliary sheets are decoupled into isolated widgets:
    - `welcome_step_language.dart` (`WelcomeStepLanguage`): Language picker and choice cards.
    - `welcome_step_theme.dart` (`WelcomeStepTheme`): Graphical mode cards, live icon pack switcher, accent picker, and palettes.
    - `welcome_step_content_preferences.dart` (`WelcomeStepContentPreferences`): Title language chips, poster preview, and M3 expressive corner radius slider.
    - `welcome_step_extensions.dart` (`WelcomeStepExtensions`): Recommended extensions with category filters and batch install.
    - `welcome_step_anilist.dart` (`WelcomeStepAniList`): AniList session card, login trigger, and finish action.
    - `welcome_marketplace_sheet.dart` (`WelcomeMarketplaceSheet`): Full searchable marketplace bottom sheet.
- **Streamlined UI & Mobile/Desktop Responsive Navigation**:
  - **Centered Bounded Layout on Large Screens**: Automatically centers the entire wizard layout (top bar, 5 step pages, and bottom navigation controls) with `ConstrainedBox(maxWidth: 640)` on desktop/tablet displays, preventing cards, previews, and buttons from stretching across widescreen monitors, while seamlessly taking 100% of the screen on mobile devices.
  - **Marketplace Modal Width Bounding**: The full extension marketplace bottom sheet (`WelcomeMarketplaceSheet`) is bounded to `maxWidth: 700` on desktop.
  - **Clean Header**: Header displays only the active step pill (`1 / 5`) and a concise 'Saltar' ('Skip') text button, free of large shiny badges.
  - **Zero-Overflow Bottom Navigation**: Bottom bar is borderless (no harsh top divider line) and uses compact circular action buttons (`IconButton.filledTonal` for back `<`, `IconButton.filled` for next `>` / finish `✓`) centered around animated step dots. Prevents any `RenderFlex` overflow across all compact mobile viewports (`w <= 386.7`).
  - **Borderless Modern Cards**: Replaced heavy enclosing borders and nested boxes with subtle `surfaceElevated.withValues(alpha: 0.40)` containers, breathing space, and sleek tinted selection outlines.

### 4.6. Refined Fluid Route Transitions Architecture (`custom_route_transitions.dart`, `WebPageTransitionsBuilder`, `SmoothPageRoute`, `SlideRightToLeftPageRoute`)
- **Micro-Breath Fade ("El Respiro") for Details, Shell Tabs & Global Routes (`buildWebPageTransition`, `SmoothPageRoute`, `ShellAnimatedIndexedStack`)**:
  - Used for `AnimeDetailScreen.navigate`, `MangaDetailScreen.navigate`, `ShellAnimatedIndexedStack` (tab navigation), and global `WebPageTransitionsBuilder`.
  - **Zero Translation (Cero desplazamiento)**: Completely eliminated vertical and horizontal offset jumps (`Offset.zero`). No jarring screen shakes or sliding layers.
  - **Tactile Micro-Breath Scale**: Incoming view enters with an imperceptible, organic `0.985 -> 1.0` scale heartbeat using natural deceleration curve `Curves.easeOutCubic`, paired with smooth progressive opacity (`0.0 -> 1.0`).
  - **120 FPS Pop / Exit Without Lag**: The underlying parent route remains completely unencumbered by transforms (`secondaryAnimation`), eliminating expensive full-screen texture re-rasterization. Blind invalidations on pop in `FeedScreen._openDetail` were completely removed; state updates are driven reactively when mutations actually happen (e.g. `EditEntryModal`, playback progress updates, or downloads).
  - **Zero-Cut Harmonious Dissolve**: Both enter and exit share identical 220ms durations and `Curves.easeOutCubic` curves, eliminating speed desynchronization and abrupt cuts.
- **Native Horizontal Slide for Settings & Subpages (`SlideRightToLeftPageRoute`)**:
  - Dedicated route builder for drilling down into Settings (`ServerSettingsScreen`, `AppearanceSettingsScreen`, `PlayerSettingsScreen`, etc.), `MyListsScreen`, `DownloadsScreen`, `ExtensionsMarketplaceScreen`, and `GenresScreen`.
  - **Right-to-Left Entrance**: The child route slides smoothly from the right (`Offset(1.0, 0.0) -> Offset.zero`) over 280ms with a subtle elevation drop shadow on its left edge.
  - **Parallax Depth**: The parent view recedes gently to the left (`Offset.zero -> Offset(-0.25, 0.0)`).
  - **Natural Pop/Back**: On exit (240ms), the subpage slides away cleanly to the right (`Offset.zero -> Offset(1.0, 0.0)`), restoring the parent view seamlessly without sudden jumps or scaling artifacts.

### 4.7. Material 3 Expressive Select Component (`m3_expressive_select.dart`, `M3ExpressiveSelect`, `M3SelectItem`)
- **Inspired by shadcn-m3e / Material 3 Expressive Motion**:
  - Replaces rigid, square legacy Flutter `DropdownButton` with an expressive, floating Select component.
  - **Animated Trigger Pill**: Rounded container with hover lighting, subtle outline borders, and a smoothly rotating 180° chevron icon (`AnimatedRotation` over 200ms `Curves.easeOutCubic`).
  - **Spring Floating Menu Overlay**: Uses `OverlayEntry` and `CompositedTransformFollower` with `FadeTransition` + `ScaleTransition` (`0.92 -> 1.0` with `Curves.easeOutCubic`). Elevated container with 14px rounded corners, deep ambient shadows, and outside-tap dismissal.
  - **Selected Item Styling**: Tinted with accent color (`primary.withValues(alpha: 0.22)`), bold high-contrast text, and a crisp checkmark icon (`Icons.check_rounded`) on the right.
  - **Desktop Implementation**: Integrated into `DesktopEpisodesTab` for the online streaming provider selector (`widget.selectedProvider`).
- **5-Step Onboarding Flow**:
  0. **Language Selection**: Real-time switch between Spanish (`es`) and English (`en`) via `i18nProvider`. Updating language dynamically refreshes extension recommendations in Step 4.
   1. **Appearance & Theming**:
      - **Visual Graphical Theme Mode Cards**: Sleek, app-like visual window mockups for **Oscuro**, **Claro**, and **Sistema** (with 50/50 split light/dark preview), eliminating cluttered text descriptions.
      - **Real-Time Dynamic Icon Pack Updates**: Switching between **Lucide Web** and **Material Symbols** instantly reflects across all icons on the screen (theme headers, dark/light/system mode icons, selection checkmarks, radio indicators, and accent sparkles).
      - **Minimalist & Breathable Layout**: Removed verbose descriptive paragraphs and the redundant "Aniting Seanime / Frieren" live preview card, maximizing focus on essential theme controls.
      - **Accent Color Selector**: Choose between "Predeterminado del Tema" (theme's native signature accent) or custom color swatches (`kMaterialAccents`).
      - **Category Filter Tabs**: **Temas Oscuros**, **Temas Claros**, and **Material Design 3** palettes with dual-color indicators.
   2. **Anime Title & Corner Radius Preferences**:
      - **Live Preview Card**: Default Frieren poster (`https://image.tmdb.org/t/p/original/kT1ZkLmG9oNUz2Z10PqKCh8CwLI.jpg`) with live title switching and dynamic corner radius.
       - **Minimalist Typographic Title Language Selector**: Seamless animated typographic selector (Romaji `Sousou no Frieren`, English `Frieren: Beyond Journey’s End`, Native `葬送のフリーレン`) without checkmarks, smoothly scaling selected option to 22sp (bold, solid opacity) while dimming unselected options to 16sp (35% opacity) via `AnimatedDefaultTextStyle`, backed by `titleLanguageProvider`.
      - **Global Corner Radius Slider & Reactive Layout**: Real-time slider (0px to 24px) modifying `borderRadius` across the entire application (cards, dialogs, menus, posters). Features quick preset chips (Cuadrado 0px, Sutil 6px, Normal 10px, Redondo 16px, Curvo 22px). Fully integrated and editable in `PersonalizacionSettingsScreen`, `ThemeSettingsScreen`, and `WelcomeStepContentPreferences`. Propagated to all media cards (`AnimeCard`, `MangaCard`, `ContinueWatchingCard`, `ContinueReadingCard`), posters, episode lists (`EpisodeListItem`, `EpisodeGridItem`, `AniZipEpisodeListView`), manga chapter lists, and stream views (`OnlineStreamView`, `LocalLibraryView`, `AnimeFullDetailsScreen`).
        - **120 FPS Decoupled Slider Architecture**: To prevent frame drops and slider stutter during drag, the slider operates on a fully decoupled local state with `divisions: 24` (snapping to discrete 1px steps). `main.dart`'s `MaterialApp` is decoupled from `borderRadius` via selective `themeProvider` watching, injecting live radius changes only through an inner `builder` `Theme` wrapper without destroying or rebuilding the root Navigator or application shell. `PersonalizacionSettingsScreen` isolates the radius section into `_PersonalizacionRadiusSection`, preventing the parent 800+ line settings page from rebuilding on every drag event. Real-time visual feedback uses `setPreviewBorderRadius` (in-memory only), while disk writes (`SharedPreferences`) are debounced strictly to drag termination (`onChangeEnd`).
   3. **Extensions Recommendation & Full Marketplace Explorer**:
     - **Curated Recommendations by Language**:
       - **Spanish (`es`)**: Torrents: AnimeTosho (`animetosho-new`), NekoBT (`nekobt`). Online Streaming: AnimeAV1 (`animeav1`), JKAnime (`jkanime`). Manga: LeerCapitulo (`leercapitulo`), Capibara Traductor (`capibaratraductordev`), ManhwaWeb (`manhwaweb`).
       - **English (`en`)**: Torrents: SubsPlease (`SubsPlease-Provider`), AnimeTosho (`animetosho-new`), NekoBT (`nekobt`). Online Streaming: HiAnime (`hianime`), AnimePahe (`aq-animepahe-beta`), AnimeAV1 (`animeav1`). Manga: AsuraScans (`asurascans`), MangaDex (`mangadex`), MangaFire (`mangafire`).
     - **Category Filter Chips**: Filter recommendations directly by `Todas`, `Torrents`, `Streaming`, and `Manga`.
     - **Full Marketplace Sheet (`_showMarketplaceSheet`)**: Interactive bottom sheet allowing real-time searching through the complete 100+ marketplace extension repository, category filtering, and 1-tap installs.
  4. **AniList Integration & Completion**:
     - Clear AniList account connect button or connected status badge with AniList avatar.
     - Prominent "Comenzar a explorar" (Start exploring) completion button and "Continuar sin cuenta (Omitir)" option.
- **Developer Testing & Preview Mode**:
  - `WelcomeScreen(isDevPreview: true)` allows previewing and testing the complete onboarding wizard at any time without resetting or modifying the user's completed state.
  - Accessible directly from `SettingsScreen` under "INFORMACIÓN" ("Pantalla de Bienvenida").
  - Advanced testing tools in `AboutSettingsScreen` under "DESARROLLO & PRUEBAS" with options to test the screen or reset the onboarding flag to test fresh install runs.

### 4.6. Downloader & Offline Storage Architecture (`Aniting/Downloads/`)
- **Isolation of Working Directory vs. Downloads Directory**:
  - **Working Directory (`torrentstream.downloadDir`)**: Configurable in Streaming Settings. Used strictly as temporary cache/buffer for torrent piece assembly, online stream segments, and runtime data.
  - **Permanent Downloads Directory (`Aniting/Downloads/`)**: Dedicated, persistent user-accessible folder automatically created on disk:
    - Android: `/storage/emulated/0/Download/Aniting/Downloads/` (fallback to App Documents `/Aniting/Downloads/`).
    - Linux / Desktop: `~/Downloads/Aniting/Downloads/` (or platform standard download directory).
    - Subfolders: `Anime/aniting/Manga/` and `Anime/aniting/Anime/`.
  - Configurable / overridable in Manga/Anime settings via `downloadPreferencesProvider` (`app_custom_downloads_path`).
- **Manga Offline Metadata & Filesystem Structure**:
  - `Anime/aniting/Manga/<mediaId>_<slug>/`:
    - `metadata.json`: Serialized `MangaEntry` (title, descriptions, genres, score, status, total chapters, progress, offline flags).
    - `cover.jpg`: High-resolution local cover for 100% offline card display.
    - `banner.jpg`: Local banner image for detail screens.
    - `{provider}_{mediaId}_{chapterId}_{chapterNumber}/`: Downloaded chapter packages containing `registry.json` and page images (`1.jpg`, `2.jpg`, ...).
  - Also seamlessly recognizes direct Seanime backend chapter folders `{provider}_{mediaId}_{chapterId}_{chapterNumber}` in the root downloads directory.
  - **Android Scoped Storage & Documents Compliance (`AppStoragePaths`)**: Uses `/storage/emulated/0/Documents/Anime/aniting/` (or `/storage/emulated/0/Download/Anime/aniting/`), with automatic graceful fallback to app-internal documents directory (`getApplicationDocumentsDirectory()`) if external storage creation fails.
- **Offline Services & Integration (`MangaOfflineService`)**:
  - `getDownloadedMangaList()`: Scans disk and converts downloaded folders into standard `MangaEntry` objects.
  - `getDownloadedChapters(mediaId)`: Resolves downloaded chapters and orders them numerically.
  - `getDownloadedChapterPages()`: Reads chapter `registry.json` or local image files, returning `MangaPage` models with local `file://` / filesystem paths.
  - `getTotalMangaStorageBytes()` / `formatBytes()`: Real-time disk storage calculation for downloads.
- **Real-Time WebSocket & Server-Synchronized Manga Downloads**:
  - **WebSocket Architecture (`WsEvents`, `webSocketServiceProvider`)**: Managed singleton WebSocket service connected automatically by `ServerNotifier` when the backend transitions to online. Subscribes to events like `chapter-download-queue-updated` and `refreshed-manga-download-data`.
  - **Server-First Chapter State (`getServerDownloadedChapterIds`, `getDownloadQueueChapterIds`)**: Queries `/api/v1/manga/downloaded-chapters/:id` and `/api/v1/manga/download-queue` directly as the authoritative source of downloaded and in-flight chapters, eliminating discrepancies between filesystem locations.
  - **Extended Batch Timeout**: `SeanimeRepository.downloadMangaChapters` specifies a 5-minute `receiveTimeout` to accommodate synchronous backend page-scraping and rate-limiting delays without premature `DioException` aborts.
- **UI Integration & Offline First Experience**:
  - **`MangaCard`**: Checks `entry.localCoverPath`. If present and valid on disk, renders `Image.file` immediately without requiring internet or cache hits, with a discreet downloaded badge.
  - **`DownloadsScreen`**: Features dedicated tabs for **Anime** and **Manga**.
    - **Anime Tab**: Displays local library collection anime. Tapping opens `AnimeDetailScreen` with `initialLocalMode: true`, immediately displaying `LocalLibraryView` with only local/downloaded episodes.
    - **Manga Tab**: Displays downloaded manga. Tapping opens `MangaDetailScreen` with `fromDownloads: true`, which automatically sets `_showOnlyDownloaded: true` to display only downloaded chapters, with a filter chip to toggle all chapters if needed.
  - **`MangaDetailScreen`**: Allows 1-tap single-chapter and batch unread downloads. Features a dedicated "Solo descargados" (`FilterChip`) filter and supports `fromDownloads: true` to act as an offline-first viewer when accessed from the Downloads hub.
  - **`MangaReaderScreen` & `MangaReaderSettingsSheet`**: Resolves chapter images intelligently: for online URLs it uses `CachedNetworkImage`; for local files on disk it uses `Image.file`; for server-downloaded chapters (relative paths like `{provider}_{mediaId}_.../1.jpg`), it resolves them against the Seanime server's static `/manga-downloads/` route, providing seamless reading for downloaded chapters. Falls back to local chapter files via `MangaOfflineService` if offline. Features full dynamic icon pack theming (`AppIcons`), ensuring all controls (back, settings, chapter selector, next/prev chapter, error placeholder, end chapter card, and reading mode/status bar/toggle segments in `MangaReaderSettingsSheet`) react synchronously to the selected icon pack (`Lucide` vs `Material`).

### 4.7. Adaptive Device Layout Architecture (Mobile, Desktop & TV)
- **Modular Layout Delegate Strategy**:
  - Rather than branching with dozens of `if (isDesktop)` conditionals within a monolithic file or duplicating business logic across multiple screens, screens follow a **Layout Delegate Pattern**:
  - The orchestrator screen (e.g. `AnimeDetailScreen`) manages state, Riverpod providers, API loading (Seanime repository, AniZip, streaming providers), AniList progress updates, and playback navigation.
  - The rendering is delegated to dedicated layout widgets in `lib/presentation/widgets/anime_detail/`:
    - **Desktop Layout (`AnimeDetailDesktopLayout`)**:
      - Two-column responsive architecture centered with `maxWidth: 1580` and generous side padding (36px):
        - **Panoramic Top Hero Backdrop**: Extended 480px height with deeper darkness and multi-stop gradient. Content is pushed downward leaving generous headroom. If AniList provides no banner, falls back to the cover art stretched with full Gaussian blur (`ImageFilter.blur(sigmaX: 45, sigmaY: 45)`) to eliminate pixelation.
        - **Left Column (Fixed ~260px)**: Enlarged vertical poster card (`250x360`px) with smooth interactive hover scale (`1.025x`), elevated ambient shadow, and cyan accent glow; trailer button moved from sidebar into the primary action bar for cleaner ergonomics; metadata sidebar (Format, Status, Aired dates, Season, Average Score, Studio).
        - **Right Column (Expanded Scrollable Area)**: Bold display title; cyan genre chips; primary action bar with large pill Play button, AniList bookmark button, share button, external links (AniList and MAL), watch trailer button with tooltip (`Ver tráiler`), and stream/torrent source toggle; expandable synopsis; sub-navigation tab bar (`Episodes`, `Characters`, `Related`, `More like this`).
        - **Full Action Bar & Tabs Hover Animations**: All controls (Play pill, Bookmark, Share, Trailer, AniList/MAL pills, source toggle pills, and sub-navigation tabs) feature responsive micro-interactions: smooth scale transitions (1.04x–1.07x), background brightening, and indicator underlines.
        - **Episodes Tab Header & Hoverable Cards**:
          - `[X Episodes]` badge on the left, provider selector and dub toggle in Online mode, view mode toggle (Grid vs 2-col List), and sort order toggle.
          - **Mode 1 (Grid)**: Responsive 3-5 column cards with 16:9 thumbnail and title below. Thumbnails feature inner zoom (`1.06x`), border highlight, and a centered play icon overlay on hover.
          - **Mode 2 (List)**: Unboxed transparent 2-column cards with 220px 16:9 thumbnail on left, title + 3-line synopsis on right, with card background highlight and inner zoom on hover.
        - **Characters, Relations & Recommendations Overhaul**:
          - **Anti-Empty Pipeline**: Fixed `rawMedia` data merging in `AnimeDetails.fromJson` and `SeanimeRepository.getAnimeDetails` (with direct fallback to AniList GraphQL `https://graphql.anilist.co`), guaranteeing characters, relations, and recommendations always load reliably even when the local server is offline or not tracking the anime.
          - **Skeleton Loading State**: Replaced false-empty "No hay datos" messages during initial loading with elegant animated skeleton shimmer cards.
          - **Interactive Cards with Inner Zoom**: Character, relation, and recommendation cards feature `1.035x` scale on hover, `1.06x` image zoom (`AnimatedScale`), border transition to bright cyan (`Color(0xFF00C7FF).withValues(alpha: 0.55)`), and cyan tinted drop shadows.
          - **Instant Navigation**: Tapping related or recommended media forwards `initialEntry: AnimeEntry.fromJson(...)` to `AnimeDetailScreen.navigate`, ensuring destination detail screens immediately display cover artwork, title, format, and score without blank states.
    - **Mobile Layout (`AnimeDetailMobileLayout`)**:
      - Compact, vertically stacked single-column design optimized for touch and one-handed phone usage.
      - **Unified Primary Action Bar**:
        - Features an expanded `FilledButton.icon` for primary playback ("Continuar Ep. X" / "Comenzar a ver"), accompanied horizontally by clean icon-only buttons:
          - **Trailer**: `IconButton` (`Icons.smart_display_outlined`) launching external YouTube/Dailymotion trailers when `trailerId` is available.
          - **Favoritos**: `IconButton` (`Icons.favorite_rounded` / `Icons.favorite_border_rounded`) connected to `animeFavoritesProvider` (`SharedPreferences` backed `user_favorite_anime_ids_v1`).
          - **Editar Lista (AniList)**: `IconButton` (`Icons.edit_outlined`) launching the AniList status/score modal without square borders or clunky bounding boxes.
      - **Anchored Mode Dropdown Menu (`PopupMenuButton<String>`)**:
        - Instead of opening an intrusive center dialog, the mode chip anchors a compact, rounded (`borderRadius: 16`) popup menu right underneath the chip.
        - Displays clean, concise options without verbose paragraphs: `'Online'` and `'Torrent'` (and `'Local'` if local files exist).
      - **100% Adaptive Theme Palette & Color Harmonization**:
        - Popups (`AnimeDetailSourcePopup`), sheets (`AnimeDetailAdvancedSheet`), and menus strictly inherit the anime's dynamic palette generated by `effectiveTheme` from the poster artwork.
        - Eliminated hardcoded background colors (e.g. `Color(0xFF1E1E24)`), replacing them with `theme.colorScheme.surfaceContainerHigh`.
        - Online provider list language and DUB badges use monochrome/adaptive surface tokens, eliminating visual clutter and competing colors.
    - **TV Layout (`AnimeDetailTvLayout`)**:
      - 10-foot user interface optimized for remote control and D-Pad navigation:
      - Oversized focusable buttons with primary focus on "Continuar Viendo (Ep X)".
      - Horizontal scrollable rails eliminating small click targets.
- **Configurable Layout Mode (`layoutModeProvider`)**:
  - Located in `lib/core/preferences/layout_mode_provider.dart` with options: `auto`, `desktop`, `mobile`, `tv`.
  - Automatically resolves: screen width $\ge 900$px $\rightarrow$ `desktop`; $< 900$px $\rightarrow$ `mobile`.
  - Configurable via user preference in **Ajustes > Apariencia e Interfaz > Modo de Interfaz**.

### 4.8. Manga Reader High-Performance Pipeline (`manga_reader_screen.dart`, `MangaKeepAlivePage`)
- **Root Cause of Image Reloads / Flickering**:
  - In Flutter, `ListView.builder` (Webtoon mode) and `PageView.builder` (Paged mode) aggressively dispose offscreen item widgets and their underlying decoded bitmap memory unless wrapped in `AutomaticKeepAliveClientMixin`.
  - Flutter's default `PaintingBinding.instance.imageCache.maximumSizeBytes` is capped at only 100MB (~10 decoded 1200x2000 32-bit RGBA bitmaps). Scrolling past 10 pages caused the LRU eviction policy to purge previously seen pages, forcing re-decoding from disk/network whenever scrolling back up.
  - Previous precaching used mismatched `ResizeImage` keys (passing `maxHeight: 2000` while `CachedNetworkImage` specified `memCacheWidth: 1200`), rendering precache hits ineffectual.
- **Engine-Level Solutions**:
  1. **Dynamic ImageCache Expansion**:
     - On entering `MangaReaderScreen.initState()`, expands Flutter's `imageCache.maximumSizeBytes` to 500MB and `maximumSize` to 400 images.
     - On screen `dispose()`, gracefully restores standard limits (100MB / 1000 items).
  2. **Page State Retention with `MangaKeepAlivePage`**:
     - All chapter pages in both Webtoon (`ListView.builder`, `cacheExtent: 6000`) and Paged (`PageView.builder`) layouts are wrapped in `MangaKeepAlivePage` (in `lib/presentation/widgets/manga/manga_keep_alive_page.dart`) with unique `ValueKey` identifiers (`webtoon_page_${chapterId}_$index`).
     - Once a page is decoded and rendered, Flutter never unmounts or destroys it until the chapter changes or the user exits.
  3. **Aggressive Parallel Chapter Preloader (`_preloadEntireChapter`)**:
     - **Frame 1 Priority**: Immediately precaches the current page and next 4 pages so reading begins with 0ms latency.
     - **Background Saturating Pipeline**: Spawns a parallel background loop fetching all remaining pages in concurrent chunks of 4 (`Future.wait`) with cancellation tokens (`_precacheGeneration`) to discard pending tasks if switching chapters.
     - **Exact Cache Key Alignment**: Matches `CachedNetworkImageProvider` parameters (`maxWidth: 1200`) and resolves relative server download paths (`/manga-downloads/`) cleanly.
  4. **Proportional Placeholder Preservation**:
     - Replaced fixed-height 350px containers with proportional placeholders (`constraints.maxWidth / 0.68`), eliminating scroll viewport height jumps during image decoding.
  5. **Complete Manga Reader & Settings Internationalization (i18n)**:
     - All user-facing strings across `MangaReaderScreen`, `MangaSettingsScreen`, `MangaReaderSettingsSheet`, `MangaChapterItem`, and `MangaDetailsModalSheet` are bound to `translationsProvider` (`l10n`), supporting English and Spanish dynamically.
     - Enums `MangaReadingMode` and `MangaStatusBarMode` provide localized display labels via extension methods (`localizedName(l10n)`).
     - Subtitles for manga in floating companions and bottom docks (`FloatingResumeCompanion`, `FloatingResumeBar`) format chapters and page numbers dynamically with zero hardcoded strings.
- **Internal Torrent Downloads & Destination Architecture (`TorrentSelectorSheet`, `SeanimeRepository`, `DesktopServer`)**:
  - **Internal Built-in Client Direct Activation**:
    - Aniting uses Seanime's internal BitTorrent engine (`anacrolix/torrent`) running within the app process rather than requiring external third-party software (such as qBittorrent or Transmission).
    - `DesktopServer` automatically ensures `[experimental] builtintorrentclient = true` is set in Seanime's `config.toml` prior to launching the server sidecar.
    - `SeanimeRepository.ensureTorrentClientReady()` checks server settings (`GET /api/v1/settings`) and automatically updates `torrent.defaultTorrentClient` to `"seanime"` via `PATCH /api/v1/settings/path`.
    - Go backend (`HandleTorrentClientDownload`) has automatic fallback: if an external client is configured but unreachable (`Start() == false`), it gracefully switches `torrent.defaultTorrentClient` to `"seanime"` and starts the internal client.
  - **Automatic Destination Directory Resolution**:
    - `SeanimeRepository.resolveAnimeDownloadDestination({media})`:
      1. First checks if the show already has downloaded files in the library via `getAnimeLibraryEntry(mediaId)` and reuses its existing folder.
      2. If not yet in the library, fetches the root `libraryPath` from server settings and appends the sanitized anime title (`cleanLibPath/sanitizedTitle`), guaranteeing `destination` is never empty.
    - Go backend (`HandleTorrentClientDownload`) provides secondary fallback: if `b.Destination` is empty, it resolves the folder from `library.libraryPath` and `b.Media.GetPreferredTitle()`.
  - **Interactive Torrent Selector & Batch Improvements (`TorrentSelectorSheet`)**:
    - **Accurate Batch Discrimination**: Regex enhanced to treat patterns like `S3-04` or `S01-E12` strictly as single episodes, preventing false batch flags.
    - **Header Episode Dropdown**: Allows filtering torrents by episode number directly from the sheet header.
    - **Instant Feedback**: Interactive download action displays dynamic status feedback without overlapping snackbars.
  - **Automatic Library Indexing & Completed Torrent Scans (`active_downloads_provider.dart`, `downloads_screen.dart`, `local_library_view.dart`)**:
    - **Auto-Scan on Completion**: When a torrent download reaches 100% or enters completion/seeding state in `ActiveDownloadsNotifier`, the app automatically triggers `repo.scanLibrary()` and invalidates `downloadedAnimeProvider` and `animeCollectionProvider`. This enables Seanime's backend scanner to parse and match downloaded video files into local library entries without requiring user intervention.
    - **Manual Scan & Folder Navigation**:
      - `DownloadsScreen`: Empty state and header refresh buttons trigger `repo.scanLibrary()` and allow opening the native downloads folder via `AppStoragePaths.openDirectoryInFileManager`.
      - `LocalLibraryView`: Empty local files state includes a dedicated "Escanear Carpeta Local" button so users can immediately index newly downloaded media.
    - **Resilient Anime Library Scan & Empty Path Handling (`seanime_repository.dart`, `backend/handlers/scan.go`, `streaming_settings_screen.dart`)**:
      - `scanLibrary({bool enhanced = true})` checks whether `library.libraryPath` is configured in backend settings; if empty, it auto-patches `library.libraryPath` to `AppStoragePaths.getAnimeDownloadsDirectory()` (`~/Documents/Anime/aniting/Anime`) before requesting a scan.
      - Dispatches `{ "enhanced": true, "enhanceWithOfflineDatabase": true }` to allow title-based AniList and offline matching for untracked local video files.
      - Backend Go scanner guards against empty paths to prevent walking the server working directory (`.`) and treats unmatched local media gracefully without HTTP 500 errors.
      - Backend `HandleGetActiveTorrentList` checks for `TorrentClientRepository == nil` to prevent panic crashes on fresh/unconfigured databases.
      - `StreamingSettingsScreen` includes a dedicated Anime Library Folder UI card (`library.libraryPath`) with open-in-file-manager, restore default, and save actions.
    - **AniZip Movie Episode Resolution & UI Polish (`anizip_data.dart`, `desktop_episodes_tab.dart`, `episode_item_widget.dart`)**:
      - `AniZipData.getEpisode()` and `mainEpisodes` now include fallbacks for single-episode works and movies where TVDB classifies episodes under Season 0 (`isSpecial: true`), preventing null metadata lookups and distorted banner fallbacks in Continue Watching.
      - `DesktopEpisodesTab` suppresses generic placeholder episode flashing during initial AniZip data loading by displaying smooth skeleton loaders.
      - `EpisodeListItem` streamlines downloading state feedback to the thumbnail badge, removing duplicate trailing spinners.
- **Aniting Dedicated Storage & Data Directory Isolation (`AppStoragePaths`, `DesktopServer`, `SeanimeServerRuntime`, `backend/config.go`)**:
  - **Full Namespace & Directory Isolation**:
    - Completely eliminates shared configuration or database file collisions with the upstream Seanime app.
    - **Windows**: `%APPDATA%\Aniting\` (previously `%APPDATA%\Seanime\`).
    - **Linux/macOS**: `~/.config/aniting/` (previously `~/.config/seanime/`).
    - **Android**: Public storage `Aniting/` (previously `Seanime/`) or internal files `aniting/`.
  - **Clean Slate & Zero Cross-App Interference**:
    - No migration or automatic copying is performed from legacy `Seanime` folders. `Aniting` starts completely fresh in its own dedicated space, preventing legacy corrupted states, duplicate extension conflicts, or server settings collisions.
    - `DesktopServer` launches `seanime.exe` explicitly passing `--datadir "%APPDATA%\Aniting"`.
    - Go backend (`initAppDataDir`) defaults directly to `Aniting` and supports `ANITING_DATA_DIR`, `ANITING_SERVER_HOST`, and `ANITING_SERVER_PORT` environment variables with graceful fallback to `SEANIME_*`.
  - **Android Absolute Path Generation & Root Path Sanitization (`SeanimeServerRuntime.kt`, `SeanimeServerService.kt`, `backend/config.go`)**:
    - Pre-compiled `seanime.aar` on Android previously failed to expand `$ANITING_DATA_DIR`, resolving paths to root `/cache` and `/logs` where SELinux blocked access (`stat /cache: permission denied`).
    - `SeanimeServerRuntime.generateDefaultConfig` writes fully resolved absolute paths (`$dataDirPath/cache`, `$dataDirPath/logs`, etc.) avoiding unexpanded environment variables.
    - `SeanimeServerRuntime.patchConfigFile` automatically cleans legacy or corrupt `config.toml` files, replacing occurrences of `'/cache'`, `'/logs'`, and `$ANITING_DATA_DIR` / `$SEANIME_DATA_DIR` with the valid, writable app storage directory.
    - `SeanimeServerService` pre-creates `cache`, `logs`, `assets`, and `extensions` folders before starting the Go runtime.
    - Go backend's `expandEnvironmentValues` incorporates `expandPathWithDataDir` with a fallback mechanism that intercepts forbidden root paths (`/cache`, `/logs`, `/assets`, etc.) and safely anchors them to `dataDir`.

---

## 5. Maintenance & Development Commands

- **Run Analysis**:
  ```bash
  flutter analyze
  ```
- **Run Automated Tests**:
  ```bash
  flutter test
  ```
- **Backend Windows Build**:
  ```powershell
  pwsh backend/build_windows.ps1
  ```
- **Run App (Desktop)**:
  ```bash
  flutter run -d linux
  # or -d windows / -d macos
  ```

---

## 6. Agent Rules & Guidelines

1. **Keep `AGENTS.md` updated**: If you add, rename, or remove files, or introduce new features/rules, update this document immediately.
2. **Follow modular patterns**: Avoid dumping hundreds of lines into a single file. Break down widgets into dedicated files and folders.
3. **Verify with tests**: Always run `flutter test` and `flutter analyze` after making changes to verify regression safety.
4. **Theme Integrity**: Never hardcode accent colors or dark backgrounds; query `Theme.of(context).colorScheme` and `context.themeColors`.
5. **No Clutter**: Keep controls, buttons, and bars minimal, clean, and unobtrusive.

---

## 7. Performance Optimization Guidelines (2026-09-25)

### 7.1. Video Player (libmpv) Performance Rules
- **Linux Raster Thread Stall Fix (PR #1440)**: `packages/media_kit_video` is vendored via `dependency_overrides` with `texture_gl.cc` patched to set `MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME = 0`. Without this patch, `mpv_render_context_render` synchronously blocks Flutter's raster thread for 17-25ms per frame on 24/30fps videos (capping Flutter UI to 15-24fps). With the fix, render takes ~0.5ms and the UI runs at a smooth 60fps.
- **mpv Properties**: Use `tone-mapping=auto` (NOT `bt.2446a` which is only for `gpu-next`). Set `hdr-compute-peak=no`. Do NOT set `vd-lavc-dr=yes` (causes EGL context lockups with `media_kit`). Use `vd-lavc-threads=0` (auto-detect). Use `sub-ass-vsfilter-color-compat=basic`. Set `video-sync=display-resample` and `interpolation=no`.
- **Torrent Streaming Mode**: Distinguish local file playback from torrent HTTP streaming. Torrents use 1MB probesize, 1.5s analyze duration, `hr-seek=no` (prevents stalled unbuffered chunk requests), and 64MB cache.
- **Controls Mount/Unmount**: Player controls are wrapped in `_ControlsOverlay` which tracks `_controlsMounted` state. When controls fade out (`AnimatedOpacity.onEnd`), the widget tree is completely unmounted so `ValueListenableBuilder` stops rebuilding invisible widgets. This is critical — without this, the bottom bar rebuilds 60x/sec even when hidden.
- **Timeline-Scoped Rebuilds**: `PlayerBottomBar` receives `ValueNotifier<Duration>` for position and buffer (not raw `Duration`). Only the `TimelineSlider` and time labels are wrapped in `ValueListenableBuilder`, NOT the play/pause/seek/volume buttons.
- **Performance Stats Isolation**: `PerformanceStatsOverlay` receives a `ValueNotifier<PerformanceStats?>` instead of a raw stats object. `VideoPlayerScreen` does NOT call `setState()` for stats updates — only the overlay rebuilds.

### 7.2. AnimatedBuilder `child` Parameter Rule
- **ALWAYS** use the `child` parameter of `AnimatedBuilder` for static subtrees. The `child` is built once and passed to the `builder` callback. Only the transform/opacity/alignment wrapper should be in the `builder`.
- Applied to: `anime_detail_screen.dart` (banner breathing), `manga_detail_screen.dart` (banner breathing), and `explore_hero_carousel.dart` (Ken Burns pan).

### 7.3. Image Cache Bounds Rule
- **ALL** `CachedNetworkImage` instances MUST specify `memCacheWidth` and `memCacheHeight` (typically 2–2.5× display dp for retina). Optionally add `maxWidthDiskCache` and `maxHeightDiskCache`.
- **ALL** `Image.asset` calls MUST specify `cacheWidth` and `cacheHeight` (2× display dp).
- **ALL** `Image.file` calls MUST specify `cacheWidth` and `cacheHeight`.
- Without these, a 1920×1080 image displayed at 160×90dp decodes ~8MB of uncompressed RGBA into the 50MB image cache.

### 7.4. BackdropFilter & Blur Performance Rules
- **Wrap all `BackdropFilter` usage in `RepaintBoundary`** to isolate blur repaints from scrolling content.
- **Blur sigma budget**: Mobile ≤ 8, Desktop ≤ 12. Higher values consume exponentially more GPU fill-rate.
- **Avoid `ShaderMask` + `BackdropFilter` stacking** when possible.
- **Avoid `Opacity` widget** (forces `saveLayer`). Use `FadeTransition` or animate alpha directly.
- **`BoxShadow` budget**: Persistent on-screen widgets (nav dock, resume bar) should use `blurRadius ≤ 12`.

### 7.5. RepaintBoundary Placement Rule
- Add `RepaintBoundary` around: continuously animated widgets (Ken Burns, breathing, shimmer), `BackdropFilter` layers, and any widget that repaints at 60fps.
- Already present on: `AnimeCard`, `MangaCard`, `ContinueWatchingCard`, `ContinueReadingCard`, `LandscapeAnimeCard`, `FloatingResumeBar`, `MobileNavDock`, `Video` widget, player controls overlay, and player settings sheet.

### 7.6. Online Streaming & Extensions Resilience (2026-09-30)
- **Extended Timeout for Online Stream Sources (`seanime_repository.dart`)**:
  - `getOnlinestreamSource` now specifies `Options(receiveTimeout: const Duration(seconds: 45))` and `getOnlinestreamEpisodes`/`searchOnlinestreamManual` use `35s`. This prevents premature `DioException [receive timeout]` in Flutter when upstream hosts (like MP4Upload, Voe, UPNShare) take longer to respond or when multiple embeds are processed by Goja JS extensions.
- **Installed Extension Card Zero-Overflow (`installed_extension_card.dart`)**:
  - Switched metadata cluster (version, author, and `Actualización disponible` badge) from a responsive `Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4)`. This guarantees zero horizontal RenderFlex overflows on narrow device viewports regardless of title/author length or badge visibility.
- **Off-Screen Floating SnackBar Elimination (`extensions_marketplace_screen.dart`)**:
  - Centralized user notifications via `_showFeedback(message)` calling `messenger.clearSnackBars()`. This clears pending floating SnackBars before enqueueing new ones, preventing off-screen positioning warnings during soft keyboard or modal sheet transitions.
- **AnimeAV1 Spanish Extension Architecture**:
  - AnimeAV1 updated its upstream embeds (`UPNShare`, `Voe`, `Byse`, `MP4Upload`). Version 1.2.1+ in the official repository contains extractors for `UPNShare` and `Voe`, resolving `Error: No se encontró servidor Byse para sub` on series where Byse is not present.

### 7.7. In-App Updates & Version Management Architecture (2026-09-30)
- **Semantic Version Parser with Prerelease & Beta Tag Support (`app_update_models.dart`)**:
  - `AppUpdateInfo.isVersionNewer` accurately compares semantic version strings containing tags like `v1.0.1-beta`, `1.0.0-beta.2`, `1.0.0+2`, and stable releases.
  - Decomposes versions into `[major, minor, patch, isStable, preReleaseNum, buildNum]`, ensuring patch releases with `-beta` (e.g. `1.0.1-beta`) correctly register as newer than previous base releases (e.g. `1.0.0`), while stable releases outrank pre-releases of the same version.
- **Automatic Startup Update Check (`MainShell`, `main_shell.dart`)**:
  - When `MainShell` mounts on app startup, an asynchronous update check runs 1.5s post-frame (avoiding UI jank or slowing down feed initialization).
  - If a newer release is published on GitHub Releases, `AppUpdateDialog.show(context, info)` opens directly without requiring the user to navigate to Settings.
  - Guarded by `static bool _hasCheckedForUpdatesOnStartup` and `AppUpdateDialog._isShowing` to prevent duplicate modal prompts.
- **Device-Specific ABI Asset Resolution (`app_update_models.dart`)**:
  - Queries `Abi.current()` (`dart:ffi`) to match the exact hardware architecture of the user's Android device:
    - `arm64-v8a`: downloads `app-arm64-v8a-release.apk` (~109 MB, saving bandwidth and storage over universal builds).
    - `x86_64`: downloads `app-x86_64-release.apk`.
### 7.8. Anime Detail Desktop Refinements, Dynamic Icon Packs & Internationalization (2026-09-30)
- **Language-Aware Episode Title Resolution (`AniZipEpisode.displayTitleForLang`, `desktop_episodes_tab.dart`)**:
  - `AniZipEpisode` previously hardcoded Spanish (`titleMap['es']`) as the primary lookup in `displayTitle`, causing English users in Torrent mode to see Spanish episode titles while Online mode showed English titles.
  - Added `displayTitleForLang(String? langCode)`: when `langCode == 'en'`, it prioritizes English titles; otherwise, it prioritizes Spanish.
  - `DesktopEpisodesTab` watches `appLanguageProvider` (`ref.watch(appLanguageProvider)`) to pass the current language code to `displayTitleForLang`, ensuring episode titles match the user's selected language consistently across both Torrent and Online modes.
- **Dynamic Icon Pack Theming on Anime Detail Desktop (`desktop_action_bar.dart`, `anime_detail_desktop_layout.dart`, `desktop_episodes_tab.dart`)**:
  - All icons across the desktop detail layout (back button, action bar play/bookmark/share/trailer, online/torrent pills, local mode folder, dropdown chevrons, list/grid toggle, sort button) now consume `iconPackProvider` via `AppIcons`, adapting instantly when switching between Lucide and Material icon packs in Settings.
- **Modular Characters Tab Overhaul (`desktop_characters_tab.dart`)**:
  - Extracted the character name and role label completely outside the image box into separate text widgets below the card, aligning with `DesktopRelationsTab` and `DesktopRecommendationsTab`.
- **Subtle Card Box Expansion Architecture & Elevated Hover Shadows (All Media Cards)**:
  - Scaled hover factors tuned to a subtle, gentle expansion (`scale: 1.025` for portrait posters, `scale: 1.02` for landscape thumbnails with `Curves.easeOutCubic`, 180ms) with soft shadows (`blurRadius: 8–10`) to provide high visual polish without aggressive displacement:
    - `DesktopCharactersTab` (`_DesktopCharacterCard`): portrait card box gently expands (`1.025`), casts soft shadow, while character name and role remain cleanly positioned outside the box.
    - `DesktopRelationsTab` (`_DesktopRelationCard`): relation poster gently expands (`1.025`).
    - `DesktopRecommendationsTab` (`_DesktopRecommendationCard`): recommendation poster gently expands (`1.025`).
    - `DesktopEpisodeGridCard`: 16:9 episode thumbnail box expands smoothly (`1.025`) without intrusive play icon overlays.
    - `DesktopEpisodeListCard`: 16:9 thumbnail box expands smoothly (`1.02`) within the 2-column list row.
    - `AnimeCard` & `MangaCard`: poster box scales smoothly (`1.025`), brightens border and elevates soft shadow, while title and scores stay static below.
    - `ContinueWatchingCard` & `ContinueReadingCard`: 16:9 episode thumbnail and manga cover box expand smoothly (`1.02`).
- **Feed Carousel Zero-Clipping Architecture (`feed_screen.dart`, `manga_feed_screen.dart`)**:
  - Horizontal `ListView.builder` instances default to `clipBehavior: Clip.hardEdge` with 0 vertical padding. When card boxes scale up, their top and bottom bounds previously clipped against the `SizedBox` container.
  - Added `clipBehavior: Clip.none`, `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)`, and increased carousel container height headroom (`+ 16`), completely eliminating top/bottom clipping on hover across anime and manga feeds.
- **Adaptive Light Theme Detail Architecture (`desktop_action_bar.dart`, `desktop_episodes_tab.dart`, `desktop_episode_pagination.dart`, `anime_detail_desktop_layout.dart`, `manga_detail_desktop_layout.dart`)**:
  - Replaced hardcoded `Colors.white` and dark assumptions across desktop detail layouts with theme-aware color resolution (`isDark = theme.brightness == Brightness.dark`):
    - Back button: renders pure white over hero banner for contrast; gracefully switches to `theme.colorScheme.onSurface` when no banner is loaded or on light backgrounds.
    - Action bar buttons: play pill uses `theme.colorScheme.primary` with white icon in light mode; secondary action buttons use `colorScheme.surfaceContainerHigh` and `colorScheme.onSurfaceVariant`.
    - Mode toggle & source pills: adapt border, background, and typography for crisp contrast in light mode.
    - Episode pagination bar: container, previous/next controls, page chips, and episode range pill adapt to light theme surfaces and text colors.
    - Episodes tab filters: audio dropdown, grid/list view toggles, sort buttons, and empty/loading states adapt smoothly to light theme.
- **Official AniList & MyAnimeList Clean Brand Icons (`_HoverBrandIcon`, `desktop_action_bar.dart`, `desktop_manga_action_bar.dart`)**:
  - Replaced pill containers, borders, and text labels with clean, minimalist brand icons (`_HoverBrandIcon`). Hovering gently scales the icon (`scale: 1.14`) and illuminates opacity to `1.0`, keeping the action bar clutter-free.
- **Global Desktop Tooltip Wait Delay (`app_theme.dart`, `theme_provider.dart`)**:
  - Configured `waitDuration: const Duration(milliseconds: 700)` globally across `TooltipThemeData`. Prevents intrusive tooltips from popping up instantly upon moving the cursor across UI elements, ensuring tooltips only display when the user intentionally rests the mouse.
- **Sub-Tab Jump Elimination & Smooth Entrance Glide (`anime_detail_desktop_layout.dart`)**:
  - Fixed vertical layout snap when switching tabs: replaced default `Alignment.center` in `AnimatedSwitcher.layoutBuilder` with `Alignment.topLeft`, preventing shorter tabs from centering within previous taller tabs before snapping upwards.
  - Added smooth slide-up entrance animation (`Offset(0, 0.035) -> Offset.zero`) combined with gentle fade (`Curves.easeOutCubic`, 240ms).

### 7.9. Manga Detail PC Layout Redesign & System Theming Architecture (2026-10-01)
- **Top Horizontal Manga Information Hub (`manga_detail_desktop_layout.dart`, `desktop_manga_sidebar.dart`, `desktop_manga_header.dart`)**:
  - Replaced the previous full-height vertical sidebar with a wide panoramic horizontal info cluster at the top:
    - Left: Large cover poster (`DesktopMangaSidebar(showMetadata: false, width: 220)`) with soft elevation shadow.
    - Right: Complete manga data cluster:
      - Formato, Estado, Año, Score, and Capítulos metadata chips.
      - Large title with high contrast.
      - System-colored genre pills (`theme.colorScheme.surfaceContainerHighest`).
      - Expandable synopsis with smooth `AnimatedSize`.
      - Manga action bar (`DesktopMangaActionBar`) with "Empezar/Continuar Leyendo" pill (`theme.colorScheme.primary`), AniList status editor, batch download, share, and clean AniList/MAL brand icons.
- **Bottom Two-Column Desktop Layout (Chapters Box + Visual Grid)**:
  - Left column (`Expanded(flex: 5)`):
    - Dedicated chapters box container with header counter badge.
    - Full chapter manager: provider selector, search bar with debounce, ascending/descending sorting, hide read filter, downloaded-only filter, batch download chip, 30-chapter pagination bar, and chapter cards.
    - Zero horizontal overflow via `Wrap(spacing: 8, runSpacing: 8)` on filter chips.
  - Right column (`Expanded(flex: 6)`):
    - Characters grid ("Personajes") with name and role displayed below the poster.
    - Relations grid ("Relaciones").
    - Similar works grid ("Obras similares").
- **100% Theme-Aware System Theming (Zero Hardcoded Colors)**:
  - Purged all hardcoded blues (`0xFF00C7FF`, `0xFF02A9FF`) and hardcoded dark tones (`0xFF14171B`, `0xFF1C2026`).
  - All backgrounds, borders, chips, text styles, and icons dynamically resolve from `theme.colorScheme` and `isDark`, delivering high legibility and contrast in both Light and Dark modes.

### 7.10. Codebase-Wide Internationalization (i18n) & Spanish String Elimination (2026-10-02)
- **Elimination of Hardcoded Spanish Prompts & Fallbacks**:
  - Replaced all fallback episode and chapter titles (`'Episodio $x'`, `'Capítulo $x'`) across streaming pipelines, resolvers, player panels, and detail screens with dynamic, localized getters (`l10n.episodeNumber`, `l10n.chapterAbbr`).
  - Localized playback stream resolvers and source controllers (`player_episode_resolver.dart`, `player_source_controller.dart`, `online_stream_view.dart`, `desktop_episodes_tab.dart`, `next_episode_card.dart`).
- **Full Detail & Batch Action Localization**:
  - Localized desktop, mobile, and TV layouts for Anime and Manga details (`anime_detail_mobile_layout.dart`, `anime_detail_desktop_layout.dart`, `anime_detail_tv_layout.dart`, `manga_detail_screen.dart`, `manga_detail_mobile_layout.dart`, `desktop_manga_chapters_tab.dart`).
  - Fully translated Torrent Batch file selector sheet (`torrent_batch_files_sheet.dart`) and quality filters (`torrent_selector_sheet.dart`).
  - Localized AniList and local entry removal dialogs (`edit_entry_modal.dart`).
- **Comprehensive `AppTranslations` Contract Extensions**:
  - Expanded `translations.dart`, `en.dart`, and `es.dart` contracts with comprehensive keys for streaming modes, downloads, empty states, search hints, and confirmation dialogs.

### 7.11. 100% Spanish & English Parity Audit & Settings/Player Engine Fixes (2026-10-02)
- **Stream Auto-Track & Subtitle Language Priority (`player_playback_coordinator.dart`)**:
  - Resolved user report where streaming video defaulted or prompted in Spanish when the app was set to English.
  - Player track selection previously hardcoded Spanish audio/subs as priority #2 right before English #3, and defaulted MPV external subtitle index to 0 without checking language.
  - Refactored `PlayerPlaybackCoordinator` to detect `l10n is EnglishTranslations` and prioritize English tracks and external subtitles when the app is in English, and Spanish when in Spanish.
- **Settings Personalization & Font/Accent Localization (`theme_provider.dart`, `personalizacion_settings_screen.dart`, `theme_settings_screen.dart`, `welcome_step_theme.dart`)**:
  - Resolved user report where settings options displayed in Spanish.
  - Converted `currentFont.displayName` (`'Sistema'`) to `currentFont.localizedDisplayName(l10n)`.
  - Added localized descriptions for all 7 typography options (`AppFontOption.localizedDescription(l10n)`).
  - Added localized accent color names (`AppAccentColor.localizedName(l10n)`) for tooltips across settings and onboarding.
- **AniList Auth Error Localization & Error Sentinel Mapping (`seanime_repository.dart`, `anilist_auth_sheet.dart`)**:
  - Replaced hardcoded Spanish exception messages in `seanime_repository.dart` with standardized error sentinel identifiers (`RATE_LIMIT`, `TIMEOUT`, `INVALID_TOKEN`, `NETWORK_ERROR`).
  - Mapped sentinels in `anilist_auth_sheet.dart` to `l10n.anilistRateLimitError`, `l10n.anilistTimeoutError`, `l10n.anilistInvalidTokenError`, and `l10n.anilistConnectionError`.
- **Complete UI Parity Across All Residual Strings**:
  - Localized desktop episode pagination (`desktop_episode_pagination.dart`), desktop episode list card fallback description (`desktop_episode_list_card.dart`), character roles (`desktop_characters_tab.dart`, `desktop_manga_characters_section.dart`), downloaded chapter labels (`manga_detail_screen.dart`), library headers (`library_screen.dart`), home screen server offline states (`home_screen.dart`), resume bar labels (`floating_resume_bar.dart`), and update failure toasts (`app_update_provider.dart`, `app_update_service.dart`).
  - Verified 100% parity across English and Spanish translations with `flutter analyze` (0 issues).


### 7.12. AniZip Language-Aware Episode Metadata, Section Toggle, Explore Skeleton & Theme Redesign (2026-10-02)
- **Language-Aware AniZip Episode Titles (`anizip_data.dart`, `seanime_repository.dart`, `offline_library_service.dart`, `anizip_episode_list.dart`, `continue_watching_card.dart`, `local_library_view.dart`)**:
  - Previously, `AniZipEpisode.displayTitle` (no-arg getter) was hardcoded to `displayTitleForLang('es')`, causing episode titles to always display in Spanish regardless of the user's selected app language.
  - All call sites that used `.displayTitle` on `AniZipEpisode` instances were systematically updated to use `.displayTitleForLang(langCode)` where `langCode` is derived from `appLanguageProvider` (`'en'` for English, `'es'` for Spanish).
  - `getContinueWatching()` in `seanime_repository.dart` and `offline_library_service.dart` now accept an optional `String? langCode` parameter to pass through to AniZip title resolution.
  - Widgets (`anizip_episode_list.dart`, `continue_watching_card.dart`, `local_library_view.dart`) now watch `appLanguageProvider` and pass the correct language code for episode title rendering.
- **Anime/Manga Section Visibility Toggle (`section_visibility_provider.dart`, `main_shell.dart`, `personalizacion_settings_screen.dart`)**:
  - New `AnimeSectionEnabledNotifier` and `MangaSectionEnabledNotifier` providers (`lib/core/preferences/section_visibility_provider.dart`) following the `_cachedPrefs` pattern for synchronous 0ms startup hydration.
  - `MainShell` dynamically builds `availablePages`, `sidebarItems`, and `desktopSidebarItems` lists, filtering out disabled sections. `IndexedStack`, `FloatingDockPill`, `MobileNavDock`, and classic `NavigationBar` all respect the dynamic page set.
  - `FloatingDockPill` updated to support `targetIndex` mapping for correct selection state with filtered navigation items.
  - `SearchScreen` and `MediaTypeToggle` respect section visibility: if Anime is disabled, defaults to Manga mode and vice versa.
  - Settings toggle in Personalización with guard preventing both sections from being disabled simultaneously.
- **Explore Screen Shimmer Skeleton Placeholders (`explore_skeleton.dart`, `search_screen.dart`)**:
  - Created `ExploreSkeleton` widget (`lib/presentation/widgets/explore_skeleton.dart`) rendering shimmer placeholders matching the Explore screen layout: hero carousel placeholder (exact dimensions `(isDesktop ? 340.0 : 260.0) + topPadding`), header controls row, genre chips row, and 2-3 curated section card rows.
  - Uses the canonical app shimmer pattern: `AnimationController(1400ms, repeat reverse)`, opacity `0.18–0.46`, `surfaceContainerHighest` color, wrapped in `RepaintBoundary`.
  - Exported `CuratedSectionRowSkeleton` for individual section loading states.
  - `search_screen.dart` updated: when trending data is loading, renders the full `ExploreSkeleton` instead of `SizedBox.shrink()`, completely eliminating the CLS jump. Curated sections also render `CuratedSectionRowSkeleton` during loading instead of collapsing to 0 height. Anime ↔ Manga toggle transitions show skeleton during data fetch.
- **Theme Settings Alignment with Setup Wizard & Material You Localization (`theme_settings_screen.dart`, `app_palette.dart`, `welcome_step_theme.dart`)**:
  - Aligned `ThemeSettingsScreen` 1:1 with the clean, polished visual aesthetic of the Setup Wizard (`welcome_step_theme.dart`):
    - **Mode**: 3 cards with the graphical mini window mockup preview (`_buildThemeModeGraphic`) for Dark, Light, and System modes.
    - **Icon Pack**: Side-by-side cards for Lucide Web and Material Symbols with preview row and checkmark badges.
    - **Accent Color**: Horizontal row of circular accent swatches with glow border and active checkmark.
    - **Community Palettes**: Clean segmented tabs (`Dark Themes`, `Light Themes`, `Material Design 3`) with vertical list of clean pill-shaped tiles showing circular color preview dot and trailing radio/check state.
    - **Extras**: Preserved OLED True Black and Dynamic Anime Theme switches alongside the Expressive M3 Corner Radius slider.
  - **Material You & System Palette Localization**:
    - Added `localizedName(AppTranslations l10n)` to `AppThemePalette` and contracts in `translations.dart`, `en.dart`, and `es.dart`.
    - Localized names for all Material Design 3 palettes in English (`Material You Violet`, `Ocean`, `Forest`, `Sunset`, `Raspberry`, `Teal`) and Spanish (`Material You Violeta`, `Océano`, `Bosque`, `Atardecer`, `Frambuesa`, `Turquesa`), resolving the issue where English UI displayed Spanish palette names.

### 7.13. Smooth Shell Page Switch Transitions & Robust Navigation Indexing (2026-10-02)
- **Fluid Shell Page Entrance Animations (`ShellAnimatedIndexedStack`, `main_shell.dart`)**:
  - Created `ShellAnimatedIndexedStack` (`lib/presentation/widgets/shell_animated_indexed_stack.dart`) wrapping `IndexedStack` with synchronized `FadeTransition` (0.0 -> 1.0) and subtle vertical glide `SlideTransition` (`Offset(0, 0.015) -> Offset.zero`, 240ms `Curves.easeOutCubic`).
  - Preserves 100% of state, scroll offsets, and active controllers across all pages while delivering a smooth, premium animated transition whenever the user navigates between tabs from the Desktop Sidebar, Mobile Floating Nav, or classic NavigationBar.
  - Keeps inactive tabs wrapped in `TickerMode(enabled: isCurrent)` to freeze background tickers and eliminate unnecessary CPU/GPU usage.
- **Robust Section Deactivation & Index Bounds Protection (`main_shell.dart`, `ShellSection`)**:
  - Replaced brittle numeric index assumptions with `ShellSection` enum (`anime`, `manga`, `explore`, `calendar`, `profile`).
  - `MainShell` maintains `ShellSection _activeSection`, filtering `availableSections` dynamically.
  - Automatically sanitizes `_activeSection` to `availableSections.first` when the currently viewed section is deactivated, and resolves `activeIndex = availableSections.indexOf(_activeSection).clamp(0, availableSections.length - 1)`.
  - Completely eliminates the `The index must be null or within the range of children` assertion crash that occurred when disabling sections.
- **Theme Mode Mini Mockup RenderFlex Overflow Fix (`theme_settings_screen.dart`, `welcome_step_theme.dart`)**:
  - Fixed 1.1px vertical RenderFlex overflow on high-density / fractional font scale mobile screens (e.g. Infinix X6837) by increasing mini window container height from 54dp to 58dp and trimming internal padding in `_buildThemeModeGraphic`.
- **Floating SnackBar Collision Clearance (`personalizacion_settings_screen.dart`)**:
  - Added `messenger.clearSnackBars()` prior to displaying `cannotDisableBothSections`, preventing floating snackbar positioning exceptions during active settings navigation.

### 7.14. Subtitle Customization Parity, Torrent Stream Auto-Pause & Active Downloads Hub (2026-10-03)
- **Subtitle Styling & MPV Color Format Correction (`subtitle_style_preferences_provider.dart`, `mpv_player_service.dart`, `ExoPlayerPlugin.kt`)**:
  - Fixed MPV hex color serializer: aligned with MPV's standard `#RRGGBBAA` CSS color format (previously `#AARRGGBB` which inverted alpha with color channels, causing black/colored borders and text to render 100% transparent and invisible on mobile).
  - Improved ASS subtitle override mode: switched from destructive `force` (which stripped dialogue positioning glyphs) to non-destructive `yes` in MPV, preserving subtitle typesetting while applying user font, size, and color overrides.
  - Added mobile font fallback mapping for Android system font compatibility (`sans-serif`, `serif`, `monospace`), preventing font resolution errors on mobile.
- **Torrent Stream Auto-Pause on Video Exit (`video_player_screen.dart`, `streaming_preferences_provider.dart`, `seanime_repository.dart`, Go backend)**:
  - Added new setting: **Pausar descarga al salir del video / Pause torrent download on exit** (enabled by default).
  - When leaving video playback while streaming a torrent, downloading is automatically halted without deleting or dropping the torrent or downloaded chunks from disk.
  - Implemented `/torrentstream/pause` and `/torrentstream/resume` in the Go backend (`stream.go`, `routes.go`, `torrentstream.go`), safely deprioritizing file pieces while preserving all downloaded content until the user selects another torrent.
  - **Pixel UI Unification for Downloads Screen (`downloads_screen.dart`, `active_downloads_tab.dart`)**:
    - Refactored `DownloadsScreen` to strictly adhere to the `PixelSubpageScaffold` architecture:
      - On PC / Tablet (dual-pane master-detail, `isEmbedded: true`): renders centered within `maxWidth: 820`, with `PixelPageHeader(title: "Descargas", showBackButton: false)`, matching 100% of all other settings subpages.
      - On Mobile (standalone push, `isEmbedded: false`): renders with the M3/Pixel fluid collapsing header `_PixelSubpageHeaderDelegate` and circular back button.
    - Added expressive M3/Android 16 segmented pill tab bar (`[ Descargas activas | Anime | Manga ]`) with animated indicators, font styling, and real-time numeric badges (`activeCount`, `animeCount`, `mangaCount`).
    - Standardized all sub-widgets inside `active_downloads_tab.dart`, anime tab, and manga tab with `PixelCardContainer`, `SettingsSectionHeader`, and smooth `GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics())` to eliminate nested viewport conflicts and preserve seamless single-axis scrolling.
  - Complete internationalization across all three i18n contracts (`translations.dart`, `en.dart`, `es.dart`).

### 7.15. Subtitle Style Architecture Parity & MPV ASS Engine Overhaul (2026-10-04)
- **libmpv ASS Subtitle Styling & Scaling Pipeline (`mpv_player_service.dart`, `subtitle_style_preferences_provider.dart`, `player_viewport.dart`)**:
  - **Correct MPV ARGB Hex Serialization (`toMpvHexColor`)**:
    - Aligned with mpv's native color parser: ARGB hex format `#AARRGGBB` (`#$a$r$g$b`), where the first two digits represent the alpha channel.
    - Corrects the previous `#RRGGBBAA` bug that caused opaque black borders (`0xFF000000` -> `#000000FF`) to be parsed with `alpha: 00` (100% transparent/invisible) and tinted colors into inverted hues.
  - **Dynamic ASS Subtitle Scaling & Override Modes**:
    - **Script Preservation with Dynamic Scaling (`sub-ass-override=scale`)**: When `overrideAss == false`, mpv keeps the fansub/author's fonts, colors, and styling, while applying `sub-scale = ${prefs.fontSizeMultiplier}`. This allows users to smoothly resize ASS subtitles using the font size slider without destroying fonts or styling.
    - **Full User Override (`sub-ass-override=force`)**: When `overrideAss == true`, mpv forces all user-configured styles (`sub-font`, `sub-font-size`, `sub-scale`, `sub-color`, `sub-back-color`, `sub-border-color`, `sub-border-size`, `sub-shadow-color`, `sub-shadow-offset`, `sub-bold`, `sub-italic`) onto ASS subtitles.
    - Added real-time property application with robust async error handling, logging, and automatic style re-application upon opening new media files.
  - **Platform Specialization (ExoPlayer vs libmpv)**:
    - **ExoPlayer (Android)**: Renders ASS subtitles natively via `libass-android` preserving script typesetting without applying destructive overrides, while applying user font, size, and color preferences to plain subtitles (SRT, VTT) via `standardSubtitleView`.
    - **libmpv (Desktop/Windows)**: Supports both dynamic font scaling (`scale`) and full styling overrides (`force`) for ASS and plain text subtitles.

### 7.16. Dedicated Download Manager, Download History, Feed Sections & Subtitle Anti-Aliasing (2026-10-04)
- **Dedicated Download Manager Screen (`download_manager_screen.dart`, `downloads_screen.dart`)**:
  - Separated active download progress from downloaded offline media: `DownloadsScreen` now strictly hosts offline downloaded Anime and Manga libraries across 2 clean tabs (`Anime`, `Manga`) with a prominent launcher card to the Download Manager.
  - `DownloadManagerScreen` provides a high-density, real-time dashboard displaying active torrent streams, qBittorrent downloads, and manga downloads in vibrant full-color cards with download speed (`MB/s`), upload speed (`MB/s`), ETA / time remaining, downloaded vs total sizes, and pause/resume/delete actions.
  - **Resilient Torrent Metrics Parsing (`download_manager_screen.dart`, `active_downloads_provider.dart`)**: Safely handles Seanime backend payloads where `size` and `eta` are formatted strings (e.g., `"1.5 GiB"`, `"12m 30s"`) or raw integers, and speeds can come via `downSpeed`, `downloadSpeed`, or `dlspeed`, completely preventing `TypeError` crashes during widget builds and auto-scan background detection.
  - **Dimmed Download History (`download_history_provider.dart`, `opacity: 0.76`)**: Records all completed anime and manga downloads with timestamps and file sizes, backed by persistent local storage (`download_history_items_v1`) with clear history confirmation dialogs.
- **Downloaded Content Sections in Anime and Manga Feeds (`feed_screen.dart`, `manga_feed_screen.dart`)**:
  - In `feed_screen.dart`: Added a horizontal carousel for "Descargas de anime" (downloaded anime) querying `downloadedAnimeProvider` right below Continue Watching, with a "Ver todo" header action navigating to `DownloadsScreen(initialTabIndex: 0)`.
  - In `manga_feed_screen.dart`: Added a horizontal carousel for "Descargas de manga" (downloaded manga) querying `downloadedMangaListProvider` right below Continue Reading, with a "Ver todo" header action navigating to `DownloadsScreen(initialTabIndex: 1)`.
  - Added "Gestor de descargas" quick navigation tile in `library_screen.dart`.
- **ExoPlayer Plain Text Subtitle Anti-Aliasing & Rendering Quality (`ExoPlayerPlugin.kt`, `player_viewport.dart`)**:
  - Eliminated the double-rendering artifact where Android's native `standardSubtitleView` (using Canvas miter strokes) and Flutter's `PlayerViewport` both rendered subtitles simultaneously. Native `standardSubtitleView` is kept hidden (`GONE`) and dormant, allowing Flutter's high-performance anti-aliased font engine to render plain subtitles (SRT, VTT) smoothly.
  - Softened text outline shadows in `PlayerViewport` with adaptive `blurRadius: math.max(1.0, bSize * 0.5)` to eliminate stair-stepped jagged edges on all screen densities.
- **Full Internationalization (i18n)**:
  - Added new keys in `translations.dart`, `en.dart`, and `es.dart`: `downloadManager`, `downloadManagerDesc`, `downloadHistory`, `noDownloadHistory`, `noDownloadHistoryDesc`, `clearHistory`, `clearHistoryConfirm`, `timeRemaining`, `etaLabel`, `downloadedAnimeSection`, `downloadedMangaSection`, `activeDownloadsCount`, `completedDownload`, `viewAll`.

### 7.17. Torrent UX Overhaul, Download Manager Navigation, Icon Pack Parity & Manga Discovery (2026-10-04)
- **Torrent Download Immediate Feedback & Auto-Close (`torrent_selector_sheet.dart`)**:
  - Tapping the download button on any single or batch torrent immediately dismisses the modal bottom sheet (`Navigator.pop(context)`), preventing the UI from freezing or feeling unresponsive.
  - Instantly displays a persistent floating SnackBar with a progress spinner announcing `"Descargando Episodio X..."` and a direct action button to open the Download Manager (`DownloadManagerScreen`).
  - Completely removed the redundant and confusing folder open icon button (`Icons.folder_open_rounded`) that was rendered on every single torrent card.
- **Mobile Episode Long-Press Action Hub (`episode_item_widget.dart`, `anizip_episode_list.dart`, `online_stream_view.dart`, `anime_detail_mobile_layout.dart`)**:
  - Enhanced `showEpisodeDetailModal` with a dedicated "Descargar" (Download) button equipped with `AppIcons.download(iconPack)`.
  - Wired `onDownload` callbacks across `EpisodeListItem` and `EpisodeGridItem` in both Online Streaming and Torrent mode, enabling users on mobile to download any episode immediately from the long-press preview modal.
- **Download Manager Folder Navigation & Completed Torrents Separation (`download_manager_screen.dart`)**:
  - Added an `AppIcons.folderOpen(iconPack)` button in the Download Manager top summary header that opens the user's downloads folder directly in the system file manager via `AppStoragePaths.openDirectoryInFileManager`.
  - Separated completed / seeding torrents from truly active downloads: Torrents at 100% (`progress >= 0.999`, `status == 'seeding'`, or `status == 'completed'`) no longer clutter the "En progreso" (Active Downloads) section. Instead, they are neatly displayed in a dedicated "Completadas y Seeding" section with completion checkmarks, seeding status, upload metrics, and pause/delete actions.
  - Top active count badge counts only downloads that are actively downloading or queued.
- **Server Manga Downloads Discovery Bug Fix (`app_providers.dart`)**:
  - Fixed a critical type-mismatch bug in `downloadedMangaListProvider` where Seanime's nested `downloadData['downloaded'][providerId]` structure was treated as a flat map of lists, causing `downloadedCount` to remain 0 and omitting downloaded manga from the Downloads screen.
  - Server-downloaded manga chapters are now discovered and displayed in the Manga downloads tab.

### 7.18. Download Management Enhancements, Android Storage Introspection & Inline Download Feedback (2026-10-04)
- **In-App Download Deletion (`downloads_screen.dart`, `local_library_view.dart`, `seanime_repository.dart`, `api_endpoints.dart`)**:
  - Added full download deletion support across the application for both anime and manga:
    - In `downloads_screen.dart`: Long-pressing or tapping the subtle delete button on any downloaded anime or manga card opens a confirmation dialog. Confirming removes local files from disk (via `localFiles` or `MangaOfflineService.deleteEntireManga`), invokes backend deletion endpoints (`DELETE /api/v1/library/local-files` and `DELETE /api/v1/manga/download-chapter`), and cleans up parent directories.
    - In `local_library_view.dart`: Users can delete individual local anime episodes via a confirmation dialog that triggers `deleteLocalFiles`, disk removal, and automatic library re-scan.
    - In `episode_item_widget.dart`: The mobile long-press episode modal (`showEpisodeDetailModal`) displays a red delete button when `onDelete` is supplied.
  - Added new mandatory i18n keys: `deleteDownload`, `deleteDownloadConfirm`, `downloadDeleted`, `deleteEpisodeDownloadConfirm`.
- **Android File Manager Integration (`MainActivity.kt`, `app_storage_paths.dart`)**:
  - Implemented the `"openDirectory"` method in `MainActivity.kt`'s `MethodChannel` (`com.anyyting.aniting/server`).
  - Utilizes `DocumentsContract.buildRootUri` / `DocumentsContract.buildDocumentUri` targeting primary external storage to launch the Android DocumentsUI file manager directly in the downloads folder (`Aniting/Downloads`), with fallbacks to `ACTION_VIEW` FileProvider and `DownloadManager.ACTION_VIEW_DOWNLOADS`.
- **Inline Episode Download Spinner & Zero-SnackBar UX (`torrent_selector_sheet.dart`, `episode_item_widget.dart`, `active_downloads_provider.dart`, `anizip_episode_list.dart`, `online_stream_view.dart`)**:
  - Completely removed the disruptive floating SnackBar when initiating a download. The torrent selector modal closes immediately (`Navigator.pop`).
  - Created `downloadingEpisodesProvider` (`DownloadingEpisodesNotifier`) in `active_downloads_provider.dart` tracking active download keys (`"${mediaId}_${episodeNumber}"`).
  - `EpisodeListItem` and `EpisodeGridItem` render a sleek inline circular progress indicator (`CircularProgressIndicator(strokeWidth: 2)`) on the right of the episode card while downloading, auto-clearing when completed or refreshed.

### 7.19. Priorización Automática de Modo Local e Indicadores de Progreso en Episodios (2026-10-04)
- **Priorización Automática de la Carpeta Local (`anime_detail_screen.dart`, `anime_detail_mobile_layout.dart`, `anime_detail_tv_layout.dart`, `anime_detail_desktop_layout.dart`)**:
  - Al abrir los detalles de un anime con episodios descargados, la aplicación prioriza de inmediato el modo y la carpeta local (`isLocalMode = true`) desde el primer instante (frame 0), evitando mostrar por defecto los proveedores en línea o torrents si el usuario ya dispone del contenido descargado.
  - Los usuarios mantienen el control manual en todo momento para alternar libremente entre modos (Local, Online, Torrent).
- **Indicadores de Descarga en Tiempo Real en Listas de Episodios (`episode_item_widget.dart`, `anizip_episode_list.dart`, `online_stream_view.dart`, `desktop_episodes_tab.dart`, `active_downloads_provider.dart`)**:
  - Las listas de episodios de AniZip, Online y Desktop muestran el estado exacto de cada episodio:
    - Indicador visual de descarga en progreso con spinner circular y porcentaje sincronizado con el cliente torrent (`downloadingEpisodesProvider`).
    - Distintivo e indicador de episodio descargado localmente con verificación instantánea.
- **Reproducción Inmediata de Contenido Descargado (`anime_detail_mobile_layout.dart`, `anime_detail_tv_layout.dart`, `online_stream_view.dart`)**:
  - Al pulsar o reproducir un episodio descargado desde cualquier lista (incluso en vistas AniZip u Online), se reproduce automáticamente el archivo local sin búfer ni depender de conexión a internet.
- **Internacionalización Completa (i18n)**:
  - Añadidas las traducciones correspondientes en `translations.dart`, `en.dart` y `es.dart` (`downloading`, `downloaded`).
### 7.21. Selector Desplegable Expressivo M3 & Optimización de Salida del Reproductor (2026-10-05)
- **Componente `M3ExpressiveSelect` con Dinámica Spring Pop & Tamaño Intrínseco**:
  - Reemplazo de desplegables nativos por un selector flotante Material 3 Expressive inspirado en Shadcn / Radix UI.
  - Apertura con dinámica de resorte y ligero rebote (`ScaleTransition` 0.88 ➔ 1.03 ➔ 1.0 con `SlideTransition` vertical).
  - Eliminado el ancho forzado artificial; la caja ahora se ajusta naturalmente al texto con padding simétrico y altura de 32px. El menú flotante iguala exactamente el ancho del botón activador.
  - Filas de opciones homogéneas (34-36px) con micro-hover y checkmark `✓` activo.
- **Eliminación de Trabón/Lag al Salir del Reproductor de Video (`video_player_screen.dart`, `player_window_manager.dart`)**:
  - Eliminada la invalidación síncrona de caché (`continueWatchingProvider`) que bloqueaba el hilo UI durante el cierre del reproductor. Ahora se ejecuta de forma diferida en un microtask asíncrono.
  - Eliminado `PaintingBinding.instance.imageCache.clear()` que purgaba la memoria de miniaturas de episodios obligando a recodificarlas desde cero al volver a la pantalla de detalles.
  - Eliminado el retraso artificial de 100ms en escritorio dentro de `handleExit`, permitiendo un pop inmediato a 120 FPS.

### 7.22. Simplificación de Temas (Claro / Oscuro / OLED) y Estandarización Liquid Glass con `g1455` (2026-10-09)
- **Simplificación del Sistema de Temas (`theme_settings_screen.dart`, `welcome_step_theme.dart`)**:
  - Depurado el selector de temas reduciendo las opciones a únicamente 3 modos fundamentales y limpios: **Modo Claro**, **Modo Oscuro** y **Modo OLED** (Negro puro `#000000`).
  - Eliminadas las listas y pestañas abigarradas de paletas comunitarias redundantes, dejando una interfaz despejada y directa.
  - Mantenido el selector horizontal de color de acento para personalizar bordes e indicadores de forma sutil y elegante sin alterar la sobriedad del fondo.
- **Estandarización Canónica de Vidrio Líquido con `package:g1455` (`https://g1455.plugfox.dev/SKILL.md`)**:
  - **Selector de Fuentes de Streaming Online (`desktop_episodes_tab.dart`)**:
    - Reemplazado el modal flotante opaco por `GlassMenuAnchor` + `GlassMenuItem` + `GlassButton` nativo de `g1455`.
    - Apertura descendente fluida morphing directamente desde el botón activador cuando hay espacio vertical disponible en pantalla.
  - **Menú Contextual de Episodios en Escritorio (`desktop_episode_context_menu.dart`)**:
    - Reestructurado el diálogo contextual para usar directamente `GlassCard` de `g1455` con animación spring pop (`Curves.easeOutBack`, escala 0.88 ➔ 1.0).
    - Eliminado el envoltorio redundante de `BackdropFilter` y fondos sólidos opacos (`alpha: 0.94`), adaptando el contraste tanto para Modo Claro (texto `black87` con micro-hover `alpha: 0.07`) como Modo Oscuro (texto `white` con micro-hover `alpha: 0.12`).
  - **Modal de Edición y Popovers (`edit_entry_modal.dart`, `edit_entry_status_dropdown.dart`)**:
    - Eliminados `BackdropFilter` redundantes que causaban sobre-desenfoque y contenedores blancos opacos de alto alpha que ocultaban la refracción líquida.
    - Los selectores de estado ahora aprovechan directamente la superficie `GlassSurface` provista por `GlassPopoverAnchor`.

