# Plan de integración TMDB (Series y Películas)

> Estado: **Fases 0–3 implementadas y TMDB activado por defecto**. Fase 4 parcial (pestaña propia de Series) y Fase 5 con tests base.
> Objetivo: TMDB deja de ser "una pestaña que se activa" y pasa a ser una fuente de primera clase que reutiliza los mismos componentes que Anime (detalle, episodios, reproductor, feed, progreso).

---

## 0. Veredicto rápido

> **Resuelto**: los 5 bloqueos que había al principio (proveedores, `canStreamOnline`, `isTmdbMedia`, progreso a AniList y reanudación sin contexto) ya están cableados. La sección de Series se activa por defecto.

**No era solo activarlo.** Activar `showsSectionEnabledProvider` te da:

- La pestaña **Series** dentro de **Explorar** (trending / populares / mejor valoradas / búsqueda).
- El detalle TMDB con metadatos, temporadas y episodios.
- Recomendaciones TMDB en el feed **solo si ya estás viendo algo de TMDB**.

Pero **no** te da reproducción online ni progreso correcto:

1. Las pantallas de detalle **saltan la carga de proveedores** cuando `isTmdb` es true.
2. `EpisodesNotifier` marca `canStreamOnline: false` para TMDB.
3. Ningún caller pasa `isTmdbMedia: true` al reproductor, así que el backend recibe una petición AniList con un ID de TMDB.
4. El progreso se envía a **AniList** con el ID de TMDB y se guarda en la biblioteca local **sin** `isTmdb`.
5. "Seguir viendo" y la barra flotante reanudan sin contexto TMDB.

El backend Go ya está listo (`GetTmdbEpisodeSources`, `supportsTmdb`, cachés namespaced `tmdb_*`). **Todo el trabajo pendiente es Flutter.**

---

## 1. Lo que ya existe (no rehacer)

| Pieza | Archivo | Estado |
| :--- | :--- | :--- |
| Cliente TMDB completo | `lib/data/services/tmdb_service.dart` | Listo |
| Modelos TMDB + `toAnimeDetails()` | `lib/data/models/tmdb_models.dart` | Listo (`isTmdb: true`) |
| API key con default editable | `lib/core/preferences/tmdb_preferences_provider.dart` | Listo |
| Providers trending/populares/top/recs | `lib/presentation/providers/app_providers.dart` | Listo |
| Explorar con tipo `SHOWS` | `lib/presentation/screens/search_screen.dart` | Listo |
| Detalle TMDB | `lib/presentation/screens/anime_detail_screen.dart` | Parcial |
| Episodios TMDB | `lib/presentation/providers/episodes_provider.dart` | Parcial |
| Reproductor con parámetros TMDB | `lib/presentation/screens/video_player_screen.dart` | Listo (nadie los pasa) |
| Source controller TMDB | `lib/presentation/widgets/player/services/player_source_controller.dart` | Listo |
| Backend TMDB onlinestream | `backend/internal/onlinestream/repository_tmdb.go` | Listo |
| Flag `supportsTmdb` en proveedores | `lib/data/models/onlinestream_models.dart` | Listo |
| Toggle de sección | `lib/core/preferences/section_visibility_provider.dart` | Listo, default `false` |

---

## 2. Gaps reales (ordenados por impacto)

### G1 — Los layouts de detalle desactivan proveedores para TMDB
`lib/presentation/widgets/anime_detail/anime_detail_desktop_layout.dart:179`

```dart
if (!widget.isMediaServerMode && !isTmdb) { ... _loadOnlineProviders(); }
```

`lib/presentation/widgets/anime_detail/anime_detail_mobile_layout.dart:127` hace `if (isTmdb) return;`.
Resultado: `_providers` vacío, `_selectedProvider` null, no hay reproducción online.

### G2 — `EpisodesNotifier` nunca habilita streaming en TMDB
`lib/presentation/providers/episodes_provider.dart:395-404` termina con `canStreamOnline: false` y sin `compatibleProviders`. Además no filtra por `supportsTmdb`.

### G3 — El reproductor nunca recibe `isTmdbMedia`
`lib/presentation/screens/video_player_screen.dart:877` usa `getIsTmdb: () => widget.isTmdbMedia`, pero ningún caller pasa `isTmdbMedia: true`. Los 22 `VideoPlayerScreen.route(...)` no lo incluyen.

### G4 — Películas TMDB se resuelven como serie
`_loadTmdbEpisodes` llama `getShowDetails(state.mediaId)` con `isMovie: false` por defecto. Para una película eso pega al endpoint `/tv/<id>` (puede traer **otra serie** con el mismo ID numérico, o fallar).

### G5 — El progreso TMDB se envía a AniList
`lib/presentation/widgets/player/services/player_progress_manager.dart:273-299` llama `repository.updateAnimeProgress` y `OfflineSyncService.enqueueAnimeProgress` sin comprobar `isTmdb`.

### G6 — `recordAnimeWatch` / `updateAnimeProgress` no reciben `isTmdb`
`lib/data/services/offline_library_service.dart:167` y `:254`. Las entradas TMDB quedan como AniList, contaminando biblioteca, recomendaciones y "Seguir viendo".

### G7 — Reanudación sin contexto TMDB
`lib/presentation/widgets/continue_watching_playback_launcher.dart` y `lib/presentation/widgets/floating_resume_bar.dart` pasan `mediaId` pero no `tmdbMediaType/season/englishTitle/year`; tampoco `isTmdbMedia`.

### G8 — El feed online oculta el progreso TMDB
`continueWatchingProvider` (`app_providers.dart:485`) en modo online solo devuelve continuidad del backend (AniList). Las entradas TMDB locales solo aparecen offline.

### G9 — Sin filas TMDB propias en el feed
Solo hay recomendaciones TMDB contextuales (`isWatchingTmdb`). No hay filas "Tendencias en series" ni "Populares en series" aunque los providers existen.

### G10 — El toggle promete una pestaña que no existe
`es.dart:2493`: "Mostrar pestaña de series TMDB en la navegación". `main_shell.dart:230-238` solo usa `showsEnabled` para habilitar/deshabilitar la home de anime. No hay `ShellSection.shows`.

### G11 — Colisión de IDs AniList vs TMDB
`_animeEntries` (`OfflineLibraryService`), `playbackProgressPreferences` y `LastSession` están indexados solo por `mediaId`. Un AniList ID y un TMDB ID iguales colisionan. `isTmdb` ayuda a distinguir, pero no a separar claves.

### G12 — Sin cobertura de pruebas TMDB
No hay tests de mapeo, episodios, progreso ni navegación TMDB.

---

## 3. Fases de ejecución

### Fase 0 — Activación honesta (bajo riesgo, ~1 h) ✅

- [x] Verificar que el toggle persiste y que `showsSectionEnabledProvider` arranca en `false` sin datos.
- [x] Corregir el copy del toggle para que describa lo que hace hoy (o dejarlo si se implementa G10 en Fase 4):
      `showsSectionDesc` → "Mostrar series de TMDB en Explorar y recomendaciones".
- [x] Preflight de API key: si faltan datos o fallan los tres feeds, Explorar → Series muestra una tarjeta accionable en vez de quedarse vacío.
- [x] Confirmar que todos los entries de TMDB llegan con `isTmdb: true` (`_mapTmdbToAnimeEntry` ya lo hace).
- [x] Añadir el fallback `isTmdbMedia || animeDetails.isTmdb` en el reproductor.

**Aceptación:** con el toggle apagado nada cambia; encendido, Explorar → Series muestra contenido y el detalle abre con metadatos, sin excepciones.

---

### Fase 1 — Reproducción TMDB (núcleo, ~1 día) ✅

**1.1. `EpisodesArgs` con contexto de medio**

`lib/presentation/providers/episodes_provider.dart`

- [x] Añadir `final String mediaType;` (`'tv'` / `'movie'`) a `EpisodesArgs` e incluirlo en `==`/`hashCode`.
- [x] Propagar `mediaType` desde `EpisodesView` (derivado de `tmdbDetails.isMovie` o del `format`).
- [x] En `_loadTmdbEpisodes`: `getShowDetails(..., isMovie: mediaType == 'movie')` con reintento al endpoint opuesto.
- [x] Guardar en `EpisodesState`: `tmdbMediaType`, `tmdbEnglishTitle` (`originalName`), `tmdbYear`.

**1.2. Proveedores compatibles**

- [x] Cargar `repo.getOnlinestreamProviders()`, filtrar `where((p) => p.supportsTmdb)` y asignar `compatibleProviders`, `selectedProvider`, `canStreamOnline`.
- [x] Películas y series usan el mismo filtro.
- [ ] Estado vacío explícito: "Ningún proveedor instalado soporta TMDB" con CTA a extensiones (queda para Fase 4).

**1.3. `playEpisode` con parámetros TMDB**

- [x] Pasar `isTmdbMedia`, `tmdbMediaType`, `tmdbSeason`, `tmdbEnglishTitle`, `tmdbYear` en las rutas local y online.
- [ ] Mismo tratamiento en torrent (el buscador de torrents aún indexa por AniList ID).

**1.4. Entradas de reproducción**

TMDB no usa las pestañas online/torrent de anime: su lista de episodios es `EpisodesView`, que delega en `EpisodesNotifier`. Por eso el cableado se concentra ahí.

- [x] `EpisodesView` propaga `mediaType`.
- [x] Botón principal ("Comenzar a ver" / Play) de desktop y mobile usa el mismo `EpisodesNotifier`, con progreso local TMDB y `supportsTmdb`.
- [x] `getIsTmdb` del reproductor cae a `animeDetails.isTmdb`.
- [ ] Pasar los parámetros TMDB en las rutas propias de los layouts que aún son solo Anime/MediaServer (`_playOnlineEpisode`, `_playLocalEpisode`, TV layout). No son alcanzables desde TMDB hoy.

**1.5. Reproductor**

- [x] `getIsTmdb` con fallback a `animeDetails.isTmdb`.
- [x] `tmdbMediaType/season/englishTitle/year` llegan al `PlayerSourceController`.
- [x] `_isMovie` contempla `format == 'MOVIE'`.

**Aceptación:** desde una serie TMDB y desde una película, el reproductor resuelve fuentes con `tmdbId`, `mediaType`, `season`, `year` correctos; cambiar de proveedor mantiene el contexto.

---

### Fase 2 — Progreso y biblioteca (~medio día) ✅

- [x] `OfflineLibraryService.recordAnimeWatch`: acepta y persiste `isTmdb`.
- [x] `OfflineLibraryService.updateAnimeProgress`: acepta y conserva `isTmdb`.
- [x] `PlayerProgressManager.savePlaybackProgress`: pasa `isTmdb`.
- [x] `PlayerProgressManager.syncAnimeProgressIfNeeded`: con `isTmdb` solo actualiza local, notifica y **no** llama a AniList ni a `OfflineSyncService`.
- [x] `PlayerProgressManager`: no escribe `updateContinuityItem` del backend para TMDB (las claves son de AniList).
- [x] `LastSessionItem`: `tmdbMediaType`, `tmdbSeason`, `tmdbEnglishTitle`, `tmdbYear` (nullable y compatibles hacia atrás).
- [x] `savePlaybackProgress` escribe esos campos en la sesión.

**Aceptación:** terminar un episodio TMDB no genera ninguna petición a AniList; la entrada local queda `isTmdb: true` con progreso correcto; reabrir la app conserva temporada y título.

---

### Fase 3 — Continuidad y feed (~1 día) 🟡 parcial

**3.1. Reanudar**

- [x] `continue_watching_playback_launcher.dart`: pasa `isTmdbMedia` y `tmdbMediaType/season/englishTitle/year`; salta la biblioteca local/torrent para TMDB y filtra proveedores `supportsTmdb`.
- [x] `floating_resume_bar.dart`: mismo tratamiento en todas sus rutas.
- [x] Al tocar una tarjeta TMDB en "Seguir viendo", abre detalle TMDB (`isTmdb: true`) cuando no hay sesión reanudable.

**3.2. Unificar "Seguir viendo"**

- [x] `continueWatchingProvider`: fusiona la continuidad del backend con `OfflineLibraryService.getContinueWatching()` (entradas `isTmdb`), deduplicando por `mediaId`.
- [x] El modo offline sigue devolviendo TMDB.
- [ ] Ordenar explícitamente por `effectiveTimestamp` al fusionar (la lista remota ya viene ordenada).

**3.3. Filas TMDB en el feed**

- [x] Fila **“Series en tendencia”** (`tmdbTrendingShowsProvider`) cuando la sección está activa.
- [ ] Fila “Series populares” (`tmdbPopularShowsProvider`).
- [x] Reutiliza `AnimeCard` y abre el detalle con `isTmdb` desde la entrada.
- [x] Invalidación en pull-to-refresh junto a las filas de anime.

**Aceptación:** un usuario sin cuenta AniList ve series TMDB en el feed, las reproduce y al volver aparecen en "Seguir viendo" con el episodio correcto.

---

### Fase 4 — Navegación y pulido (~1 día) 🟡 parcial

- [ ] Evaluar pestaña propia **Series**: `ShellSection.shows` + `ShowsFeedScreen` (reutiliza `FeedScreen` con un filtro de medio) o renombrar la sección Anime a "Inicio" y mostrar ambos feeds.
- [x] i18n de todo string nuevo en `translations.dart`, `en.dart`, `es.dart`.
- [x] Estado de error del catálogo TMDB en Explorar (API key/conexión).
- [x] Los toggles de catálogo (Anime/Series) ya no ocultan el inicio ni el historial; solo quitan su pestaña de Explorar.
- [ ] Estado explícito "ningún proveedor soporta TMDB" con CTA a extensiones.
- [x] Episodios TMDB con la misma UI de Anime (`DesktopEpisodesTab` + cards), sin filtros All/Unwatched.
- [x] Selector de temporada con el estilo de Anime y temporada 0 etiquetada como **Especiales**.
- [x] Orden episodios → cast → trailer; cast y trailer se cargan desde TMDB (`credits,videos`).
- [x] Extensiones onlinestream declaran `providerType` (`anime` / `tmdb` / `both`); Anime y TMDB filtran por capacidad y los selectores muestran un badge.
- [x] Changelog simple en `docs/CHANGELOG_HISTORY.md`.

---

### Fase 5 — Pruebas y blindaje (~medio día) 🟡 parcial

- [x] Unit: `EpisodesArgs` separa movie/tv.
- [x] Unit: `TmdbShowDetails.toAnimeDetails()` → `isTmdb`, `format`, `totalEpisodes`, año.
- [x] Unit: `OnlinestreamProvider.supportsTmdb` (constructor y JSON).
- [x] Unit: `LastSessionItem` persiste y lee el contexto TMDB; sesiones antiguas siguen funcionando.
- [x] Unit: la sección de Series está activa por defecto y respeta un `false` guardado.
- [x] Unit: `getSeasonEpisodes` usa `/tv/{id}/season/{n}` y no comparte caché entre temporadas.
- [x] Widget: Ctrl+K usa TMDB cuando AniList está desactivado o sin sesión.
- [ ] Provider: TMDB TV con un proveedor `supportsTmdb` → `canStreamOnline: true`, `compatibleProviders` filtrado; sin proveedores → `false`.
- [ ] Provider: `mediaType == 'movie'` usa el endpoint de película.
- [ ] Widget: card TMDB del feed navega a detalle con `isTmdb: true`.
- [x] `flutter analyze lib/` → 0 issues.
- [ ] `flutter test` completo → verde (hay fallos previos ajenos en `player_engine_test`, `detail_mode_persistence_test` y tests de detalle).

---

## 4. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
| :--- | :--- | :--- |
| Colisión AniList ID ↔ TMDB ID en mapas locales | Progreso/biblioteca mezclados | Corto plazo: `isTmdb` en todas las escrituras y dedupe por `(isTmdb, mediaId)`. Medio plazo: claves namespaced (`anilist:123`, `tmdb:123`) con migración tolerante. |
| Proveedores de anime no soportan TMDB | "No hay fuentes" en series | Filtrar por `supportsTmdb`, estado vacío claro y fallback a torrent/local. |
| Película TMDB resuelta como serie | Detalle/episodios incorrectos | Propagar `mediaType` desde el entry y fallback TV→movie si `getShowDetails` devuelve null. |
| Cambios en `LastSessionItem` | Sesiones viejas ilegibles | Campos nullable con defaults; no cambiar nombres existentes. |
| Refetch del feed por progreso | UI con saltos | Mantener `select` sobre identidad (`mediaId`, `isTmdb`) y no sobre posición. |
| Romper el flujo Anime | Regresión grande | Gatear todo con `isTmdb`; correr tests de feed y player tras cada fase. |
| Rate limit TMDB | Listas vacías | Reutilizar caché en memoria existente y cachear respuestas del feed. |

---

## 5. Orden recomendado

1. **Fase 0** (activación honesta) → validar que el usuario ve algo.
2. **Fase 1** (reproducción) → el gap que hoy hace que TMDB sea inutilizable.
3. **Fase 2** (progreso) → evita contaminar AniList.
4. **Fase 3** (continuidad/feed) → experiencia completa.
5. **Fase 4–5** (navegación, i18n, tests) → pulido y blindaje.

Fases 1 y 2 son las que convierten "activar" en "integrar". Sin ellas, TMDB solo sirve para navegar metadatos.
