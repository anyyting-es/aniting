# Seanime App - Historical Changelog & Performance Milestones

> **RELEASE CHANGELOG SIMPLICITY RULE (CRITICAL - MANDATORY)**:
> Release changelogs must **ALWAYS be simple, clean, and concise**.
> - **NEVER** include microscopic, tedious, or trivial implementation details that end users do not care about (e.g., do **NOT** write: *"Eliminado el brillo fosforescente del indicador deslizante"*, *"Pestañas de los 7 días visibles en frame 0"*, *"Ajustado padding a 4px"*, *"Cambiado color del dot"*).
> - **ALWAYS** summarize improvements at a high, user-facing level with clear, direct bullet points (e.g., *"Mejoras de UI y navegación en el calendario de emisión"*, *"Nueva pantalla y gestión de estado sin conexión"*, *"Optimizaciones en la caché de seguir viendo"*).
> - Keep it punchy, professional, and easy to skim.
## 7.70. Integración de Servicios Debrid (Real-Debrid, TorBox y Más) (2026-10-16)
- **Soporte Nativo de Servicios Debrid**:
  - Incorporada compatibilidad completa con proveedores Debrid líderes (Real-Debrid, TorBox, AllDebrid, Debrid-Link y Premiumize).
  - Nueva pantalla de configuración en Ajustes con diseño Pixel UI y Liquid Glass para habilitar el servicio, seleccionar proveedor y gestionar tokens de forma segura.
- **Disponibilidad Instantánea y Streaming en Caché (Instant Debrid)**:
  - En la búsqueda y selector de torrents (móvil y escritorio), la aplicación ahora identifica en tiempo real los torrents y archivos que ya están en caché en los servidores Debrid con una insignia visual distintiva (`⚡ Instant Debrid`).
  - Acción directa de reproducción instantánea (`⚡ Stream Debrid`) y descarga de alta velocidad sin depender de disponibilidad de seeders P2P.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y código optimizado.

---

## 7.69. Alineación Perfecta y Eliminación de Gap en Barra de Búsqueda (2026-10-16)
- **Eliminación del Gap Inicial en Barra de Tiempo (`TimelineSlider`)**:
  - Implementado `_FullWidthRoundedRectSliderTrackShape` para que el slider táctil pinte su recorrido de borde a borde (0px de offset inicial), eliminando la hendidura o espacio vacío que dejaba la sombra al principio.
  - La pista de fondo gris, la barra de buffer dinámico y los marcadores de capítulos de MKV ahora se alinean con precisión 1:1 desde el píxel 0.
- **Detección Automática de Episodios Locales desde Almacenamiento**:
  - Incorporado escaneo persistente en disco (`findDownloadedEpisodesOnDisk`) para que los episodios descargados se reconozcan de inmediato tras reinstalaciones o inicios sin conexión.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y tests unitarios verificados.

---

## 7.68. Optimización Dinámica de Búsqueda (Seek) y Resiliencia en Descargas (2026-10-16)
- **Parámetros de Búsqueda Adaptativos (Archivos Locales vs Red)**:
  - En archivos locales descargados, ExoPlayer ahora aplica `SeekParameters.CLOSEST_SYNC`, permitiendo saltos instantáneos al fotograma clave más cercano sin saturar el decodificador de hardware con decodificaciones intermedias pesadas.
  - En transmisiones de red, se mantiene `SeekParameters.EXACT` para sincronización precisa muestra por muestra entre audio y video.
- **Emisión Precisa de Posición Real Post-Seek**:
  - Tras cualquier operación de búsqueda, ExoPlayer lee y reporta inmediatamente su posición interna real (`currentPosition`) a la UI de Flutter, garantizando alineación visual perfecta de la barra de tiempo.
- **Resiliencia en el Motor de Descargas HLS**:
  - La preparación y limpieza de archivos de salida existentes antes de escribir la descarga ahora previene excepciones por bloqueos de descriptores o inexistencia del archivo.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y tests unitarios verificados.

---

## 7.67. Sincronización Exacta de Audio/Video en Barra de Búsqueda (Seek) (2026-10-16)
- **Sincronización Exacta Audio/Video (`SeekParameters.EXACT`)**:
  - En ExoPlayer, se cambió el modo de búsqueda a `SeekParameters.EXACT` para que tanto el decodificador de audio como el de video busquen exactamente la misma muestra temporal, eliminando la congelación del video mientras espera al stream de audio.
- **Despacho Inmediato de Posición Post-Seek**:
  - Tras invocar `seekTo()`, la posición resultante se emite de inmediato al canal de eventos de Flutter, sincronizando la barra de reproducción y subtítulos en el frame 0 sin retraso por el polling periódico.
- **Tolerancia y Continuidad en la Barra de Tiempo**:
  - En `TimelineSlider`, se ajustó la tolerancia del target optimista para que la barra se mueva fluidamente con la nueva posición del reproductor sin quedarse clavada en la posición pulsada.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados exitosamente.

---

## 7.66. Optimización de Rendimiento en Descargas Online (2026-10-16)
- **Desencriptación Criptográfica en Segundo Plano (`compute`)**:
  - En fuentes online HLS cifradas (`AES-128-CBC`), la computación criptográfica de cada fragmento ahora se ejecuta en un hilo de trabajo aislado en segundo plano mediante `compute()`, eliminando los bloqueos del hilo principal de la interfaz.
- **Throttling de Notificaciones de Progreso**:
  - Se limitó la emisión de progreso a la UI a intervalos de 500 ms (o al finalizar), evitando decenas de reconstrucciones completas por segundo del árbol de widgets.
- **Caché de Verificación de Archivos Locales en Disco**:
  - Eliminadas las comprobaciones síncronas recurrentes `File.existsSync()` en el `build` de la vista de episodios mediante caché en memoria de archivos validados.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados exitosamente.

---

## 7.65. Modales con Liquid Glass, Desplazamiento Fluido y Altura Adaptativa (2026-10-16)
- **Modal de Torrents con Altura Adaptativa y Cierre Deslizable**:
  - El selector de torrents móvil ahora se abre por defecto al ~60% de la pantalla en lugar de pantalla completa fija.
  - La lista de resultados se ajusta automáticamente a su altura intrínseca cuando hay pocas opciones (`shrinkWrap`), evitando espacios vacíos innecesarios.
  - Soporte fluido para deslizamiento interactivo hacia abajo (*drag-to-dismiss*) para cerrar el modal cómodamente.
- **Detalles de Episodio con Liquid Glass (`g1455`)**:
  - `showEpisodeDetailModal` migrado a `showGlassSheet` con acabados refractivos adaptativos (`GlassFinish.regularDark` / `regularLight`).
  - Eliminado el contenedor opaco convencional y barra de agarre redundante, integrando la barra nativa del sistema de cristal líquido.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados exitosamente.

---

## 7.64. Menú de Opciones del Reproductor con Liquid Glass Refractivo (2026-10-16)
- **Contenedores Liquid Glass sobre Video (`g1455`)**:
  - `PlayerSettingsSheet` implementa `GlassCard` con refracción translúcida tanto en la hoja inferior móvil como en el drawer lateral de escritorio y pantalla completa.
  - El fondo se fusiona elegantemente con el contenido del video en reproducción mediante desenfoque gaussiano y tinte translúcido según el tema activo (`0.65` en tema oscuro y `0.75` en claro).
- **Tarjetas y Vistas Internas Translúcidas y Adaptativas**:
  - Se eliminaron los fondos oscuros rígidos (`#151518`) en las subvistas de capítulos, pistas de audio, subtítulos, sincronización, relación de aspecto, shaders GLSL, métricas de torrents y estilos de subtítulos.
  - Elementos y divisores integrados armónicamente con `Theme.of(context).colorScheme`.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados.

---

## 7.63. Adaptación Completa del Selector de Fuentes a Modo Claro (2026-10-16)
- **Adaptabilidad a Modo Claro y Oscuro en Selector de Fuentes**:
  - `PlayerSourceSelectorSheet` ahora selecciona dinámicamente el acabado de cristal `GlassFinish.regularDark` o `GlassFinish.regularLight`.
  - Integración completa con la paleta de colores de Material 3 (`colorScheme.onSurface`, `onSurfaceVariant`, `surface` y `primary`), garantizando contraste, legibilidad y coherencia visual sin importar el tema activo.
  - Los chips de proveedores, el interruptor DUB/SUB, los botones de acción y los elementos de servidor/calidad ajustan sus fondos translúcidos y bordes para evitar textos invisibles o superficies sobreexpuestas.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados.

---

## 7.62. Corrección Integral de Eliminación en Lote, Miniaturas y Transiciones Suaves (2026-10-16)
- **Eliminación en Lote e Invalidation Completa**:
  - Eliminación en lote ahora desvincula el historial de descargas (`downloadHistoryProvider`), borra los archivos físicos en disco e invalida la colección para retirar inmediatamente los indicadores de episodio descargado.
  - Sincronización bidireccional y verificación física de archivos en los mapas de episodios de escritorio y móvil.
- **Botones y Selectores con Estilo Liquid Glass**:
  - Reemplazo de los chips y botones genéricos de Material Design por controles translúcidos con micro-bordes esmerilados y un botón principal de descarga estilo cristal fluido con glow suave.
- **Selector de Fuentes y Servidores Simplificado y Limpio**:
  - Píldoras de selección de servidores con disponibilidad (`Servidor (X/Total)`) y tipografía limpia integrada con el tema visual.
- **Miniatura Compacta en Diálogo de Descarga Individual**:
  - Ajuste a formato compacto de altura contenida para la vista previa junto al título del episodio, dejando accesibles los controles y calidades de video.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados exitosamente.

---

## 7.61. Servidores de Video Multicolores y Respeto a Navegación del Sistema Android (2026-10-16)
- **Servidores de Video con Colores Distintivos y Fallback Automático**:
  - En la descarga por lote de la fuente seleccionada, los colores distintivos ahora representan las diferentes opciones y servidores de video (Streamwish, Filemoon, Mega, etc.).
  - Selector superior de servidor preferido con contador de disponibilidad (`X/Total`) y asignación inteligente con respaldo a servidores alternativos con su color respectivo.
  - Selector por episodio para cambiar con un toque el servidor y calidad específica respetando los colores del sistema.
- **Ajuste de Insets de Navegación del Sistema en Android**:
  - Tanto el modal de descarga individual como el de descarga por lote ahora respetan las áreas seguras (`SafeArea` y `useSafeArea`), adaptando el padding inferior dinámicamente según la navegación de 3 botones o la barra de gestos para que el botón de descarga nunca quede oculto.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados.

---

## 7.60. Alertas Liquid Glass, Gestión de Descargas Online y Transiciones Suaves (2026-10-16)
- **Alertas Nativas Liquid Glass (`g1455`)**:
  - Implementación de diálogos de confirmación de eliminación con `GlassAlert` y `GlassAlertAction` en escritorio, móvil, biblioteca local y descargas por lote.
- **Detección y Eliminación Completa de Descargas Online**:
  - Los episodios descargados desde fuentes online ahora se detectan de forma unificada e inmediata tanto en vistas de Torrent, Online y Biblioteca Local.
  - El menú contextual de tres puntos ahora muestra correctamente la opción "Eliminar descarga" y limpia el archivo físico y el historial de descargas.
- **Transición Fluida entre Modos (Online, Torrent, Local)**:
  - Eliminación del cambio abrupto ("pop pum") entre fuentes y modos tanto en móvil como en escritorio mediante transiciones animadas suaves con curvas naturales.
- **Estabilidad de Layout en Navegación Flotante**:
  - Restricción de altura en `MobileFloatingNav` al no haber sesión activa, corrigiendo la excepción de Scaffold con SnackBars flotantes fuera de pantalla.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados.

---

## 7.59. Modal de Descarga por Lote y Fuentes Multicolores (2026-10-16)
- **Modal de Descarga en Lote con Liquid Glass (`g1455`)**:
  - Al seleccionar múltiples episodios, ahora se abre un modal interactivo con auténtico Liquid Glass que permite configurar las fuentes antes de encolar la descarga.
  - El modal de descarga individual también se actualizó con escarchado translúcido, bordes de cristal y elevación sutil.
- **Sistema de Fuentes con Colores Distintivos y Fallback Inteligente**:
  - Lista superior de proveedores donde cada fuente cuenta con un color distintivo único y un contador de disponibilidad (`X/Total`).
  - Al seleccionar una fuente preferida arriba, los episodios que dicha fuente disponga se le asignan automáticamente; los que no estén disponibles en esa fuente se asignan de forma inteligente a fuentes alternativas disponibles mostrando su color respectivo.
  - Posibilidad de alternar manualmente la fuente de cualquier episodio específico mediante un chip interactivo con el color distintivo de cada fuente.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados.

---

## 7.58. Barra de Acciones en Lote Flotante y Estilo Liquid Glass (2026-10-16)
- **Barra Flotante Fija en Pantalla**:
  - Se corrigió el posicionamiento de la barra de acciones por lote (`EpisodeBatchActionBar`), elevándola al stack raíz superior para que flote fijada en la parte inferior de la pantalla sin quedar atrapada al final de la lista scrolleable.
- **Acabado Liquid Glass Auténtico (`g1455`)**:
  - Estilizado de la barra con refracción y escarchado dinámico reactivo al tema (`surfaceContainer` translúcido, borde cristalino y doble sombra difusa).
  - Indicador de selección estilo pill badge y botones de acción rápida con respuesta háptica y transiciones elásticas.
- **Soporte Unificado Móvil y Escritorio**:
  - Integración en los diseños móvil y de escritorio con soporte de clic derecho y pulsación larga en las tarjetas de episodios (`DesktopGridEpisodeCard` y `DesktopListEpisodeCard`).
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados.

---

## 7.57. Reproductor y Descargas Online: Estado Claro y Progreso Visible (2026-10-16)
- **Reproductor Sin Falsos Errores**:
  - Al reproducir un episodio descargado (local) o un torrent, la tarjeta de reproducción ahora indica "Reproduciendo en local" / "Reproduciendo desde torrent" en lugar de mostrar "Opciones de reproducción" y un aviso de "no hay fuentes".
- **Descargas Online Visibles en el Gestor**:
  - Las descargas desde fuentes online aparecen ahora en el Gestor de descargas con el mismo flujo que los torrents: progreso, velocidad y cancelación, además de un aviso claro si la fuente está protegida o el archivo no es válido.
  - El contador de descargas activas de la pantalla de Descargas ya incluye las descargas online.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 253/253 tests aprobados.

---

## 7.56. Modo de Selección Múltiple y Acciones por Lote en Episodios (2026-10-16)
- **Selección Múltiple con Pulsación Larga**:
  - Al mantener presionado cualquier episodio (en vista de lista o cuadrícula), se activa el modo de selección múltiple con respuesta háptica y animaciones fluidas (`AnimatedScale` con curvas elásticas, bordes y fondo dinámicos).
  - Tocar episodios una vez en modo de selección conmuta su selección de forma instantánea.
- **Barra Flotante de Acciones en Lote (Liquid Glass)**:
  - Nueva barra flotante animada con efecto liquid glass (`g1455`) que aparece suavemente desde la parte inferior sin saltos bruscos ni interrupciones del scroll.
  - **Descargar selección**: Encola descargas en lote de los episodios seleccionados (tanto en fuentes online como torrents).
  - **Eliminar descargas**: Permite borrar con confirmación los archivos descargados de los episodios seleccionados y sincroniza la biblioteca.
  - **Marcar como visto / no visto**: Actualiza en lote el estado de visualización en la biblioteca.
  - **Seleccionar todo y Deseleccionar**: Controles rápidos para gestionar toda la lista de un toque.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/`.

---

## 7.55. Descargas Nativas para Fuentes de Streaming Online (2026-10-16)
- **Motor Dual de Descargas Online (HLS y Directo)**:
  - Implementación del sistema de descarga de episodios desde proveedores de streaming online (AnimePahe, Gogoanime, Zoro, etc.).
  - Soporte de streams HLS (`.m3u8`) y archivos de video directo con descarga concurrente de segmentos, cálculo de velocidad en tiempo real y descarga de subtítulos externos asociados.
  - Compatibilidad universal: Remuxing acelerado con FFmpeg en plataformas de escritorio y motor paralelo en Dart puro en Android.
- **Diálogo y Hoja Modal Interactiva**:
  - Nuevo selector con diseño Liquid Glass (`g1455`) y Material 3 Expressive para elegir resolución y servidor de descarga.
  - Indicador de estado de descarga en tiempo real con barra de progreso, velocidad y opción de cancelación.
- **Integración con Biblioteca Local y Gestor de Descargas**:
  - Al completar la descarga, se activa el escaneo automático del servidor para indexar el episodio en la biblioteca local y se registra en el historial de descargas.
  - Sección dedicada a "Descargas Online" en la pestaña de descargas activas y badges de progreso en tarjetas de episodios de móvil y escritorio.
- **Acceso Directo desde la App**:
  - Disponible desde las tarjetas de episodios en Streaming Online (móvil y escritorio) y desde la hoja de selección de fuentes dentro del reproductor de video.
- **Correcciones**:
  - Las descargas de fuentes cifradas ahora se descifran correctamente y se verifica que el archivo final sea reproducible; si la fuente está protegida o inválida, la descarga se marca como fallida sin dejar archivos corruptos.
  - Mensajes de estado de descarga más claros (descarga ya en curso, sin carpeta de guardado, fuente protegida) y mayor estabilidad del reproductor al salir.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/`.

---

## 7.54. Depuración y Simplificación de Tarjetas de Torrents (2026-10-16)
- **Diseño Más Limpio y Minimalista en Tarjetas**:
  - Eliminación de elementos redundantes en las tarjetas de la lista de torrents: icono pequeño de reproducción, botones de descarga o reproductor externo, indicador de visto y numeración redundante de episodio.
  - Mayor protagonismo y legibilidad del nombre del archivo, grupo de lanzamiento, resolución, etiquetas técnicas y salud del enjambre (seeders, tamaño y fecha).
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 246/246 tests aprobados al 100%.

---

## 7.53. Unificación Global de Iconos (Lucide & Material) (2026-10-16)
- **Eliminación Total de Iconos Rígidos**:
  - Migración exhaustiva de todos los iconos estáticos en las vistas de detalle de anime (móvil, escritorio y TV), selector de torrents, visor de episodios y reproductor de video a la arquitectura unificada `AppIcons.*(iconPack)`.
  - Respeto impecable y en tiempo real del paquete de iconos seleccionado en Ajustes (`Lucide` o `Material`), eliminando mezclas visuales y garantizando coherencia en toda la experiencia.
- **Ampliación Semántica de `AppIcons`**:
  - Incorporación de mapeos semánticos completos para estados de reproducción, enlaces externos, favoritos, controles de listas y selectores contextuales.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y suite de pruebas aprobada al 100%.

---

## 7.52. Insets de Navegación del Sistema en Opciones Avanzadas de Streaming (2026-10-16)
- **Respeto de Insets de Android (Barra de 3 Botones y Gestos)**:
  - En la hoja modal de opciones avanzadas (`AnimeDetailAdvancedSheet`) y vinculación manual (`AnimeDetailManualMappingSheet`), se incorpora `SafeArea` adaptativo para evitar que los botones de acción inferior queden cubiertos por la barra de navegación de 3 botones de Android o la píldora de gestos.
  - Sincronización animada fluida con el teclado virtual (`AnimatedPadding`), manteniendo un espaciado óptimo y ergonómico sin importar el modo de navegación del dispositivo.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y 246/246 tests aprobados.

---

## 7.51. Reorganización y Alineación del Modal de Edición de Listas (2026-10-16)
- **Reordenamiento Estratégico de Campos**:
  - Estado (*Status*) y Progreso (*Progress*) ahora ocupan la primera fila principal lado a lado con proporciones idénticas (50/50).
  - Fechas de inicio y finalización organizadas en la segunda fila como pareja natural.
  - Repeticiones (*Total rewatches*) y Puntuación (*Score*) ubicados al final de la cuadrícula.
- **Armonización de Color y Eliminación del Amarillo en Score**:
  - La barra y botón deslizante de puntuación ahora adoptan el color primario dinámico del tema de la app, eliminando el color amarillo estático.
  - El badge de puntuación ahora permite pulsar para ingresar la calificación numérica de forma directa.
- **Alineación Geométrica Estricta a 46 px**:
  - Calibración de todos los contenedores y controles a 46 px de altura exacta y cabeceras unificadas de 22 px con iconos contextuales, garantizando un alineamiento horizontal perfecto entre columnas.
  - Barra inferior de acciones (Eliminar, Cancelar, Guardar cambios) alineada verticalmente.
- **Verificación Completa**:
  - 0 advertencias en `flutter analyze lib/` y 246/246 tests aprobados.

---

## 7.50. Rediseño del Selector de Torrents con Vidrio Líquido (2026-10-16)
- **Modal de Vidrio Líquido Adaptativo con `g1455` (Liquid Glass Theme)**:
  - En móviles, el selector ahora se abre como una hoja flotante de cristal líquido (`showGlassSheet`) con esquinas curvadas de 36 px, efecto de refracción óptica en tiempo real y cierre suave por arrastre.
  - Integración nativa con el acabado `Theme` de la aplicación (`GlassFinish.regularDark` / `regularLight`), sincronizando la refracción, desenfoque y tinte dinámico con el tema activo de la interfaz.
  - Corrección de superposición con la barra de estado y notch: el modal respeta los límites seguros de la pantalla (`SafeArea`) sin ocultarse detrás de la barra de estado.
- **Fila Unificada: Proveedor y Stepper de Episodios**:
  - Proveedor y selector de episodios organizados en una sola fila compacta y elegante: a la izquierda el proveedor con desplegable directo, y a la derecha el stepper interactivo con flechas (`<`, `>`) y pastilla de capítulo.
- **Desplegables en Popover Nativo (`GlassPopoverAnchor`)**:
  - Reemplazo de los diálogos a pantalla completa por menús popover nativos de cristal líquido (`GlassPopoverAnchor`) alineados con el tema (`Theme`) que crecen directamente desde cada botón en su lugar (Proveedor, Episodio, Calidad y Ordenación).
- **Eliminación Total de Tintes Azules**:
  - Sustitución de los fondos azulados de las tarjetas de torrents (`TorrentFileCard`) por un acabado grafito neutro semitransparente que se integra con el vidrio líquido sin perder legibilidad ni contraste.
- **Verificación Completa**:
  - 0 incidencias en `flutter analyze lib/` y suite de pruebas aprobada al 100% (246/246 tests).

---

## 7.49. Reproducción Directa desde Seguir Viendo y Control Inteligente de Siguiente Episodio (2026-10-15)
- **Reproducción Directa al Tocar un Episodio en Seguir Viendo**:
  - Al presionar una tarjeta en la sección de Seguir Viendo, se abre inmediatamente el reproductor en el episodio correspondiente sin pasos intermedios, restaurando la posición guardada de reproducción.
  - Se conserva la misma fuente que se utilizó para ver el anime (archivos locales, proveedor online específico con su configuración de doblaje/servidor, o torrent).
- **Persistencia Inteligente de Fuentes por Anime**:
  - Nuevo servicio `AnimePlaybackSourcePreferences` que recuerda de forma persistente la fuente, proveedor y servidor utilizados para cada anime.
  - Detección automática en cascada (Local > Torrent > Online > Proveedor predeterminado) para garantizar una reproducción sin fricciones.
  - Indicador de carga fluido al pulsar la tarjeta y soporte para mantener presionado o hacer clic en el título para abrir la pantalla de detalles.
- **Validación Precisa de Disponibilidad de "Siguiente Episodio"**:
  - Corrección de la disponibilidad del botón y tarjeta de "Siguiente Episodio" en el reproductor de video para evitar mostrar episodios que aún no se han emitido en animes en emisión.
  - Validación con el catálogo real del proveedor para transmisiones online (`OnlinestreamEpisode`) y consulta precisa contra AniList (`nextAiringEpisode`) y AniZip (`airDate` y stubs sin emitir) para torrents y biblioteca.
- **Verificación Completa**:
  - 0 advertencias en `flutter analyze lib/` y suite de pruebas aprobada al 100% (246/246 tests).

---

## 7.48. Optimización del Selector de Fuentes y Continuidad de Reproducción (2026-10-15)
- **Selector Dinámico de Fuentes y Servidores en Vivo**:
  - Cambio fluido de servidor/fuente dentro del modal sin cierres abruptos (`PlayerSourceSelectorSheet`), con actualización reactiva inmediata mediante `ListenableBuilder` e indicador de carga no invasivo.
  - Botón de alternancia rápida entre Doblaje y Subtítulos (`[SUB]` / `[DUB]`) directamente en el selector de reproducción y tarjeta de fuentes.
- **Continuidad y Reanudación Instantánea de Episodios**:
  - Corrección integral de la posición de reanudación al entrar a cualquier episodio online o local, restaurando exactamente el minuto y segundo guardado en la biblioteca.
  - Preservación perfecta del progreso al alternar servidores o cambiar de episodio dentro del reproductor.
- **Verificación Completa**:
  - 0 advertencias en `flutter analyze lib/`.

---

## 7.47. Restauración del Ecosistema de Extensiones Goja (2026-10-15)
- **Restauración de Extensiones Goja en Backend**:
  - Reactivación completa de la arquitectura de extensiones Goja en Seanime con ejecución de scripts TypeScript/JavaScript en el backend.
  - Reintegración de las extensiones del catálogo (`anipm`, `jkanime`, `tioanime`).
- **Marketplace e Instalador Dinámico de Extensiones**:
  - Restauración de la experiencia completa del Marketplace con soporte para múltiples repositorios comunitarios, inspección de código fuente y gestión de extensiones instaladas.
- **Verificación Completa**:
  - Suite de pruebas de extensiones aprobada al 100% y 0 advertencias en `flutter analyze lib/`.

---

## 7.46. Modularización de Fuentes Online Nativas y Selector en Reproductor (2026-10-15)
- **Fuentes Nativas Modulares Separadas (`lib/data/sources/online/`)**:
  - Implementación independiente en archivos dedicados para cada proveedor: `AnitingUniversal`, `KawaiiOnlineSource` (Latino, Castellano y Sub) y `JkAnimeOnlineSource` (StreamWish, VOE).
  - Eliminación de dependencias de ejecutables externos JS para la resolución de transmisiones.
- **Selector de Servidores y Fuentes en el Reproductor**:
  - Restauración de pistas nativas de audio en el reproductor de video.
  - Selección de fuentes y doblajes organizada en el selector inferior (`PlayerSourceSelectorSheet`) con badges de idioma (`LATINO`, `CASTELLANO`, `ENGLISH`, `SUB`) y cambio instantáneo preservando la posición.
- **Gestión Visual de Extensiones**:
  - Inclusión de los 3 proveedores nativos en la pestaña Online de extensiones, marcados como integrados y listos para usar sin descargas.
- **Verificación Completa**:
  - 100% de la suite de pruebas aprobada y 0 advertencias en `flutter analyze lib/`.

---

## 7.45. Fuentes In-App Nativas y Unificación Multi-Audio / Multi-Subtítulos (2026-10-15)
- **Fuentes Nativas en Dart (`lib/data/sources/`)**:
  - Migración a fuentes in-app nativas en Flutter (Online, Torrents, Manga y Series) con clientes directos de alto rendimiento.
  - Resolución inteligente en paralelo: enlaces 1080p en múltiples servidores con extracción en el Edge.
- **Unificación Multi-Audio y Multi-Subtítulos en el Reproductor**:
  - Integración completa de pistas de audio (Español Latino, Español Castellano, Inglés y Japonés original) visibles directamente en los ajustes del reproductor con cambio transparente preservando la posición.
  - Selección de subtítulos suaves (soft subtitles en más de 15 idiomas) sin recarga de video.
  - Insignias visuales de idioma y calidad en el selector de fuentes y servidores.
- **Verificación Completa**:
  - 100% de la suite de pruebas aprobada (250 de 250 pruebas) y 0 problemas en `flutter analyze lib/`.

---

## 7.44. Consolidación de Proveedor Único Universal y Nueva Experiencia de Extensiones (2026-10-15)
- **Proveedor Único Oficial Aniting Universal**:
  - Unificación completa de todas las fuentes de transmisión en línea bajo el proveedor oficial `aniting-universal`.
  - Soporte integrado de transmisiones de alta calidad 1080p, selección multi-audio (Latino, Castellano, Japonés e Inglés) y multi-subtítulos sincronizados.
  - Retiro y purga de scripts y extensiones obsoletas en el repositorio central.
- **Rediseño Esencial de la Pantalla de Extensiones**:
  - Interfaz simplificada y categorizada en tres secciones clave: Transmisión Online, Torrents y Manga.
  - Eliminación de configuraciones complejas de URLs manuales y cuadros de diálogo redundantes.
  - Tarjetas unificadas con control de activación, actualización y gestión simplificada con diseño Material 3 Expressive.
- **Verificación Completa**:
  - 100% de la suite de pruebas aprobada (246 de 246 pruebas) y 0 advertencias en el análisis estático.

---

## 7.43. Limpieza y Consolidación de la Arquitectura de Episodios (2026-10-14)
- **Consolidación Universal de Episodios**:
  - Migración completa de vistas de detalle en escritorio, móvil y TV a la arquitectura universal (`EpisodesView`), unificando la navegación de episodios para series y películas.
  - Eliminación de archivos y widgets redundantes de TMDB (`tmdb_episodes_view.dart`, `tmdb_episode_card.dart`, `tmdb_season_selector.dart`, `tmdb_season_posters_view.dart`).
- **Verificación y Calidad de Código**:
  - 100% de pruebas aprobadas (246 de 246) y cero advertencias en el analizador estático de Flutter.

---

## 7.42. Estabilidad de Red, Resiliencia Offline y Refinamiento Responsivo (2026-10-14)
- **Modo Desconectado y Manejo Robusto de Red**:
  - Resiliencia completa en proveedores de datos (`loadAnimeWithCacheAndSwr`, `loadMangaWithCacheAndSwr`) devolviendo inmediatamente la biblioteca local o caché en memoria sin peticiones de red fantasma ni bloqueos cuando el servidor está detenido.
- **Optimización de Layout en Mis Listas para Escritorio**:
  - Adaptabilidad fluida del buscador superior mediante restricciones responsivas flexibles para prevenir desbordamientos visuales en resoluciones compactas de escritorio.
- **Saneamiento y Cobertura Integral de Pruebas**:
  - Cobertura y aprobación al 100% (246 de 246 pruebas pasando) sincronizando las expectativas del reproductor moderno, hojas de cristal líquido (`GlassHost`), selector de torrents por lotes y estados vacíos.

---

## 7.41. Arquitectura Unificada de Episodios y Restauración de Titlebar Nativo (2026-10-14)
- **Nueva Arquitectura Universal de Episodios**:
  - Modelo y controlador agnósticos de medios (`EpisodeItem`, `EpisodesNotifier`, `EpisodesView`) unificando la lógica de reproducción, progreso y visualización para Anime, Series de TV y Películas.
  - Separación limpia de extensiones y proveedores: control automático para fuentes en línea y trackers de torrents según el tipo de catálogo (Anime vs TMDB).
  - Componente canónico de episodios con soporte dual para vista en cuadrícula (16:9) y lista compacta, filtros de estado y paginación rápida.
- **Barra de Título Nativa del Sistema en Escritorio**:
  - Restauración de la barra de título nativa del sistema operativo en Linux/Wayland (GNOME/KDE), Windows y macOS con soporte completo de botones de control y snapping.
  - Reversión de la barra de título personalizada para máxima compatibilidad con el entorno de escritorio.
  - Restablecimiento de los controles superiores del reproductor en su altura estándar y espaciosa de 44px.

---

## 7.39. Adopción de Material 3 Expressive y Refinamiento de Vidrio Líquido (2026-10-14)
- **Controles Expresivos Material 3**:
  - Botones principales de reproducción, acciones flotantes y barra de herramientas con animaciones elásticas y respuesta háptica visual.
  - Integración armónica de `M3EButton`, `M3EIconButton` y `M3ESwitch` preservando el diseño de cristal líquido existente.
- **Sincronización Dinámica de Vidrio Líquido (`g1455`)**:
  - Corrección en la reactividad de `GlassHost`: ahora propaga explícitamente el acabado óptico y el color de fondo para alternar de inmediato entre temas Claro, Oscuro y OLED.
- **Tema Oscuro Más Profundo (Charcoal Black)**:
  - Fondo del tema oscuro ajustado a un negro carbón profundo (`#0F0F14`) con superficies en `#14141B`, conservando el negro absoluto (`#000000`) exclusivo para OLED.

---

## 7.38. Depuración Limpia de Carpetas Locales y Corrección de Descargas (2026-10-13)
- **Eliminación Total de Archivos al Desvincular Carpetas**:
  - Al remover un directorio local, todos sus archivos y entradas asociadas se purgan de la base de datos y de la colección local simulada.
- **Filtro Riguroso para Descargas**:
  - La sección de descargas en el inicio ahora exige archivos locales válidos en el disco, evitando entradas fantasma sin contenido descargado.
- **Limpieza Inmediata de Cachés**:
  - Invalidación automática de las colecciones y sugerencias en memoria al desvincular directorios para mantener el feed sincronizado al instante.

---

## 7.37. Escáner Híbrido TMDB y Auto-Emparejamiento de Series (2026-10-13)
- **Aislamiento Estricto de Carpetas TMDB vs AniList**:
  - El escáner de anime ahora omite carpetas configuradas como Series TV o Películas para evitar consultas innecesarias y límites de peticiones (rate limiting) en AniList.
- **Auto-Emparejamiento Inteligente con TMDB**:
  - Al escanear carpetas de series o películas, el sistema busca automáticamente las coincidencias en TMDB y vincula las series con sus pósters y temporadas.
- **Estabilidad en Sugerencias y Emparejamiento Manual**:
  - Corrección de fallos inesperados en el servidor al consultar sugerencias de títulos en carpetas locales ya vinculadas o vacías.

---

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
