import 'translations.dart';

class SpanishTranslations implements AppTranslations {
  const SpanishTranslations();

  // Navigation & Shell
  @override
  String get navHome => 'Inicio';
  @override
  String get navExplore => 'Explorar';
  @override
  String get navCalendar => 'Calendario';
  @override
  String get navProfile => 'Perfil';
  @override
  String get navSettings => 'Configuración';
  @override
  String get profile => 'Perfil';
  @override
  String get serverConnected => 'Servidor conectado';
  @override
  String get serverOffline => 'Servidor desconectado';

  // Common
  @override
  String get loading => 'Cargando...';
  @override
  String get error => 'Error';
  @override
  String get retry => 'Reintentar';
  @override
  String get close => 'Cerrar';
  @override
  String get back => 'Volver';
  @override
  String get search => 'Buscar';
  @override
  String get save => 'Guardar';
  @override
  String get cancel => 'Cancelar';
  @override
  String get ok => 'Aceptar';
  @override
  String get refresh => 'Actualizar';
  @override
  String get clear => 'Limpiar';
  @override
  String get user => 'Usuario';
  @override
  String get on => 'Activado';
  @override
  String get off => 'Desactivado';
  @override
  String get delay => 'Desfase';
  @override
  String get reset => 'Restablecer';
  @override
  String get noTitle => 'Sin título';

  // Feed & Home
  @override
  String get feedTitle => 'Inicio';
  @override
  String get continueWatching => 'Seguir Viendo';
  @override
  String get trendingAnime => 'En Tendencia';
  @override
  String get popularThisSeason => 'Popular Esta Temporada';
  @override
  String get popularOfTheMoment => 'Populares del momento';
  @override
  String get recentReleases => 'Últimos Lanzamientos';
  @override
  String get quickSearch => 'Buscar rápido';
  @override
  String get quickSearchHint => 'Buscar anime rápido...';
  @override
  String get quickSearchMangaHint => 'Buscar manga rápido...';
  @override
  String get serverNotConnected => 'Servidor Seanime no conectado';
  @override
  String get serverNotConnectedDesc =>
      'Inicia el servidor local o verifica la conexión para ver el contenido.';
  @override
  String get startServer => 'Iniciar Servidor';
  @override
  String get startLocal => 'Iniciar Local';
  @override
  String get stopServer => 'Detener';
  @override
  String get currentlyWatching => 'Viendo Actualmente';
  @override
  String get missedSequels => 'Secuelas que te perdiste';
  @override
  String get recommendations => 'Te podría gustar';
  @override
  String get discoverAnime => 'Descubrir Anime';
  @override
  String get noEpisodesInProgress =>
      'No hay episodios en curso. Empieza a reproducir un anime para seguirlo aquí.';
  @override
  String get seeMore => 'Ver más';
  @override
  String get seeLess => 'Ver menos';
  @override
  String get reachedTheEnd => 'Has llegado al final • No hay más resultados';
  @override
  String get loginForFeed => 'Inicia sesión para tu feed';
  @override
  String get loginForFeedDesc =>
      'Conecta AniList para continuar episodios y sincronizar tu colección.';
  @override
  String get linkAccount => 'Vincular';
  @override
  String get sortTooltip => 'Ordenar';

  // Continue Watching Sort Modes
  @override
  String get sortRecent => 'Visto recientemente';
  @override
  String get sortAirDateDesc => 'Emisión reciente';
  @override
  String get sortAirDateAsc => 'Emisión antigua';
  @override
  String get sortEpisodeDesc => 'Episodio más alto';
  @override
  String get sortEpisodeAsc => 'Episodio más bajo';
  @override
  String get sortTitle => 'Título (A-Z)';

  // Search
  @override
  String get searchTitle => 'Explorar';
  @override
  String get searchPlaceholder => 'Buscar anime, géneros, estudios...';
  @override
  String get filterAll => 'Todos';
  @override
  String get noResultsFound => 'No se encontraron resultados';
  @override
  String get airingCalendar => 'Calendario de emisión';
  @override
  String get searchAnimePrompt => 'Escribe el nombre de un anime para buscar';
  @override
  String get searchBarHint => 'Buscar anime (ej. Frieren, Naruto, Kimetsu...)';

  // Library & Profile
  @override
  String get libraryTitle => 'Perfil';
  @override
  String get myLists => 'Mis Listas';
  @override
  String get downloads => 'Descargas';
  @override
  String get animeDownloads => 'Descargas de Anime';
  @override
  String get mangaDownloads => 'Descargas de Manga';
  @override
  String get quickSettings => 'Configuraciones Rápidas';
  @override
  String get localLibrary => 'Local';
  @override
  String get serverLibrary => 'Servidor';
  @override
  String get emptyLibrary => 'No hay elementos en tu biblioteca';
  @override
  String get manageAniListAccount => 'Gestionar Cuenta AniList';
  @override
  String get scanLocalFolder => 'Escanear Carpeta Local';
  @override
  String get scanStarted => 'Escaneo iniciado...';
  @override
  String get scanFailed => 'Error al iniciar escaneo';
  @override
  String get statusWatching => 'Viendo';
  @override
  String get statusCompleted => 'Vistos';
  @override
  String get statusPlanning => 'Planeados';
  @override
  String get statusDropped => 'Dropeados';
  @override
  String get statusPaused => 'En Pausa';
  @override
  String get statusAll => 'Todos';
  @override
  String get reading => 'Leyendo';
  @override
  String get emptyLibraryCategory => 'No hay animes en esta categoría';
  @override
  String get emptyLibraryLocal => 'No hay animes en tu biblioteca local aún';
  @override
  String get serverOfflineLibrary =>
      'Inicia el servidor local en Ajustes para cargar tu colección local.';

  // Settings
  @override
  String get settingsTitle => 'Configuración';
  @override
  String get appearanceAndTheme => 'Apariencia y Tema';
  @override
  String get themeAndColors => 'Tema y Colores';
  @override
  String get appearanceAndDisplay => 'Apariencia e Interfaz';
  @override
  String get animeDynamicTheme => 'Tema Adaptativo de Anime';
  @override
  String get animeDynamicThemeDesc =>
      'Usa el color característico de AniList para adaptar la paleta Material Design en la pantalla del anime.';
  @override
  String get themeMode => 'Modo de Tema';
  @override
  String get themeDark => 'Oscuro';
  @override
  String get themeLight => 'Claro';
  @override
  String get themeOled => 'OLED';
  @override
  String get themeSystem => 'Sistema';
  @override
  String get themePresets => 'Paletas de la Comunidad';
  @override
  String get themePresetsDesc => 'Elige una estética cuidada inspirada en la comunidad y tu sistema';
  @override
  String get iconPack => 'Paquete de Iconos';
  @override
  String get iconPackDesc => 'Elige la estética visual de los iconos en toda la aplicación';
  @override
  String get iconPackLucide => 'Lucide (Web / Desktop Moderno)';
  @override
  String get iconPackLucideDesc => 'Iconos outline limpios, estilizados y ligeros tipo web moderna';
  @override
  String get iconPackMaterial => 'Material Symbols (Clásico)';
  @override
  String get iconPackMaterialDesc => 'Iconos redondeados tradicionales de estilo móvil';
  @override
  String get accentColor => 'Color de Acento';
  @override
  String get typography => 'Tipografía y Fuente';
  @override
  String get videoPlayer => 'Reproductor de Video';
  @override
  String get playbackEngine => 'Motor de Reproducción';
  @override
  String get defaultEngine => 'Motor Predeterminado';
  @override
  String get defaultEngineDesc =>
      'ExoPlayer está optimizado para Android con aceleración directa y libass para subtítulos complejos (.ass). Si un formato o códec no es compatible, conmuta automáticamente a libmpv.';
  @override
  String get appLanguage => 'Idioma de la Aplicación';
  @override
  String get appLanguageDesc => 'Elige tu idioma preferido para la interfaz';
  @override
  String get serverSettings => 'Servidor Seanime';
  @override
  String get extensionsTitle => 'Extensiones';
  @override
  String get preferences => 'Preferencias';
  @override
  String get system => 'Sistema';
  @override
  String get info => 'Información';
  @override
  String get appearanceSubtitle => 'Tema, colores de acento, títulos y vistas';
  @override
  String get extensionsSubtitle => 'Marketplace, proveedores online y repositorios';
  @override
  String get streamingSources => 'Fuentes de Streaming';
  @override
  String get streamingSourcesSubtitle => 'Activar o desactivar Torrent y Streaming Online';
  @override
  String get serverAndNetwork => 'Servidor Seanime y Red';
  @override
  String get serverAndNetworkSubtitle => 'Servidor local, conexión remota IP y rendimiento';
  @override
  String get aboutApp => 'Acerca de Aniting';
  @override
  String get aboutSubtitle => 'Cliente nativo Aniting Flutter';
  @override
  String get aboutLegalese => 'Cliente nativo para gestión y reproducción de anime.';

  // Appearance & Personalization
  @override
  String get accentColorPalette => 'Color de Acento (Paleta Tonal M3)';
  @override
  String get themeAccentDefault => 'Predeterminado del Tema';
  @override
  String get fontStyle => 'Estilo de Fuente';
  @override
  String get fontStyleDesc => 'Selecciona la tipografía que se utilizará en toda la interfaz.';
  @override
  String get livePreview => 'Vista previa en vivo';
  @override
  String get fontPangram => 'El veloz murciélago hindú comía feliz cardillo y kiwi. 1234567890';
  @override
  String get preferredTitleLanguage => 'Idioma Preferido para Títulos';
  @override
  String get preferredTitleLanguageDesc =>
      'Selecciona cómo se mostrarán los nombres de los animes en toda la aplicación.';
  @override
  String get titleExample => 'Ejemplo';
  @override
  String get titleRomaji => 'Romaji';
  @override
  String get titleEnglish => 'Inglés';
  @override
  String get titleNative => 'Nativo';
  @override
  String get episodeDisplay => 'Visualización de Episodios';
  @override
  String get episodeDisplayDesc =>
      'Elige si prefieres ver los episodios en una lista detallada o en cuadrícula compacta.';
  @override
  String get detailedList => 'Lista detallada';
  @override
  String get grid => 'Cuadrícula';
  @override
  String get desktopScrollbar => 'Barra de Desplazamiento (PC)';
  @override
  String get desktopScrollbarDesc => 'Mostrar barra de scroll arrastrable en escritorio';
  @override
  String get mobileNavStyle => 'Estilo de Barra Móvil';
  @override
  String get mobileNavStyleDesc => 'Elige entre la barra de navegación fija clásica o el dock flotante';
  @override
  String get mobileNavStyleFloating => 'Flotante (Dock)';
  @override
  String get mobileNavStyleClassic => 'Fija tradicional';
  @override
  String get showScores => 'Mostrar Puntuaciones';
  @override
  String get showScoresDesc => 'Muestra la calificación con estrellas en las portadas de contenido';
  @override
  String get floatingResumeBar => 'Sigue donde te quedaste';
  @override
  String get floatingResumeBarDesc => 'Muestra una barra flotante para reanudar al instante el último anime o manga';

  // Player Settings
  @override
  String get audioAndGestures => 'Audio y Gestos';
  @override
  String get volumeBoost => 'Amplificación de Volumen (>100%)';
  @override
  String get volumeBoostDesc =>
      'Permite subir el volumen hasta 200% mediante gestos en pantalla con refuerzo de audio nativo.';
  @override
  String get exoplayerDesc =>
      'Aceleración por hardware nativa, menor consumo de batería, soporte .ass con libass y respaldo a libmpv.';
  @override
  String get mpvDesc =>
      'Motor universal con soporte integral para todos los codecs, subtítulos y filtros.';

  // Streaming Sources Settings
  @override
  String get playbackMethods => 'Métodos de Reproducción';
  @override
  String get torrentStreaming => 'Torrent Streaming';
  @override
  String get torrentStreamingDesc =>
      'Búsqueda y reproducción directa de torrents (BitTorrent / Debrid). Al desactivarlo se oculta la pestaña Torrent en los animes.';
  @override
  String get onlineStreaming => 'Online Streaming';
  @override
  String get onlineStreamingDesc =>
      'Reproducción mediante proveedores y extensiones online instaladas. Al desactivarlo se oculta la pestaña Online en los animes.';
  @override
  String get streamingSourcesNotice =>
      'Si desactivas una fuente, no aparecerá en la pantalla de detalles de ningún anime. Si ambas están desactivadas, solo podrás reproducir archivos de tu biblioteca local.';
  @override
  String get torrentStorageSection => 'Almacenamiento y Caché de Torrents';
  @override
  String get workingDirectoryTitle => 'Directorio de trabajo / caché';
  @override
  String get workingDirectoryDesc =>
      'Ruta donde se guardan temporalmente los vídeos y datos de los torrents.';
  @override
  String get autoDeletePreviousTitle => 'Auto-eliminar torrents anteriores';
  @override
  String get autoDeletePreviousDesc =>
      'Conserva solo 1 torrent a la vez. Al reproducir o iniciar un nuevo torrent, borra automáticamente los archivos y carpetas del torrent anterior del disco para ahorrar espacio.';
  @override
  String get defaultDirectoryHint => 'Por defecto (~/.cache/seanime/torrentstream en SSD)';
  @override
  String get savePath => 'Guardar ruta';
  @override
  String get resetPath => 'Restaurar por defecto';

  // Server & Network Settings
  @override
  String get localServer => 'Servidor Local';
  @override
  String get remoteConnection => 'Conexión Remota (PC / Servidor en Red)';
  @override
  String get hostIp => 'Host / Dirección IP';
  @override
  String get hostHint => '127.0.0.1 o IP local de tu PC';
  @override
  String get port => 'Puerto';
  @override
  String get testAndSave => 'Probar y Guardar';
  @override
  String get testingConnection => 'Probando conexión...';
  @override
  String get androidPerfAndPerms => 'Rendimiento y Permisos en Android';
  @override
  String get batteryOpt => 'Segundo Plano (Ahorro de Batería)';
  @override
  String get batteryOptDisabled => 'Optimización desactivada (el servidor no se apagará)';
  @override
  String get batteryOptEnabled => 'Optimización activa (Android puede pausar el servidor)';
  @override
  String get disableOptimization => 'Desactivar Optimización';
  @override
  String get storageAccess => 'Acceso a Archivos y Descargas';
  @override
  String get storageAccessGranted => 'Permiso concedido para guardar torrents y anime';
  @override
  String get storageAccessDenied => 'Sin permiso completo de almacenamiento';
  @override
  String get grantStorageAccess => 'Conceder Acceso a Archivos';
  @override
  String get coreVersion => 'Versión de Core';

  // Extensions & Marketplace
  @override
  String get installed => 'Instaladas';
  @override
  String get marketplace => 'Marketplace';
  @override
  String get checkForUpdates => 'Buscar Actualizaciones';
  @override
  String get reloadAll => 'Recargar Todo';
  @override
  String get configureRepo => 'Configurar Repositorio';
  @override
  String get noInstalledExtensions => 'No hay extensiones instaladas';
  @override
  String get noInstalledExtensionsDesc =>
      'Explora el Marketplace para instalar proveedores y extensiones de streaming de anime.';
  @override
  String get exploreMarketplace => 'Explorar Marketplace';
  @override
  String get install => 'Instalar';
  @override
  String get uninstall => 'Desinstalar';
  @override
  String get update => 'Actualizar';
  @override
  String get viewCode => 'Ver Código';
  @override
  String get enable => 'Activar';
  @override
  String get disable => 'Desactivar';
  @override
  String get allExtensionsUpToDate => 'Todas las extensiones instaladas están al día.';
  @override
  String get updatesFound => 'actualización(es) disponibles!';

  // Anime Detail & Full Details
  @override
  String get exitLocalMode => 'Salir de Modo Local';
  @override
  String get enterLocalMode => 'Modo Local (Archivos)';
  @override
  String get animeDetails => 'Detalles del anime';
  @override
  String get synopsis => 'Sinopsis';
  @override
  String get characters => 'Personajes y Elenco';
  @override
  String get character => 'Personaje';
  @override
  String get relations => 'Relaciones y Obras Conectadas';
  @override
  String get staff => 'Equipo Principal (Staff)';
  @override
  String get rankings => 'Rankings y Estadísticas';
  @override
  String get averageScore => 'Score Promedio';
  @override
  String get anilistMean => 'Media AniList';
  @override
  String get format => 'Formato';
  @override
  String get episodes => 'Episodios';
  @override
  String get durationPerEp => 'Duración/ep';
  @override
  String get status => 'Estado';
  @override
  String get season => 'Temporada';
  @override
  String get studio => 'Estudio';
  @override
  String get mainRole => 'Principal';
  @override
  String get supportingRole => 'Secundario';
  @override
  String get streamingDisabledTitle => 'Fuentes de streaming desactivadas';
  @override
  String get streamingDisabledDesc =>
      'Has desactivado Torrent y Online Streaming en Ajustes. Para ver episodios, activa al menos una fuente en Ajustes > Fuentes de Streaming.';

  // Local Library View & Episodes
  @override
  String get checkingLocalFiles => 'Comprobando archivos locales...';
  @override
  String get downloadedFiles => 'Archivos Descargados';
  @override
  String get localEpisodes => 'episodios locales';
  @override
  String get switchToGrid => 'Cambiar a cuadrícula';
  @override
  String get switchToList => 'Cambiar a lista';
  @override
  String get notInLocalLibrary => 'No está en tu biblioteca local';
  @override
  String get notInLocalLibraryDesc =>
      'No se encontraron episodios descargados localmente para este anime en tu servidor de Seanime.';
  @override
  String get watchOnlineStream => 'Ver en Streaming Online';
  @override
  String get searchTorrents => 'Buscar Torrents';
  @override
  String get orderAsc => 'Orden: 1 a N';
  @override
  String get orderDesc => 'Orden: N a 1';
  @override
  String get searchEpisodePlaceholder => 'Buscar por título o número de episodio...';
  @override
  String get noEpisodesFoundMatching => 'No se encontraron episodios que coincidan con';
  @override
  String get noAiredEpisodesAvailable => 'No hay episodios emitidos disponibles en esta sección.';

  // Online Stream & Torrent Selector
  @override
  String get onlineProvider => 'Proveedor';
  @override
  String get changeProvider => 'Cambiar proveedor';
  @override
  String get tapToChangeProvider => 'Toca para cambiar proveedor';
  @override
  String get sub => 'Sub';
  @override
  String get dub => 'Dub';
  @override
  String get selectSource => 'Seleccionar Fuente de Video';
  @override
  String get allProviders => 'Todos los proveedores';
  @override
  String get smartSearch => 'Búsqueda Inteligente';
  @override
  String get simpleSearch => 'Búsqueda Simple';
  @override
  String get searchQueryHint => 'Término de búsqueda...';
  @override
  String get seeds => 'Seeds';
  @override
  String get leech => 'Leech';
  @override
  String get size => 'Tamaño';
  @override
  String get noTorrentsFound => 'No se encontraron torrents';
  @override
  String get noTorrentsFoundDesc => 'Prueba cambiando de proveedor o usando la búsqueda simple.';

  // AniList Authentication Sheet
  @override
  String get anilistLoginTitle => 'Iniciar sesión con AniList';
  @override
  String get anilistLoginDesc =>
      'Sincroniza tu lista, progreso de episodios y notas en tiempo real.';
  @override
  String get openInBrowser => 'Abrir AniList en el navegador';
  @override
  String get pasteTokenDivider => 'Pega el token generado';
  @override
  String get tokenPlaceholder => 'Pega aquí el token o la URL de redirección...';
  @override
  String get linkAccountBtn => 'Vincular Cuenta';
  @override
  String get disconnectAccount => 'Desconectar Cuenta';
  @override
  String get accountSynced => 'Cuenta Sincronizada';
  @override
  String get viewProfileOnAnilist => 'Ver Perfil en AniList';
  @override
  String get tokenPasted => 'Token pegado desde el portapapeles.';
  @override
  String get clipboardEmpty => 'El portapapeles está vacío.';

  // Server Status Banner
  @override
  String get serverActiveLocal => 'Servidor Local Activo';
  @override
  String get serverActiveRemote => 'Conectado a Servidor Remoto';
  @override
  String get serverStarting => 'Iniciando / Conectando al servidor...';

  // Video Player
  @override
  String get playbackStats => 'Stats de Reproducción';
  @override
  String get chapters => 'Capítulos';
  @override
  String get audioTracks => 'Pistas de Audio';
  @override
  String get subtitleTracks => 'Subtítulos';
  @override
  String get subtitleSync => 'Sync de Subtítulos';
  @override
  String get audioSync => 'Sync de Audio';
  @override
  String get playbackSpeed => 'Velocidad';
  @override
  String get shaders => 'Shaders GLSL';
  @override
  String get mode => 'Modo';
  @override
  String get nextEpisode => 'Siguiente episodio';
  @override
  String get mute => 'Silenciar';
  @override
  String get unmute => 'Activar sonido';
  @override
  String get showInfo => 'Mostrar información';
  @override
  String get collapsePanel => 'Colapsar panel';
  @override
  String get playbackSources => 'Opciones de reproducción';
  @override
  String get searchingSources => 'Buscando opciones...';
  @override
  String get playingFirstAvailable => 'Reproduciendo primera opción encontrada';
  @override
  String get tapToChangeSource => 'Toca para cambiar de servidor o calidad';
  @override
  String get reloadSourcesTooltip => 'Recargar fuentes';
  @override
  String get noSourcesFoundForEpisode => 'No se encontraron opciones de reproducción para este episodio';
  @override
  String get availableSourcesCount => 'opciones disponibles';
  @override
  String get aspectRatio => 'Ajuste de Pantalla';
  @override
  String get screenFit => 'Ajuste de Pantalla';
  @override
  String get videoSource => 'Fuente de Video';
  @override
  String get performanceStats => 'Stats en pantalla';
  @override
  String get gestures => 'Gestos en pantalla';
  @override
  String get torrentDownloadProgress => 'Progreso del Torrent';
  @override
  String get downloadSpeed => 'Descarga';
  @override
  String get uploadSpeed => 'Subida';
  @override
  String get seedersPeers => 'Peers';
  @override
  String get remainingTime => 'Faltan';
  @override
  String get completed => 'Completado';
  @override
  String get switchingToMpvNotice => 'Conmutando a libmpv por compatibilidad de formato...';
  @override
  String get noChapters => 'No hay capítulos disponibles';
  @override
  String get noAudioTracks => 'No se encontraron pistas de audio';
  @override
  String get noSubtitleTracks => 'No se encontraron pistas de subtítulos';
  @override
  String get fitContain => 'Ajustar';
  @override
  String get fitCover => 'Rellenar (Recortar)';
  @override
  String get fitFill => 'Estirar pantalla';

  // Additional Player & Control getters
  @override
  String get episode => 'Episodio';
  @override
  String get play => 'Reproducir';
  @override
  String get pause => 'Pausar';
  @override
  String get fullScreen => 'Pantalla completa';
  @override
  String get exitFullScreen => 'Salir de pantalla completa';
  @override
  String get reduceToModal => 'Reducir a modal';
  @override
  String get watching => 'Viendo';
  @override
  String get forward10s => 'Avanzar 10s';
  @override
  String get rewind10s => 'Retroceder 10s';
  @override
  String get synchronized => 'Sincronizado';
  @override
  String get resetTo0ms => 'Restablecer a 0 ms';
  @override
  String get skipOpening => 'Saltar Opening';
  @override
  String get skipEnding => 'Saltar Ending';
  @override
  String get skipCredits => 'Saltar Créditos';
  @override
  String get skipIntro => 'Saltar Intro';
  @override
  String get skipPreview => 'Saltar Avance';
  @override
  String get skip => 'Saltar';
  @override
  String get disableSubtitles => 'Desactivar subtítulos';
  @override
  String get copyPath => 'Copiar ruta';
  @override
  String get copyLink => 'Copiar enlace';
  @override
  String get pathCopied => 'Ruta copiada al portapapeles';
  @override
  String get linkCopied => 'Enlace copiado al portapapeles';
  @override
  String get codeCopied => 'Código copiado al portapapeles.';
  @override
  String get sourceFile => 'Archivo Local';
  @override
  String get sourceStream => 'Transmisión Online';
  @override
  String get sourceTorrent => 'Streaming Torrent';
  @override
  String get playbackEngineLabel => 'Motor de reproducción:';
  @override
  String get filePathLabel => 'Ruta del archivo:';
  @override
  String get sourceUrlLabel => 'Enlace / URL de origen:';
  @override
  String get shadersRequireMpv => 'Los shaders GLSL requieren el motor libmpv.';
  @override
  String get subtitleSyncDesc =>
      'Ajusta el retardo para adelantar o retrasar los subtítulos respecto al video.';
  @override
  String get audioSyncDesc =>
      'Ajusta el desfase de la pista de audio con el video.';
  @override
  String get closeSettings => 'Cerrar ajustes';
  @override
  String get defaultOption => 'Por defecto';
  @override
  String get disabled => 'Desactivado';
  @override
  String get embedded => 'Integrado';
  @override
  String get parts => 'partes';
  @override
  String get normal => 'Normal';
  @override
  String get unknown => 'Desconocido';
  @override
  String get engine => 'Motor';
  @override
  String get videoCodec => 'Códec Video';
  @override
  String get resolution => 'Resolución';
  @override
  String get droppedFrames => 'Cuadros perdidos';
  @override
  String get hwDecoder => 'Decodificador (HW)';
  @override
  String get videoBitrate => 'Bitrate Video';
  @override
  String get audioBitrate => 'Bitrate Audio';
  @override
  String get demuxerCache => 'Caché Demuxer';
  @override
  String get subtitles => 'Subtítulos';
  @override
  String get automatic => 'Automático';
  @override
  String get playerSettings => 'Ajustes';
  @override
  String get source => 'Fuente';
  @override
  String get subtitleSyncTitle => 'Sincronización de Subtítulos';
  @override
  String get audioSyncTitle => 'Sincronización de Audio';
  @override
  String get onBadge => 'On';
  @override
  String get offBadge => 'Off';

  // Additional AniList Auth getters
  @override
  String get couldNotOpenBrowser => 'No se pudo abrir el navegador web.';
  @override
  String get errorOpeningBrowser => 'Error abriendo navegador:';
  @override
  String get pasteTokenOrUrlPrompt =>
      'Por favor pega el token o el enlace de redirección de AniList.';
  @override
  String get tokenIncompletePrompt =>
      'El token parece estar incompleto. En AniList mantén presionado y pulsa "Seleccionar todo", o copia la URL completa de la barra del navegador.';
  @override
  String get loginSuccessAnilist => '¡Sesión iniciada con AniList exitosamente!';
  @override
  String get failedToLinkAccount =>
      'No se pudo vincular la cuenta. Revisa que el token no haya expirado y esté completo.';
  @override
  String get logoutConfirmTitle => 'Cerrar Sesión';
  @override
  String get logoutConfirmContent =>
      '¿Estás seguro de que deseas desconectar tu cuenta de AniList?';
  @override
  String get sessionLoggedOut => 'Sesión cerrada correctamente.';
  @override
  String get anilistUser => 'Usuario AniList';

  // Additional Server Status getters
  @override
  String get serverDisconnected => 'Servidor desconectado';

  // Additional Quick Search getters
  @override
  String get quickSearchPrompt => 'Escribe el título de un anime para comenzar';
  @override
  String get quickSearchMangaPrompt => 'Escribe el título de un manga para comenzar';
  @override
  String get noResultsFor => 'Sin resultados para';

  // Additional Local Library & Episodes getters
  @override
  String get episodesCountSuffix => 'episodios';
  @override
  String get availableCount => 'disponibles';
  @override
  String get searchEpisode => 'Buscar episodio';
  @override
  String get sort1toN => 'Orden: 1 a N';
  @override
  String get sortNto1 => 'Orden: N a 1';
  @override
  String get episodeSynopsis => 'Sinopsis del episodio';
  @override
  String get noDescriptionAvailable =>
      'Sin descripción disponible para este episodio.';
  @override
  String get filler => 'RELLENO';
  @override
  String get viewExtendedDetails => 'Ver ficha extendida';
  @override
  String get retryAniZip => 'Reintentar AniZip';
  @override
  String get noEpisodesAniZipOrLocal =>
      'No se encontraron episodios en AniZip ni localmente.';
  @override
  String get noEpisodesAniZipDesc =>
      'Puedes buscar torrents o intentar volver a sincronizar la información de AniZip.';

  // Additional Extensions & Marketplace getters
  @override
  String get pluginExtensionsNotSupported =>
      'Las extensiones de tipo plugin no están soportadas.';
  @override
  String get invalidManifestUrl =>
      'Esta extensión no tiene una URL de manifiesto válida.';
  @override
  String get extensionInstalledSuccessfully => 'se instaló correctamente.';
  @override
  String get extensionInstallFailed =>
      'Error al instalar. Verifica que el servidor Seanime esté en ejecución.';
  @override
  String get extensionUninstallTitle => 'Desinstalar extensión';
  @override
  String get extensionUninstallConfirm => '¿Deseas desinstalar';
  @override
  String get extensionUninstalled => 'desinstalada.';
  @override
  String get extensionUpdating => 'Actualizando';
  @override
  String get extensionUpdateSuccess => 'actualizada con éxito.';
  @override
  String get extensionUpdateFailed => 'Error al actualizar';
  @override
  String get extensionsReloadSuccess => 'Extensiones recargadas con éxito.';
  @override
  String get extensionsReloadFailed => 'Error al recargar extensiones.';
  @override
  String get allExtensionsUpToDateLong =>
      'Todas las extensiones instaladas están al día.';
  @override
  String get availableUpdatesCount => 'actualización(es) disponibles!';
  @override
  String get repoConfigTitle => 'Configuración de Repositorio';
  @override
  String get repoUrlLabel => 'URL del Repositorio Marketplace (JSON)';
  @override
  String get restoreDefaultRepo => 'Restablecer repositorio por defecto';
  @override
  String get manualInstallManifest => 'Instalación manual de extensión (.json)';
  @override
  String get installManifest => 'Instalar Manifiesto';
  @override
  String get saveAndLoad => 'Guardar y Cargar';
  @override
  String get sourceLabel => 'Fuente:';
  @override
  String get allTypes => 'Todos los Tipos';
  @override
  String get allLanguages => 'Todos los Idiomas';
  @override
  String get animeTorrents => 'Torrents Anime';
  @override
  String get manga => 'Manga';
  @override
  String get onlineStreamingTab => 'Streaming Online';
  @override
  String get customSources => 'Fuentes Personalizadas';
  @override
  String get searchExtensionsHint => 'Buscar extensiones...';
  @override
  String get installedCardLabel => 'Instalada';
  @override
  String get byAuthor => 'por';
  @override
  String get updateAvailable => 'Actualización disponible';
  @override
  String get viewSourceCode => 'Ver código fuente';
  @override
  String get sourceCodeNotLoaded =>
      'No se pudo cargar el código fuente de esta extensión.';
  @override
  String get copyCode => 'Copiar código';
  @override
  String get codeCopiedToClipboard => 'Código copiado al portapapeles.';
  @override
  String get loadingMarketplaceRepo =>
      'Cargando repositorio del Marketplace...';
  @override
  String get changeRepo => 'Cambiar Repositorio';
  @override
  String get noExtensionsFound => 'No se encontraron extensiones';
  @override
  String get noExtensionsFoundDesc =>
      'Intenta buscar con otra palabra clave o cambia el filtro.';

  // Additional Torrent & Online Streaming getters
  @override
  String get loadingProviders => 'Cargando proveedores...';
  @override
  String get searchingTorrentsInProviders =>
      'Buscando torrents en proveedores...';
  @override
  String get searchingTorrents => 'Buscando torrents...';
  @override
  String get resultsFound => 'resultados encontrados';
  @override
  String get noTorrentsForEpisode =>
      'No se encontraron torrents para este episodio.';
  @override
  String get trySimpleSearchOrProvider =>
      'Prueba cambiando a "Búsqueda Simple" o seleccionando otro proveedor.';
  @override
  String get openInExternalPlayer => 'Abrir en MPV externo';
  @override
  String get playInApp => 'Reproducir en la app';
  @override
  String get bestRelease => 'MEJOR RELEASE';
  @override
  String get openingExternalPlayer =>
      'Abriendo en reproductor externo (MPV)...';
  @override
  String get serverNotOnline => 'El servidor Seanime no está en línea.';
  @override
  String get failedToStartTorrent => 'No se pudo iniciar el stream del torrent.';
  @override
  String get loadingStreamingExtensions =>
      'Cargando extensiones de streaming...';
  @override
  String get noOnlineExtensionsInstalled =>
      'No hay extensiones de streaming online instaladas';
  @override
  String get noOnlineExtensionsInstalledDesc =>
      'Para ver episodios en streaming online, instala una extensión de proveedor (como AnimePahe, Gogoanime o Consumet) desde la Marketplace.';
  @override
  String get openExtensionsMarketplace => 'Abrir Marketplace de Extensiones';
  @override
  String get audioDubbed => 'Audio: Doblado (toca para subtitulado)';
  @override
  String get audioSubtitled => 'Audio: Subtitulado (toca para doblado)';
  @override
  String get manualMappingActive => 'Vinculación manual activa:';
  @override
  String get linkAnimeManually =>
      'Vincular anime manualmente con el proveedor';
  @override
  String get reloadEpisodes => 'Recargar episodios';
  @override
  String get filterEpisodesHint =>
      'Filtrar episodios por número o título...';
  @override
  String get selectServerQuality => 'Seleccionar Servidor / Calidad';
  @override
  String get quality => 'Calidad:';
  @override
  String get server => 'Servidor';
  @override
  String get noVideoSourcesFound =>
      'No se encontraron fuentes de video para el episodio';
  @override
  String get errorGettingSources => 'Error al obtener fuentes:';
  @override
  String get clearCacheAndRetry => 'Limpiar caché y reintentar';
  @override
  String get searchAndLinkIn => 'Buscar y vincular en';
  @override
  String get linkWith => 'Vincular con';
  @override
  String get searchAndSelectInProvider =>
      'Busca y selecciona el anime en el proveedor';
  @override
  String get linkedTo => 'Vinculado a:';
  @override
  String get unlink => 'Desvincular';
  @override
  String get linkRemoved => 'Vinculación eliminada';
  @override
  String get searchingProviderCatalog =>
      'Buscando en el catálogo del proveedor...';
  @override
  String get searchPromptMapping =>
      'Escribe un término y pulsa "Buscar" o toca una de las sugerencias.';
  @override
  String get animeLinkedSuccess => 'Anime vinculado con éxito a';
  @override
  String get linked => 'Vinculado';
  @override
  String get link => 'Vincular';
  @override
  String get searchAnimePlaceholder => 'Ej: Frieren, Dandadan, Bleach...';
  @override
  String get tapToEdit => 'Toca para editar';
  @override
  String get errorLoadingEpisodes => 'Error al cargar episodios:';
  @override
  String noEpisodesFoundAuto(String provider) =>
      'No se encontraron episodios automáticamente con "$provider".\nPuedes buscar y vincular el anime manualmente o probar con otro proveedor.';
  @override
  String noAnimeFoundInProvider(String provider, String query) =>
      'No se encontraron animes en "$provider" para "$query". Prueba buscando con palabras clave más cortas o con el nombre en español/romaji.';
  @override
  String noEpisodesInProvider(String provider) =>
      'No se encontraron episodios en "$provider".';


  // Status & Season & Relation formatters
  @override
  String get statusFinished => 'Finalizado';
  @override
  String get statusReleasing => 'En emisión';
  @override
  String get statusNotYetReleased => 'Próximamente';
  @override
  String get statusCancelled => 'Cancelado';
  @override
  String get statusHiatus => 'En pausa';

  @override
  String get seasonWinter => 'Invierno';
  @override
  String get seasonSpring => 'Primavera';
  @override
  String get seasonSummer => 'Verano';
  @override
  String get seasonFall => 'Otoño';

  @override
  String get relSequel => 'Secuela';
  @override
  String get relPrequel => 'Precuela';
  @override
  String get relSideStory => 'Historia Paralela';
  @override
  String get relSpinOff => 'Spin-off';
  @override
  String get relAlternative => 'Versión Alternativa';
  @override
  String get relParent => 'Historia Principal';
  @override
  String get relSummary => 'Resumen';
  @override
  String get relAdaptation => 'Adaptación';
  @override
  String get relCharacter => 'Personaje';
  @override
  String get relOther => 'Relacionado';

  @override
  String get continueReading => 'Continuar Leyendo';
  @override
  String get currentlyReading => 'Leyendo Actualmente';
  @override
  String get completedManga => 'Mangas Completados';
  @override
  String get trendingManga => 'Manga en Tendencia';
  @override
  String get popularManga => 'Manga Popular';
  @override
  String get discoverManga => 'Descubrir Manga';
  @override
  String get chapter => 'Capítulo';
  @override
  String get noMangaProviders => 'No hay extensiones de manga instaladas';
  @override
  String get readChapter => 'Leer';
  @override
  String get nextPage => 'Siguiente';
  @override
  String get previousPage => 'Anterior';

  // Airing Calendar & Genres
  @override
  String get genresTitle => 'Géneros';
  @override
  String get exploreGenres => 'Explorar por Género';
  @override
  String get today => 'Hoy';
  @override
  String get tomorrow => 'Mañana';
  @override
  String get sortTrending => 'Tendencias';
  @override
  String get sortScore => 'Puntuación';
  @override
  String get sortPopularity => 'Popularidad';
  @override
  String get sortStartDate => 'Más Recientes';
  @override
  String get sortBy => 'Ordenar por';
  @override
  String get filterByYear => 'Filtrar por año';
  @override
  String get allYears => 'Todos los años';
  @override
  String get episodesUpcoming => 'Próximos episodios';
  @override
  String get anime => 'Anime';
  @override
  String get curatedRomance => 'Romance & Vida Diaria';
  @override
  String get curatedAction => 'Acción & Shonen';
  @override
  String get curatedFantasy => 'Fantasía & Isekai';
  @override
  String get curatedMovies => 'Películas Destacadas';
  @override
  String get curatedTopRated => 'Mejor Calificados';
  @override
  String get noAiringToday => 'No hay episodios programados para este día';
  @override
  String get filters => 'Filtros';
  @override
  String get applyFilters => 'Aplicar Filtros';
  @override
  String get clearFilters => 'Limpiar Filtros';
  @override
  String get selectGenresAndTags => 'Géneros y Etiquetas';
  @override
  String get allGenres => 'Todos los Géneros';
  @override
  String get tagsTitle => 'Etiquetas';
  @override
  String get formatTitle => 'Formato';
  @override
  String get seasonTitle => 'Temporada';
  @override
  String get statusTitle => 'Estado';
  @override
  String get yearTitle => 'Año';
  @override
  String get curatedRomanceManga => 'Manga de Romance & Drama';
  @override
  String get curatedActionManga => 'Manga de Acción & Aventura';
  @override
  String get curatedFantasyManga => 'Manga de Fantasía & Isekai';
  @override
  String get formatTv => 'Serie de TV';
  @override
  String get formatMovie => 'Película';
  @override
  String get formatOva => 'OVA';
  @override
  String get formatOna => 'ONA';
  @override
  String get formatSpecial => 'Especial';
  @override
  String get formatManga => 'Manga';
  @override
  String get formatNovel => 'Novela Ligera';
  @override
  String get formatOneShot => 'One-shot';
  @override
  String get allFormats => 'Todos los Formatos';
  @override
  String get allStatuses => 'Todos los Estados';
  @override
  String get allSeasons => 'Todas las Temporadas';
  @override
  String get activeFilters => 'Filtros Activos';

  // Onboarding / Welcome screen
  @override
  String get welcomeTitle => 'Bienvenido a Aniting';
  @override
  String get welcomeSubtitle => 'Configura tu experiencia a tu gusto en unos simples pasos.';
  @override
  String get welcomeStepLanguage => 'Idioma';
  @override
  String get welcomeStepTheme => 'Apariencia';
  @override
  String get welcomeStepPreferences => 'Preferencias';
  @override
  String get welcomeStepExtensions => 'Extensiones';
  @override
  String get welcomeStepAnilist => 'AniList';
  @override
  String get welcomeSkip => 'Omitir';
  @override
  String get welcomeSkipAll => 'Saltar';
  @override
  String get welcomeNext => 'Continuar';
  @override
  String get welcomeBack => 'Atrás';
  @override
  String get welcomeFinish => 'Comenzar a explorar';
  @override
  String get welcomeDevPreview => 'Asistente de Bienvenida (Dev)';
  @override
  String get welcomeResetDone => 'Asistente de bienvenida restablecido. Se mostrará en el próximo inicio.';
  @override
  String get welcomeResetPrompt => 'Restablecer pantalla de bienvenida';
  @override
  String get welcomeLanguagePrompt => 'Selecciona el idioma principal de la aplicación';
  @override
  String get welcomeThemePrompt => 'Elige el estilo visual y la paleta que más te guste';
  @override
  String get welcomeTitleLangPrompt => 'Formato preferido para los nombres de anime';
  @override
  String get welcomeStreamingModePrompt => '¿Cómo prefieres reproducir tus animes?';
  @override
  String get welcomeModeBoth => 'Ambos (Recomendado)';
  @override
  String get welcomeModeBothDesc => 'Accede a torrents peer-to-peer y servidores de streaming online';
  @override
  String get welcomeModeOnline => 'Solo Online';
  @override
  String get welcomeModeOnlineDesc => 'Reproduce directamente desde servidores web sin usar torrents';
  @override
  String get welcomeModeTorrent => 'Solo Torrent';
  @override
  String get welcomeModeTorrentDesc => 'Streaming P2P de alta fidelidad y máxima calidad';
  @override
  String get welcomeExtensionsPrompt => 'Extensiones recomendadas para comenzar a ver y leer';
  @override
  String get welcomeInstallAll => 'Instalar seleccionadas';
  @override
  String get welcomeInstalledCount => 'instaladas';
  @override
  String get welcomeAnilistPrompt => 'Conecta tu cuenta de AniList para sincronizar tu progreso y listas';
  @override
  String get welcomeAnilistConnected => '¡Cuenta vinculada con éxito!';
  @override
  String get welcomeAnilistSkip => 'Continuar sin cuenta (Omitir)';
  @override
  String get themeSectionDark => 'Temas Oscuros';
  @override
  String get themeSectionLight => 'Temas Claros';
  @override
  String get themeSectionMaterial => 'Material Design 3';
  @override
  String get exploreAllMarketplace => 'Explorar catálogo completo';
  @override
  String get allRecommended => 'Todas las recomendadas';
  @override
  String get searchExtensionsPrompt => 'Buscar extensiones...';
  @override
  String get blurBanner => 'Desenfocar banner';
  @override
  String get blurBannerDesc => 'Aplica un desenfoque cinemático al banner de fondo en los detalles de anime y manga';
  @override
  String get cornerRadius => 'Esquinas';
  @override
  String get welcomeAnilistTitle => 'Sincronización con AniList';
  @override
  String get welcomeAnilistSyncDesc => 'Sincroniza animes, mangas, episodios y puntuaciones en tiempo real.';
  @override
  String get welcomeExtensionsEmptyHint => 'Podrás explorar e instalar extensiones desde la tienda en cualquier momento.';
  @override
  String get settingsSaved => 'Configuración guardada correctamente';

  @override
  String formatStatus(String? status) {
    if (status == null || status.isEmpty) return '';
    switch (status.toUpperCase()) {
      case 'FINISHED':
        return statusFinished;
      case 'RELEASING':
        return statusReleasing;
      case 'NOT_YET_RELEASED':
        return statusNotYetReleased;
      case 'CANCELLED':
        return statusCancelled;
      case 'HIATUS':
        return statusHiatus;
      default:
        return status;
    }
  }

  @override
  String formatSeason(String? season) {
    if (season == null || season.isEmpty) return '';
    switch (season.toUpperCase()) {
      case 'WINTER':
        return seasonWinter;
      case 'SPRING':
        return seasonSpring;
      case 'SUMMER':
        return seasonSummer;
      case 'FALL':
        return seasonFall;
      default:
        return season;
    }
  }

  @override
  String formatRelationType(String? type) {
    if (type == null || type.isEmpty) return relOther;
    switch (type.toUpperCase()) {
      case 'SEQUEL':
        return relSequel;
      case 'PREQUEL':
        return relPrequel;
      case 'SIDE_STORY':
        return relSideStory;
      case 'SPIN_OFF':
        return relSpinOff;
      case 'ALTERNATIVE':
        return relAlternative;
      case 'PARENT':
        return relParent;
      case 'SUMMARY':
        return relSummary;
      case 'ADAPTATION':
        return relAdaptation;
      case 'CHARACTER':
        return relCharacter;
      case 'OTHER':
      default:
        return relOther;
    }
  }

  @override
  String formatWatchStatus(String? status, int progress, int? totalEpisodes, String fallbackFormat) {
    if (progress > 0) {
      if (totalEpisodes != null && progress >= totalEpisodes) {
        return statusCompleted;
      }
      return statusWatching;
    }
    if (status == 'PLANNING') return statusPlanning;
    if (status != null && status.isNotEmpty) return formatStatus(status);
    return fallbackFormat;
  }
}
