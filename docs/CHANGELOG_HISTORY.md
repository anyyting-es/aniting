# Seanime App - Historical Changelog & Performance Milestones

> **RELEASE CHANGELOG SIMPLICITY RULE (CRITICAL - MANDATORY)**:
> Release changelogs must **ALWAYS be simple, clean, and concise**.
> - **NEVER** include microscopic, tedious, or trivial implementation details that end users do not care about (e.g., do **NOT** write: *"Eliminado el brillo fosforescente del indicador deslizante"*, *"Pestañas de los 7 días visibles en frame 0"*, *"Ajustado padding a 4px"*, *"Cambiado color del dot"*).
> - **ALWAYS** summarize improvements at a high, user-facing level with clear, direct bullet points (e.g., *"Mejoras de UI y navegación en el calendario de emisión"*, *"Nueva pantalla y gestión de estado sin conexión"*, *"Optimizaciones en la caché de seguir viendo"*).
> - Keep it punchy, professional, and easy to skim.

## 7.36. Botones de Acción Sólidos y Flotantes en Detalles (2026-10-13)
- **Fondo Sólido para Reproducción**:
  - Botón principal de reproducción y continuar episodio actualizado con fondo sólido del tema para máxima claridad y contraste.
- **Íconos de Acción Flotantes**:
  - Botones de lápiz de edición, compartir, trailer, favoritos y descargas estilizados como íconos flotantes limpios sin fondos de cristal.

---

## 7.35. Rediseño Profesional del Selector de Torrents en Escritorio (2026-10-12)
- **Nuevo Diseño de Tarjetas de Torrents**:
  - Caja lateral distintiva con el grupo de lanzamiento y resolución en cian brillante.
  - Insignias técnicas automáticas para códec de video (H.264, HEVC, AVC), 10-bit, códec de audio (AAC, FLAC), Dual Audio (Original + Doblaje) y subtítulos múltiples.
  - Indicador numérico de semillas, tamaño de descarga y antigüedad relativa del torrent con acciones rápidas de descarga y reproductor externo.
- **Panel Lateral de Control y Búsqueda**:
  - Miniatura 16:9 limpia sin obstrucciones de texto, título con número de episodio y duración estimada.
  - Selector de proveedor, alternador de búsqueda inteligente y opción para buscar a través de todos los proveedores simultáneamente.
  - Stepper compacto numérico para cambiar de episodio con flechas arriba/abajo.
  - Filtros directos para batches, resolución, mejores versiones y campo para afinar la búsqueda por título.
- **Barra de Herramientas y Ordenación**:
  - Contador de resultados y botones interactivos para ordenar por Semillas, Tamaño, Fecha o Resolución con indicador de dirección.

---

## 7.34. Gestión Avanzada de Biblioteca Local y Corrección de Archivos (2026-10-12)
- **Gestión y Desvinculación de Carpetas**:
  - Posibilidad de desvincular tanto la carpeta principal como carpetas secundarias de la biblioteca local con diálogo de confirmación.
- **Visualizador de Series y Contenido Local**:
  - Nueva sección visual interactiva para explorar todo el contenido local detectado con carátulas, buscador en tiempo real y filtros rápidos (Anime, Series TV, Películas).
  - Acciones directas por título para corregir el emparejamiento (AniList / TMDB) o desvincular completamente.
- **Detección y Gestión de Archivos sin Emparejar**:
  - Corrección exhaustiva en el escaneo y sincronización de archivos huérfanos o no reconocidos, logrando paridad total con Seanime de escritorio.
  - Lista desplegable para inspeccionar archivos y episodios individuales de cada grupo no emparejado con opción de emparejamiento manual.

---

## 7.33. Rediseño Completo del Visor de Torrents en PC y Móvil (2026-10-12)
- **Nuevo Diseño de Dos Paneles en Escritorio**:
  - Reemplazo del modal estrecho inferior por un diálogo amplio y panorámico en PC aprovechando todo el ancho de la pantalla.
  - **Panel Izquierdo (Información y Controles)**: Miniatura 16:9 del episodio con distintivo numérico, título, cambiador rápido de episodios (anterior/siguiente y selector directo), selector de calidad y resolución por píldoras, selector de proveedor de torrents, alternador de búsqueda inteligente/manual y filtro de batches.
  - **Panel Derecho (Lista de Archivos de Torrents)**: Visualizador amplio y legible de resultados de torrents con tarjetas estilizadas personalizadas sin Material Design genérico.
- **Tarjetas de Torrents Claras e Informativas**:
  - Extracción y formateo limpio de grupos de lanzamiento (`[SubsPlease]`, `[Erai-raws]`, etc.), resolución (`1080p`, `720p`, `4K`), insignia dorada de mejor opción y tipo de archivo.
  - Indicador visual intuitivo de salud y velocidad por semillas (verde para excelente/buena velocidad, ámbar para velocidad moderada y rojo para torrents sin semillas).
  - Botón principal de reproducción directa con un clic, descarga en cliente y apertura en reproductor externo.
- **Vista Móvil Adaptativa**:
  - Hoja modal táctil optimizada con chips horizontales de filtro y tarjetas unificadas con la misma riqueza visual.
- **Biblioteca Local Híbrida con Estándar Plex / Jellyfin**:
  - Implementación en el backend Go (`backend/internal/library/shows/`) de un escáner y parser estándar para series y películas occidentales siguiendo convenciones Plex/Jellyfin (`SxxExx`, `1x04`, `Temporada X Episodio Y`, carpetas con año y limpieza de tags de calidad).
  - Persistencia de archivos locales de series en SQLite (`show_local_files`) y endpoints dedicados `/api/v1/shows/*`.
  - En la configuración de carpetas locales (`LocalLibraryPathsCard`), soporte para tipificar cada directorio como Anime (AniList), Series de TV (TMDB), Películas (TMDB) o Mixto.
  - Diálogo de emparejamiento híbrido (`LocalLibraryMatchDialog`) con selector de proveedor `[ AniList ]` vs `[ TMDB ]`, búsqueda directa y acción de desvinculación (Unmatch).
  - Integración en las vistas de episodios de TMDB (`TmdbEpisodeCard`, `TmdbEpisodesView`): indicador visual de archivo local y reproducción directa en el reproductor integrado con 1 toque.
- **Soporte Nativo MPRIS (D-Bus) en Linux**:
  - Servicio `MprisService` que registra la interfaz `org.mpris.MediaPlayer2` y `org.mpris.MediaPlayer2.Player` en el bus de sesión D-Bus de Linux.
  - Control de reproducción mediante teclas multimedia, interfaces del sistema (GNOME, KDE Plasma) y la utilidad `playerctl` (Play, Pause, Play/Pause, Stop, Next, Previous, Seek y SetPosition).
  - Emisión en tiempo real de metadatos (título, artista, álbum, carátula y duración) y estado de reproducción sincronizados con el reproductor de video.

---

## 7.31. Barra de Progreso de Reproducción Reactiva en Lista de Episodios (2026-10-12)
- **Sincronización Reactiva con `playbackProgressPreferencesProvider`**:
  - Las tarjetas de episodios en la página de detalles ahora reflejan el indicador de progreso de reproducción local al salir del reproductor, idéntico a las tarjetas de "Continuar viendo" en Inicio.
  - Integración reactiva en tarjetas desktop (`DesktopGridEpisodeCard`, `DesktopListEpisodeCard`), móvil (`EpisodeListItem`, `EpisodeGridItem`) y TMDB (`TmdbEpisodeCard`).
  - Umbral de visibilidad suave entre 1% y 98% con guardado automático reactivo al cerrar o pausar el video.

---

## 7.30. Optimización de Rendimiento GPU y Shaders en Vista Móvil de Detalles de Anime (2026-10-12)
- **Eliminación de BackdropFilter Redundantes**:
  - Removidos desenfoques innecesarios en selectores de modo y botones de acción rápida situados sobre fondos opacos.
- **Optimización de Blur y Sombras**:
  - Reducción de sigma de desenfoque de fallback a 25 y eliminación de capas de recorte costosas (`saveLayer`).
  - Aislamiento de tarjetas y filas interactivas con `RepaintBoundary` para evitar repintados en cascada durante el scroll.

---

## 7.29. Optimización de Rendimiento GPU y 0 FPS Idle en Detalles de Anime (2026-10-12)
- **0 FPS Reales en Reposo**:
  - Removido `SingleTickerProviderStateMixin` con animación continua infinita en el fondo; el efecto de parallax se transformó en un cálculo impulsado únicamente por el scroll del usuario.
- **Depuración de Shaders en Escritorio**:
  - Eliminados `BackdropFilter` redundantes sobre fondos opacos en la barra de controles de episodios.
  - Aislamiento de capas de renderizado en grillas de episodios, recomendaciones y relaciones con `RepaintBoundary`.

---

## 7.28. Remoción de Sección de Personajes y Elenco en Vista Desktop de Anime (2026-10-12)
- **Diseño Enfocado en Escritorio**:
  - Eliminada la sección de personajes en PC cuando el anime está en modo AniList para evitar desplazamientos verticales excesivos y mantener el foco en episodios, relaciones y recomendaciones.

---

## 7.27. Visibilidad Inmediata y Sincronización de Archivos Locales en Feed y Colección (2026-10-11)
- **Invalidación Reactiva de Proveedores**:
  - Sincronización inmediata al finalizar escaneos locales o emparejamientos manuales en la pantalla de inicio y en la lista de descargas.
  - Detección de shows huérfanos con auto-adición a la biblioteca de AniList en estado "Planning" para disponibilidad inmediata con 1 toque.

---

## 7.26. Pantalla de Ajustes de Biblioteca Local y Emparejamiento Manual (2026-10-11)
- **Subpágina Dedicada en Ajustes**:
  - Nueva categoría en Ajustes para gestionar rutas locales, discos adicionales, escáner mejorado con WebSocket en tiempo real y estadísticas de medios.
  - Diálogo de emparejamiento manual para shows no reconocidos con sugerencias automáticas y buscador integrado.

---

## 7.25. Eliminación de Micro-Lag en Navegación y Transición de Episodios (2026-10-10)
- **Desacoplamiento de Clic de Entrada al Reproductor**:
  - Transición fluida a pantalla completa pospuesta al siguiente frame para completar eventos de puntero de GTK/Wayland sin tirones.
- **Transiciones Ligeras de Modo de Episodios**:
  - Reemplazo de transiciones elásticas costosas por fundidos suaves aislados con `RepaintBoundary`.

---

## 7.24. Optimización de Apertura y Desmontaje de Textura EGL / libmpv estilo Plezy (2026-10-10)
- **Desmontaje en Segundo Plano en Linux**:
  - Liberación de contextos EGL y recursos pesados de libmpv delegada a hilos en segundo plano, erradicando el congelamiento de 1 segundo al salir del reproductor.
- **Priorización de Decodificación por Hardware**:
  - Configuración optimizada de `hwdec` para evitar sondeos síncronos innecesarios de extensiones Vulkan/CUDA no compatibles.

---

## 7.23. Empaquetado Automático del Servidor en Linux y Optimización de Transición del Reproductor (2026-10-10)
- Scripts de compilación unificados y empaquetado del binario Go embebido para distribuciones Linux.

---

## 7.22. Simplificación de Temas y Estandarización Liquid Glass con `g1455` (2026-10-09)
- Rediseño de componentes visuales con estilo Liquid Glass siguiendo la especificación `g1455`: menús emergentes, tarjetas translúcidas, modales y barras de navegación adaptativas.

---

## 7.21. Selector Desplegable Expressivo M3 & Optimización de Salida del Reproductor (2026-10-05)
- Componente `M3ExpressiveSelect` con micro-animaciones fluidas, menús flotantes desacoplados y salida instantánea del reproductor sin bloqueos de audio.

---

## 7.19. Priorización Automática de Modo Local e Indicadores de Progreso en Episodios (2026-10-04)
- Selección automática de reproducción desde disco cuando los episodios están descargados localmente, con indicadores visuales de completado.

---

## 7.16 - 7.18. Gestor de Descargas, Historial y Resiliencia de Torrents (2026-10-04)
- Gestor de descargas unificado para anime y manga, descarga por lotes, introspección de almacenamiento en Android y pausas automáticas de torrents al salir del reproductor.

---

## 7.14 - 7.15. Motor de Subtítulos ASS y Paridad de Estilos (2026-10-03 - 2026-10-04)
- Integración completa de estilos de subtítulos avanzados para libmpv y Media3/libass en Android, corrección de fuentes y compatibilidad con directivas `.ass`.

---

## 7.10 - 7.12. Internacionalización Completa (i18n), AniZip y Navegación Suave (2026-10-02)
- Eliminación total de cadenas de texto estáticas; paridad estricta al 100% entre inglés y español en todas las pantallas. Metadatos de episodios dependientes del idioma del usuario.

---

## 7.6 - 7.9. Resiliencia de Streaming, Actualizaciones In-App y Rediseño Desktop (2026-09-30 - 2026-10-01)
- Soporte para extensiones en línea, actualización automática de la aplicación desde GitHub Releases según la arquitectura del dispositivo (`arm64-v8a`, `x86_64`) y vistas panorámicas de detalles en PC.
