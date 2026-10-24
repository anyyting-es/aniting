# Plan: Wallpaper inmutable y navegación sin flashes

> Objetivo: el wallpaper es una capa **única, estática y permanente** detrás de toda la app.
> La UI (páginas, tabs, sheets, transiciones) se mueve por encima. El wallpaper nunca se
> recarga, nunca se desplaza, nunca se tapa con un color sólido y nunca parpadea.

> **Estado para el release:** la feature está oculta y forzada a off mediante
> `lib/core/constants/feature_flags.dart` (`FeatureFlags.customWallpaper = false`,
> `FeatureFlags.desktopWindowTransparency = false`). El código queda intacto para retomarla
> cuando la app esté estable. Para volver a mostrarla, alcanza con poner los flags en `true`.

---

## 1. Diagnóstico: qué está pasando hoy

El wallpaper ya está montado **fuera del `Navigator`** (`lib/main.dart:290-298`), así que
estructuralmente la idea correcta ya existe. La sensación de "se recarga" viene de cinco
capas de problemas distintos:

| # | Síntoma | Causa raíz | Prioridad |
| :-- | :--- | :--- | :--- |
| 1 | Al abrir Settings: primero un color sólido, después el wallpaper | La transición por defecto (`ZoomPageTransitionsBuilder` en Linux/Windows/Android) pinta un scrim opaco de `colorScheme.surface` de 0 → 0.60 y además hace snapshot de las rutas. | **P0** |
| 2 | El wallpaper "aparece tarde" al arrancar | `AppWallpaperNotifier.setCachedPrefs()` existe pero **nunca se llama** en `main.dart`. El provider arranca con `enabled: false`, carga prefs en async y el wallpaper entra un frame después. | **P0** |
| 3 | Al arrancar, la paleta Material You cambia de golpe | `AppPalettes.wallpaperSeedColor` se setea recién cuando el provider del wallpaper construye; `ThemeNotifier` ya construyó la paleta antes con el seed por defecto. | **P0** |
| 4 | Al abrir Settings, el feed desaparece de golpe | `main_shell.dart:106-115` hace `setState(_isSettingsOpen = true)` **antes** del `Navigator.push`; el `Visibility` oculta el shell en el mismo frame en que empieza la transición. | **P0** |
| 5 | Anime/Manga Detail se ve negro/opaco, sin wallpaper | Esas pantallas re-declaran `scaffoldBackgroundColor` opaco (`anime_detail_screen.dart:542-545`, `manga_detail_screen.dart:597-600`, `anime_full_details_screen.dart:75-82`, `anime_details_modal_sheet.dart:93-96`). Con OLED por defecto es negro puro. | **P0** |
| 6 | Bandas opacas arriba (AppBar) | `appBarTheme.backgroundColor` queda en `effectivePalette.background` (`theme_provider.dart:516`); `main.dart:271-273` sólo cambia el `systemOverlayStyle`, no el color. | **P1** |
| 7 | El glass "se apaga" o se ve plano durante animaciones | `g1455` prohíbe glass dentro de `Opacity`/`FadeTransition`/`AnimatedSwitcher`/`ColorFilter`/`ImageFiltered`. Hay varios sitios así: transiciones de ruta, `ShellAnimatedIndexedStack`, `AppWarmUpGate`, `AnimatedSwitcher` de settings, `showGeneralDialog` del player, etc. | **P1** |
| 8 | El blur del wallpaper puede re-calcularse en cada frame | `AppWallpaperBackground` usa `ImageFiltered` + `Opacity` sobre un `Image.file` sin `RepaintBoundary`. Si algo arriba repinta el `Stack`, el blur se vuelve a rasterizar. | **P2** |
| 9 | El wallpaper puede quedar en blanco bajo presión de memoria | `didHaveMemoryPressure()` limpia `imageCache` (`main.dart:163-167`); el `Image.file` no tiene una referencia propia al `ui.Image` ya decodificado. | **P2** |
| 10 | `hasValidWallpaper` hace I/O síncrono en cada build | `existsSync()` en `AppWallpaperState.hasValidWallpaper` (`wallpaper_preferences_provider.dart:23-27`). | **P2** |

### Lo que **no** es el problema

- El wallpaper **no** tiene parallax ni animación propia. No hay que quitársela.
- El wallpaper **no** se reconstruye al navegar (el `Consumer` de `main.dart` no observa la ruta).
- El `Navigator` ya es transparente: las rutas opacas dejan de pintar la ruta de abajo al terminar la transición, pero el wallpaper vive fuera del `Overlay`, así que sigue visible.

---

## 2. Arquitectura objetivo

```
MaterialApp.builder
└── Theme (scaffold transparente)
    └── M3ETheme
        └── GlassHost
            └── Stack
                ├── [0] WallpaperLayer   ← inmutable, RepaintBoundary, pre-decodificado
                ├── [1] Navigator        ← toda la UI y sus animaciones
                └── [2] ToastHost
```

Reglas del contrato:

1. **Una sola capa de wallpaper**, montada una vez, fuera del `Navigator`. Nunca se anima ni se
   reconstruye por navegación.
2. **Toda ruta de nivel superior es transparente** (`Scaffold.backgroundColor` transparente).
   Lo opaco son las superficies de contenido (cards, barras, sheets), no el fondo de pantalla.
3. **Las transiciones de ruta no usan opacidad ni scrim de `surface`**. Se mueve la UI con
   slide/scale; el wallpaper queda fijo.
4. **El glass nunca va dentro de un `FadeTransition`/`Opacity`.** Se anima con
   `GlassSurface.materialize` o se oculta con `Visibility`.
5. **El wallpaper se decodifica una vez** y se mantiene una referencia al `ui.Image`. El blur se
   pre-calcula o se aísla en un `RepaintBoundary`.

---

## 3. Fases de implementación

### Fase 0 — P0: eliminar el flash al abrir Settings y al arrancar

**0.1. Cachear prefs del wallpaper antes de `runApp`**

- `lib/core/preferences/wallpaper_preferences_provider.dart`
  - En `setCachedPrefs(prefs)`, setear también `AppPalettes.wallpaperSeedColor` desde
    `_keySeedColor` de forma síncrona.
- `lib/main.dart:101-126`
  - Agregar `AppWallpaperNotifier.setCachedPrefs(prefs);` (idealmente antes de
    `ThemeNotifier.setCachedPrefs(prefs)`).

Resultado: `build()` lee el estado real del wallpaper en el primer frame y la paleta arranca
con el seed correcto. Se elimina el "color sólido → wallpaper" del cold start.

**0.2. Transiciones de ruta sin scrim y sin fade sobre glass**

- `lib/core/theme/theme_provider.dart:609` y `lib/core/theme/app_theme.dart:32`
  - Reemplazar `const PageTransitionsTheme()` por un `PageTransitionsTheme` con un builder
    propio, por plataforma:
    - Linux/Windows: `WallpaperSafePageTransitionsBuilder` (slide horizontal + micro-scale,
      **sin** `FadeTransition`, **sin** `ColoredBox` de fondo).
    - Android: `PredictiveBackPageTransitionsBuilder(fallbackColor: Colors.transparent)` o el
      builder propio si el predictive back no es crítico.
    - iOS/macOS: `CupertinoPageTransitionsBuilder()` ya es slide y no pinta scrim.
  - El builder propio vive en `lib/core/theme/custom_route_transitions.dart`.
- `lib/core/theme/custom_route_transitions.dart:24-72`
  - `buildWebPageTransition` hoy hace doble `FadeTransition` + `ScaleTransition`. Cambiarlo a
    slide + scale **sin opacidad** (o usarlo sólo donde no haya glass).
  - `SmoothPageRoute` (anime/manga detail) usa ese builder: al quitar el fade, el glass deja de
    apagarse durante la navegación.

Resultado: al abrir Settings ya no hay un velo de `surface`; la página entra deslizándose sobre
el wallpaper.

**0.3. Dejar de ocultar el shell antes de tiempo**

- `lib/presentation/screens/main_shell.dart:104-115` y `:322-324`, `:345-347`, `:389-391`
  - Quitar el `setState(_isSettingsOpen = true)` previo al push y el `Visibility` que oculta el
    shell.
  - El `Navigator` ya deja de pintar la ruta de abajo cuando la ruta de Settings (opaca) termina
    su transición; durante la transición se ve el shell saliendo, que es el efecto natural de
    "la UI se mueve sobre el wallpaper".
  - Si se quiere conservar el `_isSettingsOpen` por seguridad, ocultarlo recién en
    `route.animation.status == AnimationStatus.completed` y restaurarlo en `reverse`.

Resultado: desaparece el salto brusco feed → wallpaper al abrir Settings.

**0.4. Respetar el wallpaper en las pantallas de detalle**

- `lib/presentation/screens/anime_detail_screen.dart:542-545`
- `lib/presentation/screens/anime_full_details_screen.dart:75-82`
- `lib/presentation/screens/manga_detail_screen.dart:597-600`
- `lib/presentation/widgets/anime_details_modal_sheet.dart:93-96`
  - Si `wallpaperPreferencesProvider.hasValidWallpaper` es true, mantener
    `scaffoldBackgroundColor: Colors.transparent` (heredado del `baseTheme`) y aplicar sólo el
    `colorScheme` dinámico del cover.
  - Los gradientes de los heroes que terminan en `scaffoldBackgroundColor` pasan a terminar en
    transparente; agregar un scrim sutil con alpha para legibilidad del texto
    (`desktop_hero_banner.dart:158-167`, `anime_detail_mobile_layout.dart:799-830`,
    `mobile_manga_hero_banner.dart:79-108`).
  - TV layout (`anime_detail_tv_layout.dart:174-175`) y player/reader se mantienen opacos por
    decisión de diseño.

---

### Fase 1 — P1: contrato de transparencia

**1.1. AppBar transparente cuando hay wallpaper**

- `lib/main.dart:271-273` (dentro del `updatedTheme.copyWith`)
  - Si `hasWallpaper || effectiveWindowTransparency`:
    - `appBarTheme.backgroundColor = Colors.transparent`
    - `appBarTheme.surfaceTintColor = Colors.transparent`
    - `appBarTheme.scrolledUnderElevation = 0`
  - Esto arregla las bandas opacas de MyLists, Genres, GenreDetail, AiringCalendar,
    ExtensionsMarketplace, MangaDetail, AnimeFullDetails.

**1.2. Revisar superficies opacas restantes**

- `main_shell.dart:434-435` (NavigationBar clásica) → decidir: glass, transparente o mantener
  `surfaceContainer` como barra de navegación (no es un flash, es una barra).
- `showModalBottomSheet` con `colorScheme.surface` opaco
  (`manga_detail_screen.dart:416-418`, `discover_filter_sheet.dart:152-156`,
  `manga_details_modal_sheet.dart:21-24`, `player_settings_screen.dart:108-111`) → migrar a
  `Colors.transparent` + contenedor glass, o dejarlos como sheets sólidos (decisión de diseño).
- `WelcomeScreen` pinta una imagen full-screen (`welcome_screen.dart:333-371`). Es intencional
  para onboarding; si se quiere wallpaper también ahí, cambiar a `Image` con opacidad y dejar el
  wallpaper detrás.

**1.3. `GlassHost.backdrop` con wallpaper**

- `lib/main.dart:282-284`: hoy pasa `Colors.transparent`. Para el tier opaco y la legibilidad,
  pasar un color promedio real (derivado de `wallpaperState.seedColor` o del palette background)
  en lugar de transparente.

---

### Fase 2 — P1: animaciones compatibles con glass (regla 21 de g1455)

Cambiar los `FadeTransition`/`AnimatedSwitcher`/`AnimatedOpacity` que envuelven glass por
slide/scale, o por `Visibility`/`materialize`:

| Archivo | Qué hacer |
| :--- | :--- |
| `lib/presentation/widgets/shell_animated_indexed_stack.dart:65-77` | Reemplazar `FadeTransition` por slide/scale sin opacidad. Evita que el wallpaper se vea a través de la página durante 240 ms en cada cambio de tab. |
| `lib/presentation/screens/startup/app_warm_up_gate.dart:164-176` | `AnimatedSwitcher` con fade sobre `MainShell` (que contiene glass). Cambiar a transición sin opacidad o switch directo. |
| `lib/presentation/screens/settings/widgets/expressive/expressive_settings_detail_panel.dart:74-88` | `FadeTransition` sobre páginas de settings con glass → slide sin fade. |
| `lib/presentation/widgets/player/sheets/player_settings_sheet.dart:208` | `showGeneralDialog` sin `transitionBuilder` usa fade por defecto → agregar slide/scale sin opacidad. |
| `lib/presentation/widgets/toast/app_toast_item.dart:149-161` | `FadeTransition` sobre `GlassCard` → `Visibility`/slide, o aceptar que el toast no sea glass. |
| `lib/presentation/widgets/edit_entry_modal.dart:66-81`, `anime_detail_source_popup.dart:49-60`, `anime_detail_mode_popup.dart:42-53` | Quitar el fade que envuelve `GlassCard`; dejar slide/scale. |
| `lib/presentation/screens/manga_reader_screen.dart:897-901`, `970-977` y `welcome_step_debrid.dart:151-156` | `AnimatedOpacity` sobre `GlassCard` → `Visibility` o materialize. |

No tocar `showDialog` (Material no aplica fade al child) ni los `AnimatedSwitcher` de contenido
que no contienen glass.

---

### Fase 3 — P2: renderizado del wallpaper a prueba de balas

**3.1. `AppWallpaperBackground` inmutable**

- `lib/presentation/widgets/app_wallpaper_background.dart`
  - Envolver todo en `RepaintBoundary(isComplex: true, willChange: false)`.
  - Mantener el `FileImage`/`ui.Image` en un provider o cache para que no se re-decodifique.
  - Opcional: pre-calcular el blur con `ui.PictureRecorder` + `ImageFilter.blur` y pintar con
    `RawImage`; así el blur no se recalcula nunca en runtime.
  - Evitar `existsSync()` por build: cachear `fileExists` en `AppWallpaperState` y recalcularlo
    sólo al cambiar de path o al abrir la app.

**3.2. Precarga y memoria**

- `lib/main.dart:46-53`
  - Después de `runApp` (o en `_loadFromPrefs`), `precacheImage(FileImage(file), context)` para
    que el primer frame ya tenga el bitmap.
  - Guardar una referencia al `ui.Image` decodificado para que `imageCache.clear()` en
    `didHaveMemoryPressure()` no deje el wallpaper en blanco.

**3.3. (Opcional) Declaración de backdrop para glass**

- Evaluar `GlassBackdrop.image(FileImage(...), child: navigator)` en `main.dart` para que el
  glass que está directamente sobre el wallpaper no capture la pantalla completa.
  - Requiere envolver las zonas con contenido dinámico en `GlassBackdrop.live()` (feeds,
    listas), si no el glass mostraría sólo el wallpaper.
  - Es una optimización de performance, no un requisito para arreglar los flashes.

---

### Fase 4 — Verificación

**Manual (checklist):**

- [ ] Cold start con wallpaper: no se ve color sólido antes de la imagen.
- [ ] Cold start: la paleta Material You ya sale con el seed del wallpaper.
- [ ] Abrir/cerrar Settings desde Home, Manga, Explore, Calendar, Profile (desktop y mobile).
- [ ] Abrir Anime Detail, Manga Detail, Anime Full Details, Downloads, Search, Genres.
- [ ] Cambiar tabs del shell: el wallpaper no se transparenta durante la animación.
- [ ] Abrir diálogos/sheets/player settings: el glass no se ve plano ni gris.
- [ ] Cambiar opacidad/blur del wallpaper en vivo: sin parpadeos ni saltos.
- [ ] Activar/desactivar OLED y window transparency: sin fondos negros inesperados.
- [ ] Simular presión de memoria: el wallpaper no queda en blanco.
- [ ] Verificar que el wallpaper no se mueve al hacer scroll, abrir sheets ni navegar.

**Automático:**

- [ ] `flutter analyze lib/` → 0 issues.
- [ ] `flutter test` (incluye `test/wallpaper_preferences_test.dart`).
- [ ] Agregar test de regresión:
  - El estado inicial con prefs cacheadas ya tiene `hasValidWallpaper == true` en el primer build.
  - El `PageTransitionsTheme` configurado no es el default de Zoom (o su `backgroundColor` es
    transparente).
  - Un widget test que monte `MaterialApp` con wallpaper y navegue a una ruta, verificando que
    `AppWallpaperBackground` sigue montado y no se recrea.

---

## 4. Orden recomendado de PRs

1. **PR 1 (P0, ~1-2 h):** 0.1 + 0.2 + 0.3 → elimina el flash de Settings y de arranque.
2. **PR 2 (P0, ~2-3 h):** 0.4 + 1.1 → wallpaper visible en detail screens y sin bandas opacas.
3. **PR 3 (P1, ~2-3 h):** Fase 2 → glass estable en todas las animaciones.
4. **PR 4 (P2, ~2-3 h):** Fase 3 → renderizado/precarga/optimización.
5. **PR 5 (opcional):** Fase 3.3 `GlassBackdrop` + limpieza de sheets opacos.

---

## 5. Criterios de aceptación

- El wallpaper se monta una sola vez y no se reconstruye al navegar.
- Ninguna transición de ruta pinta un color sólido sobre el wallpaper.
- Ninguna pantalla de nivel superior tapa el wallpaper con un fondo opaco (salvo TV/player/reader
  por diseño).
- El glass se mantiene estable (no se apaga) durante transiciones y cambios de tab.
- El primer frame con wallpaper ya muestra la imagen y la paleta correcta.
- `flutter analyze lib/` limpio y tests en verde.

---

## 6. Riesgos / decisiones abiertas

- **Legibilidad en detail screens:** al dejar el wallpaper detrás de los heroes, hay que ajustar
  los gradientes (alpha) para que el texto siga teniendo contraste. Requiere revisión visual.
- **Android predictive back:** si se reemplaza el builder por uno propio se puede perder la
  animación nativa de predictive back. Alternativa: `fallbackColor: Colors.transparent` y
  aceptar el fade interno de `FadeForwardsPageTransitionsBuilder`.
- **`GlassBackdrop`:** declarar el wallpaper como backdrop global mejora performance pero hace
  que el glass sobre listas deje de refractar el contenido; hay que delimitar con
  `GlassBackdrop.live()`.
- **Window transparency:** el slider de opacidad de `desktop_window_transparency_provider` hoy
  no se aplica en `main.dart` (el fondo se fuerza a transparente). Es deuda separada; no bloquea
  este plan.
