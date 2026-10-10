import 'translations.dart';

class EnglishTranslations implements AppTranslations {
  const EnglishTranslations();

  // Navigation & Shell
  @override
  String get navHome => 'Home';
  @override
  String get navExplore => 'Explore';
  @override
  String get navCalendar => 'Calendar';
  @override
  String get navProfile => 'Library';
  @override
  String get navSettings => 'Settings';
  @override
  String get profile => 'Profile';
  @override
  String get serverConnected => 'Server connected';
  @override
  String get serverOffline => 'Server offline';

  // Common
  @override
  String get loading => 'Loading...';
  @override
  String get error => 'Error';
  @override
  String get retry => 'Retry';
  @override
  String get close => 'Close';
  @override
  String get back => 'Back';
  @override
  String get search => 'Search';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String get ok => 'OK';
  @override
  String get refresh => 'Refresh';
  @override
  String get clear => 'Clear';
  @override
  String get user => 'User';
  @override
  String get on => 'On';
  @override
  String get off => 'Off';
  @override
  String get delay => 'Delay';
  @override
  String get reset => 'Reset';
  @override
  String get noTitle => 'Untitled';

  // Feed & Home
  @override
  String get feedTitle => 'Home';
  @override
  String get continueWatching => 'Continue Watching';
  @override
  String get trendingAnime => 'Trending Anime';
  @override
  String get popularThisSeason => 'Popular This Season';
  @override
  String get popularOfTheMoment => 'Popular right now';
  @override
  String get recentReleases => 'Recent Releases';
  @override
  String get quickSearch => 'Quick Search';
  @override
  String get quickSearchHint => 'Quick search anime...';
  @override
  String get quickSearchMangaHint => 'Quick search manga...';
  @override
  String get serverNotConnected => 'Seanime Server not connected';
  @override
  String get serverNotConnectedDesc =>
      'Start the local server or check your connection to view content.';
  @override
  String get startServer => 'Start Server';
  @override
  String get startLocal => 'Start Local';
  @override
  String get stopServer => 'Stop';
  @override
  String get currentlyWatching => 'Currently Watching';
  @override
  String get missedSequels => 'Missed Sequels';
  @override
  String get recommendations => 'You Might Like';
  @override
  String get discoverAnime => 'Discover Anime';
  @override
  String get noEpisodesInProgress =>
      'No episodes in progress. Start playing an anime to track it here.';
  @override
  String get seeMore => 'See more';
  @override
  String get seeLess => 'See less';
  @override
  String get reachedTheEnd => 'You have reached the end • No more results';
  @override
  String get loginForFeed => 'Sign in for your feed';
  @override
  String get loginForFeedDesc =>
      'Connect AniList to continue episodes and sync your collection.';
  @override
  String get linkAccount => 'Link Account';
  @override
  String get sortTooltip => 'Sort';

  // Continue Watching Sort Modes
  @override
  String get sortRecent => 'Recently watched';
  @override
  String get sortAirDateDesc => 'Recent air date';
  @override
  String get sortAirDateAsc => 'Oldest air date';
  @override
  String get sortEpisodeDesc => 'Highest episode';
  @override
  String get sortEpisodeAsc => 'Lowest episode';
  @override
  String get sortTitle => 'Title (A-Z)';

  // Search
  @override
  String get searchTitle => 'Explore';
  @override
  String get searchPlaceholder => 'Search anime, genres, studios...';
  @override
  String get filterAll => 'All';
  @override
  String get noResultsFound => 'No results found';
  @override
  String get airingCalendar => 'Airing Calendar';
  @override
  String get searchAnimePrompt => 'Type an anime name to search';
  @override
  String get searchBarHint => 'Search anime (e.g. Frieren, Naruto, Kimetsu...)';

  // Library & Profile
  @override
  String get libraryTitle => 'Profile';
  @override
  String get myLists => 'My Lists';
  @override
  String get downloads => 'Downloads';
  @override
  String get animeDownloads => 'Anime Downloads';
  @override
  String get mangaDownloads => 'Manga Downloads';
  @override
  String get quickSettings => 'Quick Settings';
  @override
  String get localLibrary => 'Local';
  @override
  String get serverLibrary => 'Server';
  @override
  String get emptyLibrary => 'No items in your library';
  @override
  String get manageAniListAccount => 'Manage AniList Account';
  @override
  String get scanLocalFolder => 'Scan Local Folder';
  @override
  String get scanStarted => 'Scan started...';
  @override
  String get scanFailed => 'Error starting scan';
  @override
  String get openDownloadsFolder => 'Open Downloads Folder';
  @override
  String get statusWatching => 'Watching';
  @override
  String get statusCompleted => 'Completed';
  @override
  String get statusPlanning => 'Planning';
  @override
  String get statusDropped => 'Dropped';
  @override
  String get statusPaused => 'Paused';
  @override
  String get statusAll => 'All';
  @override
  String get reading => 'Reading';
  @override
  String get emptyLibraryCategory => 'No anime in this category';
  @override
  String get emptyLibraryLocal => 'No anime in your local library yet';
  @override
  String get serverOfflineLibrary =>
      'Start the local server in Settings to load your local collection.';

  // Settings
  @override
  String get settingsTitle => 'Settings';
  @override
  String get appearanceAndTheme => 'Appearance & Theme';
  @override
  String get themeAndColors => 'Theme & Colors';
  @override
  String get appearanceAndDisplay => 'Appearance & Display';
  @override
  String get animeDynamicTheme => 'Adaptive Anime Theme';
  @override
  String get animeDynamicThemeDesc =>
      'Uses AniList signature color to dynamically style the anime details screen with Material Design.';
  @override
  String get themeMode => 'Theme Mode';
  @override
  String get darkMode => 'Dark';
  @override
  String get lightMode => 'Light';
  @override
  String get systemMode => 'System';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeLight => 'Light';
  @override
  String get themeOled => 'OLED';
  @override
  String get themeSystem => 'System';
  @override
  String get themePresets => 'Community Palettes';
  @override
  String get themePresetsDesc => 'Curated visual themes inspired by the community and your system';
  @override
  String get iconPack => 'Icon Pack';
  @override
  String get iconPackDesc => 'Choose the visual style of icons across the application';
  @override
  String get iconPackLucide => 'Lucide (Modern Web / Desktop)';
  @override
  String get iconPackLucideDesc => 'Clean, refined outline web icons with high clarity';
  @override
  String get iconPackMaterial => 'Material Symbols (Classic)';
  @override
  String get iconPackMaterialDesc => 'Classic rounded mobile icon set';
  @override
  String get accentColor => 'Accent Color';
  @override
  String get typography => 'Typography & Font';
  @override
  String get videoPlayer => 'Video Player';
  @override
  String get playbackEngine => 'Playback Engine';
  @override
  String get defaultEngine => 'Default Engine';
  @override
  String get defaultEngineDesc =>
      'ExoPlayer is optimized for Android with direct hardware acceleration and libass for .ass subtitles. Automatically falls back to libmpv if needed.';
  @override
  String get appLanguage => 'App Language';
  @override
  String get appLanguageDesc => 'Choose your preferred language for the interface';
  @override
  String get serverSettings => 'Seanime Server';
  @override
  String get extensionsTitle => 'Extensions';
  @override
  String get preferences => 'Preferences';
  @override
  String get system => 'System';
  @override
  String get info => 'Information';
  @override
  String get appearanceSubtitle => 'Theme, accent colors, titles and views';
  @override
  String get extensionsSubtitle => 'Marketplace, online providers and repositories';
  @override
  String get streamingSources => 'Streaming Sources';
  @override
  String get streamingSourcesSubtitle => 'Enable or disable Torrent and Online Streaming';
  @override
  String get serverAndNetwork => 'Seanime Server & Network';
  @override
  String get serverAndNetworkSubtitle => 'Local server, remote IP connection and performance';
  @override
  String get aboutApp => 'About Aniting';
  @override
  String get aboutSubtitle => 'Native Aniting Flutter Client';
  @override
  String get aboutLegalese => 'Native client for anime management and playback.';

  // Appearance & Personalization
  @override
  String get accentColorPalette => 'Accent Color (M3 Tonal Palette)';
  @override
  String get themeAccentDefault => 'Theme Default';
  @override
  String get fontStyle => 'Font Style';
  @override
  String get fontStyleDesc => 'Select the font to be used across the interface.';
  @override
  String get livePreview => 'Live Preview';
  @override
  String get fontPangram => 'The quick brown fox jumps over the lazy dog. 1234567890';
  @override
  String get preferredTitleLanguage => 'Preferred Title Language';
  @override
  String get preferredTitleLanguageDesc => 'Choose how anime names are displayed throughout the app.';
  @override
  String get titleExample => 'Example';
  @override
  String get titleRomaji => 'Romaji';
  @override
  String get titleEnglish => 'English';
  @override
  String get titleNative => 'Native';
  @override
  String get episodeDisplay => 'Episode Display';
  @override
  String get episodeDisplayDesc =>
      'Choose whether to view episodes in a detailed list or a compact grid.';
  @override
  String get detailedList => 'Detailed list';
  @override
  String get grid => 'Grid';
  @override
  String get desktopScrollbar => 'Desktop Scrollbar';
  @override
  String get desktopScrollbarDesc => 'Show draggable scrollbar on desktop';
  @override
  String get mobileNavStyle => 'Mobile Navigation Style';
  @override
  String get mobileNavStyleDesc => 'Choose between the traditional fixed navigation bar or the floating dock';
  @override
  String get mobileNavStyleFloating => 'Floating (Dock)';
  @override
  String get mobileNavStyleClassic => 'Traditional fixed';
  @override
  String get desktopNavStyle => 'Desktop Navigation Style';
  @override
  String get desktopNavStyleDesc => 'Choose between the classic side rail or the centered floating dock';
  @override
  String get desktopNavStyleFloating => 'Floating Dock';
  @override
  String get desktopNavStyleSidebar => 'Classic Sidebar';
  @override
  String get showScores => 'Show Ratings';
  @override
  String get showScoresDesc => 'Display star ratings on content cards and posters';
  @override
  String get floatingResumeBar => 'Continue where you left off';
  @override
  String get floatingResumeBarDesc => 'Show a floating bar to instantly resume your last anime or manga';

  // Player Settings
  @override
  String get audioAndGestures => 'Audio & Gestures';
  @override
  String get volumeBoost => 'Volume Amplification (>100%)';
  @override
  String get volumeBoostDesc =>
      'Allows increasing volume up to 200% via on-screen gestures with native audio boost.';
  @override
  String get exoplayerDesc =>
      'Native hardware acceleration, lower battery usage, .ass support via libass, and libmpv fallback.';
  @override
  String get mpvDesc =>
      'Universal engine with comprehensive codec, subtitle, and filter support.';

  // Streaming Sources Settings
  @override
  String get playbackMethods => 'Playback Methods';
  @override
  String get torrentStreaming => 'Torrent Streaming';
  @override
  String get torrentStreamingDesc =>
      'Direct search and playback of torrents (BitTorrent / Debrid). Disabling hides the Torrent tab in anime.';
  @override
  String get onlineStreaming => 'Online Streaming';
  @override
  String get onlineStreamingDesc =>
      'Playback via installed online providers and extensions. Disabling hides the Online tab in anime.';
  @override
  String get streamingSourcesNotice =>
      'If you disable a source, it will not appear on the details screen of any anime. If both are disabled, you can only play files from your local library.';
  @override
  String get torrentStorageSection => 'Torrent Storage & Cache';
  @override
  String get animeLibraryFolderTitle => 'Anime Library Folder';
  @override
  String get animeLibraryFolderDesc =>
      'Folder on your device where Seanime scans for local anime files and video downloads.';
  @override
  String get workingDirectoryTitle => 'Working / Cache Directory';
  @override
  String get workingDirectoryDesc =>
      'Path where torrent videos and temporary data are stored.';
  @override
  String get autoDeletePreviousTitle => 'Auto-delete previous torrents';
  @override
  String get autoDeletePreviousDesc =>
      'Keep only 1 torrent at a time. Automatically deletes files and folders from previous torrents when starting a new stream to save disk space.';
  @override
  String get pauseTorrentOnExitTitle => 'Pause torrent download on exit';
  @override
  String get pauseTorrentOnExitDesc =>
      'Pause torrent piece downloads when leaving the video player to save bandwidth and battery.';
  @override
  String get defaultDirectoryHint => 'Default (~/.cache/aniting/torrentstream on SSD)';
  @override
  String get savePath => 'Save path';
  @override
  String get resetPath => 'Reset to default';

  // Server & Network Settings
  @override
  String get localServer => 'Local Server';
  @override
  String get remoteConnection => 'Remote Connection (PC / Network Server)';
  @override
  String get hostIp => 'Host / IP Address';
  @override
  String get hostHint => '127.0.0.1 or your PC local IP';
  @override
  String get port => 'Port';
  @override
  String get testAndSave => 'Test & Save';
  @override
  String get testingConnection => 'Testing connection...';
  @override
  String get androidPerfAndPerms => 'Android Performance & Permissions';
  @override
  String get batteryOpt => 'Background (Battery Saver)';
  @override
  String get batteryOptDisabled => 'Optimization disabled (server will stay running)';
  @override
  String get batteryOptEnabled => 'Optimization active (Android may pause the server)';
  @override
  String get disableOptimization => 'Disable Optimization';
  @override
  String get storageAccess => 'Files & Downloads Access';
  @override
  String get storageAccessGranted => 'Permission granted to store torrents and anime';
  @override
  String get storageAccessDenied => 'No full storage permission';
  @override
  String get grantStorageAccess => 'Grant File Access';
  @override
  String get coreVersion => 'Core Version';

  // LAN Sharing & Discovery
  @override
  String get lanSharing => 'Share Server on Network';
  @override
  String get lanSharingDesc => 'Allow other devices on your Wi-Fi to connect to this server';
  @override
  String get lanSharingActive => 'Sharing Active';
  @override
  String get lanSharingActiveDesc => 'Other devices can find and connect to this server';
  @override
  String get serverName => 'Server Name';
  @override
  String get serverNameHint => 'My Server';
  @override
  String get sharingOnNetwork => 'Sharing on network';
  @override
  String get discoveredServers => 'Servers on Network';
  @override
  String get discoveredServersDesc => 'Aniting servers detected on your Wi-Fi';
  @override
  String get searchingServers => 'Searching for servers...';
  @override
  String get searchServers => 'Scan for Servers';
  @override
  String get noServersFound => 'No servers found';
  @override
  String get noServersFoundDesc => 'Make sure a device on your network has server sharing enabled';
  @override
  String get connectToServer => 'Connect';
  @override
  String get connectedToServer => 'Connected';
  @override
  String discoveredServerLabel(String name, String ip, int port) => '$name ($ip:$port)';
  @override
  String get restartingServer => 'Restarting local server to apply network changes...';
  @override
  String get useLocalServer => 'Switch to Local Server';
  @override
  String get connectedToRemoteDesc => 'Connected to a server on your network. The local server on this device is paused to save battery and RAM.';
  @override
  String get lanSharingRequiresLocal => 'Only available when using the local server on this device';

  // Extensions & Marketplace
  @override
  String get installed => 'Installed';
  @override
  String get marketplace => 'Marketplace';
  @override
  String get checkForUpdates => 'Check for Updates';
  @override
  String get reloadAll => 'Reload All';
  @override
  String get configureRepo => 'Configure Repository';
  @override
  String get noInstalledExtensions => 'No extensions installed';
  @override
  String get noInstalledExtensionsDesc =>
      'Explore the Marketplace to install anime streaming providers and extensions.';
  @override
  String get exploreMarketplace => 'Explore Marketplace';
  @override
  String get install => 'Install';
  @override
  String get uninstall => 'Uninstall';
  @override
  String get update => 'Update';
  @override
  String get viewCode => 'View Code';
  @override
  String get enable => 'Enable';
  @override
  String get disable => 'Disable';
  @override
  String get allExtensionsUpToDate => 'All installed extensions are up to date.';
  @override
  String get updatesFound => 'update(s) found available!';

  // Anime Detail & Full Details
  @override
  String get exitLocalMode => 'Exit Local Mode';
  @override
  String get enterLocalMode => 'Local Mode (Files)';
  @override
  String get animeDetails => 'Anime Details';
  @override
  String get synopsis => 'Synopsis';
  @override
  String get characters => 'Characters & Cast';
  @override
  String get character => 'Character';
  @override
  String get relations => 'Relations & Connected Works';
  @override
  String get staff => 'Key Staff';
  @override
  String get rankings => 'Rankings & Statistics';
  @override
  String get averageScore => 'Average Score';
  @override
  String get anilistMean => 'AniList Mean';
  @override
  String get format => 'Format';
  @override
  String get episodes => 'Episodes';
  @override
  String get durationPerEp => 'Duration/ep';
  @override
  String get status => 'Status';
  @override
  String get season => 'Season';
  @override
  String get studio => 'Studio';
  @override
  String get mainRole => 'Main';
  @override
  String get supportingRole => 'Supporting';
  @override
  String get streamingDisabledTitle => 'Streaming sources disabled';
  @override
  String get streamingDisabledDesc =>
      'You have disabled Torrent and Online Streaming in Settings. To watch episodes, enable at least one source in Settings > Streaming Sources.';

  // Local Library View & Episodes
  @override
  String get checkingLocalFiles => 'Checking local files...';
  @override
  String get downloadedFiles => 'Downloaded Files';
  @override
  String get localEpisodes => 'local episodes';
  @override
  String get switchToGrid => 'Switch to grid';
  @override
  String get switchToList => 'Switch to list';
  @override
  String get notInLocalLibrary => 'Not in your local library';
  @override
  String get notInLocalLibraryDesc =>
      'No locally downloaded episodes were found for this anime on your Seanime server.';
  @override
  String get watchOnlineStream => 'Watch Online Stream';
  @override
  String get searchTorrents => 'Search Torrents';
  @override
  String get orderAsc => 'Order: 1 to N';
  @override
  String get orderDesc => 'Order: N to 1';
  @override
  String get searchEpisodePlaceholder => 'Search by title or episode number...';
  @override
  String get noEpisodesFoundMatching => 'No episodes found matching';
  @override
  String get noAiredEpisodesAvailable => 'No aired episodes available in this section.';

  // Online Stream & Torrent Selector
  @override
  String get onlineProvider => 'Provider';
  @override
  String get changeProvider => 'Change provider';
  @override
  String get tapToChangeProvider => 'Tap to change provider';
  @override
  String get sub => 'Sub';
  @override
  String get dub => 'Dub';
  @override
  String get selectSource => 'Select Video Source';
  @override
  String get allProviders => 'All providers';
  @override
  String get smartSearch => 'Smart Search';
  @override
  String get simpleSearch => 'Simple Search';
  @override
  String get searchQueryHint => 'Search query...';
  @override
  String get seeds => 'Seeds';
  @override
  String get leech => 'Leech';
  @override
  String get size => 'Size';
  @override
  String get noTorrentsFound => 'No torrents found';
  @override
  String get noTorrentsFoundDesc => 'Try switching providers or using simple search.';

  // AniList Authentication Sheet
  @override
  String get anilistLoginTitle => 'Sign in with AniList';
  @override
  String get anilistLoginDesc =>
      'Sync your list, episode progress, and ratings in real-time.';
  @override
  String get openInBrowser => 'Open AniList in browser';
  @override
  String get pasteTokenDivider => 'Paste the generated token';
  @override
  String get tokenPlaceholder => 'Paste token or redirect URL here...';
  @override
  String get linkAccountBtn => 'Link Account';
  @override
  String get disconnectAccount => 'Disconnect Account';
  @override
  String get accountSynced => 'Account Synchronized';
  @override
  String get viewProfileOnAnilist => 'View Profile on AniList';
  @override
  String get tokenPasted => 'Token pasted from clipboard.';
  @override
  String get clipboardEmpty => 'Clipboard is empty.';

  // Server Status Banner
  @override
  String get serverActiveLocal => 'Local Server Active';
  @override
  String get serverActiveRemote => 'Connected to Remote Server';
  @override
  String get serverStarting => 'Starting / Connecting to server...';

  // Video Player
  @override
  String get playbackStats => 'Playback Stats';
  @override
  String get chapters => 'Chapters';
  @override
  String get audioTracks => 'Audio Tracks';
  @override
  String get subtitleTracks => 'Subtitles';
  @override
  String get subtitleSync => 'Subtitle Sync';
  @override
  String get audioSync => 'Audio Sync';
  @override
  String get playbackSpeed => 'Speed';
  @override
  String get shaders => 'GLSL Shaders';
  @override
  String get mode => 'Mode';
  @override
  String get nextEpisode => 'Next episode';
  @override
  String get mute => 'Mute';
  @override
  String get unmute => 'Unmute';
  @override
  String get showInfo => 'Show info';
  @override
  String get collapsePanel => 'Collapse panel';
  @override
  String get playbackSources => 'Playback options';
  @override
  String get searchingSources => 'Searching options...';
  @override
  String get playingFirstAvailable => 'Playing first available option';
  @override
  String get tapToChangeSource => 'Tap to switch server or quality';
  @override
  String get reloadSourcesTooltip => 'Reload sources';
  @override
  String get noSourcesFoundForEpisode => 'No playback options found for this episode';
  @override
  String get availableSourcesCount => 'available options';
  @override
  String get aspectRatio => 'Screen Fit';
  @override
  String get screenFit => 'Screen Fit';
  @override
  String get videoSource => 'Video Source';
  @override
  String get performanceStats => 'On-screen Stats';
  @override
  String get gestures => 'On-screen Gestures';
  @override
  String get torrentDownloadProgress => 'Torrent Download Progress';
  @override
  String get downloadSpeed => 'Download';
  @override
  String get uploadSpeed => 'Upload';
  @override
  String get seedersPeers => 'Peers';
  @override
  String get remainingTime => 'Remaining';
  @override
  String get completed => 'Completed';
  @override
  String get switchingToMpvNotice => 'Switching to libmpv for format compatibility...';
  @override
  String get noChapters => 'No chapters available';
  @override
  String get noAudioTracks => 'No audio tracks found';
  @override
  String get noSubtitleTracks => 'No subtitle tracks found';
  @override
  String get fitContain => 'Fit (Contain)';
  @override
  String get fitCover => 'Fill Screen (Crop)';
  @override
  String get fitFill => 'Stretch to Fill';

  // Additional Player & Control getters
  @override
  String get episode => 'Episode';
  @override
  String get play => 'Play';
  @override
  String get pause => 'Pause';
  @override
  String get fullScreen => 'Fullscreen';
  @override
  String get exitFullScreen => 'Exit Fullscreen';
  @override
  String get reduceToModal => 'Reduce to modal';
  @override
  String get watching => 'Watching';
  @override
  String get forward10s => 'Forward 10s';
  @override
  String get rewind10s => 'Rewind 10s';
  @override
  String get synchronized => 'Synchronized';
  @override
  String get resetTo0ms => 'Reset to 0 ms';
  @override
  String get skipOpening => 'Skip Opening';
  @override
  String get skipEnding => 'Skip Ending';
  @override
  String get skipCredits => 'Skip Credits';
  @override
  String get skipIntro => 'Skip Intro';
  @override
  String get skipPreview => 'Skip Preview';
  @override
  String get skip => 'Skip';
  @override
  String get disableSubtitles => 'Disable Subtitles';
  @override
  String get copyPath => 'Copy path';
  @override
  String get copyLink => 'Copy link';
  @override
  String get pathCopied => 'Path copied to clipboard';
  @override
  String get linkCopied => 'Link copied to clipboard';
  @override
  String get codeCopied => 'Code copied to clipboard.';
  @override
  String get sourceFile => 'Local File';
  @override
  String get sourceStream => 'Online Stream';
  @override
  String get sourceTorrent => 'Torrent Stream';
  @override
  String get playbackEngineLabel => 'Playback engine:';
  @override
  String get filePathLabel => 'File path:';
  @override
  String get sourceUrlLabel => 'Source Link / URL:';
  @override
  String get shadersRequireMpv => 'GLSL shaders require the libmpv engine.';
  @override
  String get subtitleSyncDesc =>
      'Adjust delay to advance or delay subtitles relative to the video.';
  @override
  String get audioSyncDesc => 'Adjust the audio track offset relative to the video.';
  @override
  String get closeSettings => 'Close settings';
  @override
  String get defaultOption => 'Default';
  @override
  String get disabled => 'Disabled';
  @override
  String get embedded => 'Embedded';
  @override
  String get parts => 'parts';
  @override
  String get normal => 'Normal';
  @override
  String get unknown => 'Unknown';
  @override
  String get engine => 'Engine';
  @override
  String get videoCodec => 'Video Codec';
  @override
  String get resolution => 'Resolution';
  @override
  String get droppedFrames => 'Dropped Frames';
  @override
  String get hwDecoder => 'Decoder (HW)';
  @override
  String get videoBitrate => 'Video Bitrate';
  @override
  String get audioBitrate => 'Audio Bitrate';
  @override
  String get demuxerCache => 'Demuxer Cache';
  @override
  String get subtitles => 'Subtitles';
  @override
  String get automatic => 'Automatic';
  @override
  String get playerSettings => 'Settings';
  @override
  String get source => 'Source';
  @override
  String get subtitleSyncTitle => 'Subtitle Synchronization';
  @override
  String get audioSyncTitle => 'Audio Synchronization';
  @override
  String get onBadge => 'On';
  @override
  String get offBadge => 'Off';

  // Additional AniList Auth getters
  @override
  String get couldNotOpenBrowser => 'Could not open web browser.';
  @override
  String get errorOpeningBrowser => 'Error opening browser:';
  @override
  String get pasteTokenOrUrlPrompt =>
      'Please paste the AniList token or redirect URL.';
  @override
  String get tokenIncompletePrompt =>
      'The token appears to be incomplete. On AniList long press and select "Select All", or copy the entire URL from the browser bar.';
  @override
  String get loginSuccessAnilist => 'Successfully signed in with AniList!';
  @override
  String get failedToLinkAccount =>
      'Could not link account. Check that the token has not expired and is complete.';
  @override
  String get anilistRateLimitError =>
      'AniList rate limit is active. Please wait 60 seconds before trying again.';
  @override
  String get anilistTimeoutError =>
      'AniList or the server took too long to respond. Please wait 1 minute and try again.';
  @override
  String get anilistInvalidTokenError =>
      'The AniList token is invalid or has expired. Make sure to copy the full token and try again.';
  @override
  String get anilistConnectionError =>
      'Could not connect to the server or AniList. Check your connection and try again.';
  @override
  String get logoutConfirmTitle => 'Log Out';
  @override
  String get logoutConfirmContent =>
      'Are you sure you want to disconnect your AniList account?';
  @override
  String get sessionLoggedOut => 'Logged out successfully.';
  @override
  String get anilistUser => 'AniList User';

  // Additional Server Status getters
  @override
  String get serverDisconnected => 'Server disconnected';

  // Additional Quick Search getters
  @override
  String get quickSearchPrompt => 'Type an anime title to start searching';
  @override
  String get quickSearchMangaPrompt => 'Type a manga title to start searching';
  @override
  String get noResultsFor => 'No results for';

  // Additional Local Library & Episodes getters
  @override
  String get episodesCountSuffix => 'episodes';
  @override
  String get availableCount => 'available';
  @override
  String get searchEpisode => 'Search episode';
  @override
  String get sort1toN => 'Order: 1 to N';
  @override
  String get sortNto1 => 'Order: N to 1';
  @override
  String get episodeSynopsis => 'Episode Synopsis';
  @override
  String get noDescriptionAvailable =>
      'No description available for this episode.';
  @override
  String get filler => 'FILLER';
  @override
  String get viewExtendedDetails => 'View extended details';
  @override
  String get retryAniZip => 'Retry AniZip';
  @override
  String get noEpisodesAniZipOrLocal =>
      'No episodes found in AniZip or locally.';
  @override
  String get noEpisodesAniZipDesc =>
      'You can search torrents or try re-syncing AniZip information.';

  // Additional Extensions & Marketplace getters
  @override
  String get pluginExtensionsNotSupported =>
      'Plugin type extensions are not supported.';
  @override
  String get invalidManifestUrl =>
      'This extension does not have a valid manifest URL.';
  @override
  String get extensionInstalledSuccessfully => 'installed successfully.';
  @override
  String get extensionInstallFailed =>
      'Failed to install. Verify that Seanime server is running.';
  @override
  String get extensionUninstallTitle => 'Uninstall extension';
  @override
  String get extensionUninstallConfirm => 'Do you want to uninstall';
  @override
  String get extensionUninstalled => 'uninstalled.';
  @override
  String get extensionUpdating => 'Updating';
  @override
  String get extensionUpdateSuccess => 'updated successfully.';
  @override
  String get extensionUpdateFailed => 'Failed to update';
  @override
  String get extensionsReloadSuccess => 'Extensions reloaded successfully.';
  @override
  String get extensionsReloadFailed => 'Failed to reload extensions.';
  @override
  String get allExtensionsUpToDateLong =>
      'All installed extensions are up to date.';
  @override
  String get availableUpdatesCount => 'available update(s) found!';
  @override
  String get repoConfigTitle => 'Repository Configuration';
  @override
  String get repoUrlLabel => 'Marketplace Repository URL (JSON)';
  @override
  String get restoreDefaultRepo => 'Restore default repository';
  @override
  String get manualInstallManifest => 'Manual extension install (.json)';
  @override
  String get installManifest => 'Install Manifest';
  @override
  String get saveAndLoad => 'Save & Load';
  @override
  String get sourceLabel => 'Source:';
  @override
  String get allTypes => 'All Types';
  @override
  String get allLanguages => 'All Languages';
  @override
  String get animeTorrents => 'Anime Torrents';
  @override
  String get manga => 'Manga';
  @override
  String get onlineStreamingTab => 'Online Streaming';
  @override
  String get customSources => 'Custom Sources';
  @override
  String get searchExtensionsHint => 'Search extensions...';
  @override
  String get installedCardLabel => 'Installed';
  @override
  String get byAuthor => 'by';
  @override
  String get updateAvailable => 'Update available';
  @override
  String get viewSourceCode => 'View source code';
  @override
  String get sourceCodeNotLoaded =>
      'Could not load source code for this extension.';
  @override
  String get copyCode => 'Copy code';
  @override
  String get codeCopiedToClipboard => 'Code copied to clipboard.';
  @override
  String get loadingMarketplaceRepo => 'Loading Marketplace repository...';
  @override
  String get changeRepo => 'Change Repository';
  @override
  String get noExtensionsFound => 'No extensions found';
  @override
  String get noExtensionsFoundDesc =>
      'Try searching with another keyword or change the filter.';

  // Additional Torrent & Online Streaming getters
  @override
  String get loadingProviders => 'Loading providers...';
  @override
  String get searchingTorrentsInProviders =>
      'Searching torrents in providers...';
  @override
  String get searchingTorrents => 'Searching torrents...';
  @override
  String get resultsFound => 'results found';
  @override
  String get noTorrentsForEpisode =>
      'No torrents were found for this episode.';
  @override
  String get trySimpleSearchOrProvider =>
      'Try switching to "Simple Search" or selecting another provider.';
  @override
  String get openInExternalPlayer => 'Open in external MPV';
  @override
  String get playInApp => 'Play in app';
  @override
  String get bestRelease => 'BEST RELEASE';
  @override
  String get openingExternalPlayer =>
      'Opening in external player (MPV)...';
  @override
  String get serverNotOnline => 'Seanime server is not online.';
  @override
  String get failedToStartTorrent => 'Could not start torrent stream.';
  @override
  String get loadingStreamingExtensions =>
      'Loading streaming extensions...';
  @override
  String get noOnlineExtensionsInstalled =>
      'No online streaming extensions installed';
  @override
  String get noOnlineExtensionsInstalledDesc =>
      'To watch episodes in online streaming, install a provider extension (such as AnimePahe, Gogoanime or Consumet) from the Marketplace.';
  @override
  String get openExtensionsMarketplace => 'Open Extensions Marketplace';
  @override
  String get audioDubbed => 'Audio: Dubbed (tap for subtitled)';
  @override
  String get audioSubtitled => 'Audio: Subtitled (tap for dubbed)';
  @override
  String get manualMappingActive => 'Manual mapping active:';
  @override
  String get linkAnimeManually => 'Link anime manually with provider';
  @override
  String get reloadEpisodes => 'Reload episodes';
  @override
  String get filterEpisodesHint =>
      'Filter episodes by number or title...';
  @override
  String get filterByTitle => 'Filter by title...';
  @override
  String get selectServerQuality => 'Select Server / Quality';
  @override
  String get quality => 'Quality:';
  @override
  String get server => 'Server';
  @override
  String get noVideoSourcesFound => 'No video sources found for episode';
  @override
  String get errorGettingSources => 'Error getting sources:';
  @override
  String get clearCacheAndRetry => 'Clear cache and retry';
  @override
  String get searchAndLinkIn => 'Search and link in';
  @override
  String get linkWith => 'Link with';
  @override
  String get searchAndSelectInProvider =>
      'Search and select the anime in the provider';
  @override
  String get linkedTo => 'Linked to:';
  @override
  String get unlink => 'Unlink';
  @override
  String get linkRemoved => 'Link removed';
  @override
  String get searchingProviderCatalog => 'Searching provider catalog...';
  @override
  String get searchPromptMapping =>
      'Type a query and tap "Search" or tap one of the suggestions.';
  @override
  String get animeLinkedSuccess => 'Anime linked successfully to';
  @override
  String get linked => 'Linked';
  @override
  String get link => 'Link';
  @override
  String get searchAnimePlaceholder => 'e.g., Frieren, Dandadan, Bleach...';
  @override
  String get tapToEdit => 'Tap to edit';
  @override
  String get errorLoadingEpisodes => 'Error loading episodes:';
  @override
  String noEpisodesFoundAuto(String provider) =>
      'No episodes found automatically with "$provider".\nYou can search and link the anime manually or try another provider.';
  @override
  String noAnimeFoundInProvider(String provider, String query) =>
      'No anime found in "$provider" for "$query". Try searching with shorter keywords or the English/Romaji title.';
  @override
  String noEpisodesInProvider(String provider) =>
      'No episodes found in "$provider".';


  // Status & Season & Relation formatters
  @override
  String get statusFinished => 'Finished';
  @override
  String get statusReleasing => 'Releasing';
  @override
  String get statusNotYetReleased => 'Upcoming';
  @override
  String get statusCancelled => 'Cancelled';
  @override
  String get statusHiatus => 'On Hiatus';

  @override
  String get seasonWinter => 'Winter';
  @override
  String get seasonSpring => 'Spring';
  @override
  String get seasonSummer => 'Summer';
  @override
  String get seasonFall => 'Fall';

  @override
  String get relSequel => 'Sequel';
  @override
  String get relPrequel => 'Prequel';
  @override
  String get relSideStory => 'Side Story';
  @override
  String get relSpinOff => 'Spin-off';
  @override
  String get relAlternative => 'Alternative';
  @override
  String get relParent => 'Main Story';
  @override
  String get relSummary => 'Summary';
  @override
  String get relAdaptation => 'Adaptation';
  @override
  String get relCharacter => 'Character';
  @override
  String get relOther => 'Related';

  @override
  String get continueReading => 'Continue Reading';
  @override
  String get currentlyReading => 'Currently Reading';
  @override
  String get completedManga => 'Completed Manga';
  @override
  String get trendingManga => 'Trending Manga';
  @override
  String get popularManga => 'Popular Manga';
  @override
  String get discoverManga => 'Discover Manga';
  @override
  String get chapter => 'Chapter';
  @override
  String get noMangaProviders => 'No manga extensions installed';
  @override
  String get readChapter => 'Read';
  @override
  String get nextPage => 'Next';
  @override
  String get previousPage => 'Previous';

  // Airing Calendar & Genres
  @override
  String get genresTitle => 'Genres';
  @override
  String get exploreGenres => 'Explore by Genre';
  @override
  String get today => 'Today';
  @override
  String get tomorrow => 'Tomorrow';
  @override
  String get sortTrending => 'Trending';
  @override
  String get sortScore => 'Score';
  @override
  String get sortPopularity => 'Popularity';
  @override
  String get sortStartDate => 'Newest';
  @override
  String get sortBy => 'Sort by';
  @override
  String get filterByYear => 'Filter by year';
  @override
  String get allYears => 'All years';
  @override
  String get episodesUpcoming => 'Upcoming episodes';
  @override
  String get anime => 'Anime';
  @override
  String get curatedRomance => 'Romance & Slice of Life';
  @override
  String get curatedAction => 'Action & Shonen';
  @override
  String get curatedFantasy => 'Fantasy & Isekai';
  @override
  String get curatedMovies => 'Featured Movies';
  @override
  String get curatedTopRated => 'Top Rated';
  @override
  String get noAiringToday => 'No episodes scheduled for this day';
  @override
  String get filters => 'Filters';
  @override
  String get applyFilters => 'Apply Filters';
  @override
  String get clearFilters => 'Clear Filters';
  @override
  String get selectGenresAndTags => 'Genres & Tags';
  @override
  String get allGenres => 'All Genres';
  @override
  String get tagsTitle => 'Tags';
  @override
  String get formatTitle => 'Format';
  @override
  String get seasonTitle => 'Season';
  @override
  String get statusTitle => 'Status';
  @override
  String get yearTitle => 'Year';
  @override
  String get curatedRomanceManga => 'Romance & Drama Manga';
  @override
  String get curatedActionManga => 'Action & Adventure Manga';
  @override
  String get curatedFantasyManga => 'Fantasy & Isekai Manga';
  @override
  String get formatTv => 'TV Series';
  @override
  String get formatTvShort => 'TV Short';
  @override
  String get formatMovie => 'Movie';
  @override
  String get formatOva => 'OVA';
  @override
  String get formatOna => 'ONA';
  @override
  String get formatSpecial => 'Special';
  @override
  String get formatManga => 'Manga';
  @override
  String get formatNovel => 'Light Novel';
  @override
  String get formatOneShot => 'One Shot';
  @override
  String get allFormats => 'All Formats';
  @override
  String get allStatuses => 'All Statuses';
  @override
  String get allSeasons => 'All Seasons';
  @override
  String get activeFilters => 'Active Filters';
  @override
  String get discoverSeries => 'Discover series';
  @override
  String get highestRatedShows => 'Highest rated shows';
  @override
  String get allTags => 'All tags';
  @override
  String get allScores => 'All scores';
  @override
  String get timelessYear => 'Timeless';
  @override
  String get adultContent => 'Adult';
  @override
  String get titleSearchPlaceholder => 'Title';
  @override
  String get highestScore => 'Highest score';

  // Onboarding / Welcome screen
  @override
  String get welcomeTitle => 'Welcome to Aniting';
  @override
  String get welcomeSubtitle => 'Tailor your experience just how you like it in a few simple steps.';
  @override
  String get welcomeStepLanguage => 'Language';
  @override
  String get welcomeStepTheme => 'Appearance';
  @override
  String get welcomeStepPreferences => 'Preferences';
  @override
  String get welcomeStepExtensions => 'Extensions';
  @override
  String get welcomeStepAnilist => 'AniList';
  @override
  String get welcomeSkip => 'Skip';
  @override
  String get welcomeSkipAll => 'Skip';
  @override
  String get welcomeNext => 'Continue';
  @override
  String get welcomeBack => 'Back';
  @override
  String get welcomeFinish => 'Get Started';
  @override
  String get welcomeDevPreview => 'Welcome Wizard (Dev)';
  @override
  String get welcomeResetDone => 'Welcome wizard reset. It will appear on next app launch.';
  @override
  String get welcomeResetPrompt => 'Reset welcome screen';
  @override
  String get welcomeLanguagePrompt => 'Select the primary application language';
  @override
  String get welcomeThemePrompt => 'Choose your favorite visual theme and palette';
  @override
  String get welcomeTitleLangPrompt => 'Preferred anime title display format';
  @override
  String get welcomeStreamingModePrompt => 'How do you prefer to watch your anime?';
  @override
  String get welcomeModeBoth => 'Both (Recommended)';
  @override
  String get welcomeModeBothDesc => 'Access peer-to-peer torrents and direct online streaming servers';
  @override
  String get welcomeModeOnline => 'Online Only';
  @override
  String get welcomeModeOnlineDesc => 'Stream directly from web servers without using torrents';
  @override
  String get welcomeModeTorrent => 'Torrent Only';
  @override
  String get welcomeModeTorrentDesc => 'High-fidelity peer-to-peer streaming with maximum quality';
  @override
  String get welcomeExtensionsPrompt => 'Recommended extensions to start watching and reading';
  @override
  String get welcomeInstallAll => 'Install selected';
  @override
  String get welcomeInstalledCount => 'installed';
  @override
  String get welcomeAnilistPrompt => 'Connect your AniList account to sync your watch progress and lists';
  @override
  String get welcomeAnilistConnected => 'Account connected successfully!';
  @override
  String get welcomeAnilistSkip => 'Continue without account (Skip)';
  @override
  String get themeSectionDark => 'Dark Themes';
  @override
  String get themeSectionLight => 'Light Themes';
  @override
  String get themeSectionMaterial => 'Material Design 3';
  @override
  String get materialPurpleName => 'Material You Violet';
  @override
  String get materialBlueName => 'Material You Ocean';
  @override
  String get materialGreenName => 'Material You Forest';
  @override
  String get materialOrangeName => 'Material You Sunset';
  @override
  String get materialCrimsonName => 'Material You Raspberry';
  @override
  String get materialTealName => 'Material You Teal';
  @override
  String get paletteSystem => 'System (Dank Shell / Matugen)';
  @override
  String get exploreAllMarketplace => 'Explore Full Marketplace';
  @override
  String get allRecommended => 'All Recommended';
  @override
  String get searchExtensionsPrompt => 'Search extensions...';
  @override
  String get blurBanner => 'Blur banner';
  @override
  String get blurBannerDesc => 'Applies a cinematic blur to the background banner on anime and manga details';
  @override
  String get cornerRadius => 'Corners';
  @override
  String get welcomeAnilistTitle => 'Sync with AniList';
  @override
  String get welcomeAnilistSyncDesc => 'Sync anime, manga, episodes, and scores in real time.';
  @override
  String get welcomeExtensionsEmptyHint => 'You can explore and install extensions from the marketplace at any time.';
  @override
  String get settingsSaved => 'Settings saved successfully';
  @override
  String get searchSettingsHint => 'Search settings...';
  @override
  String get mangaReader => 'Manga Reader';
  @override
  String get mangaReaderSettings => 'Reader Settings';
  @override
  String get mangaReadingModeSection => 'READING MODE';
  @override
  String get mangaReadingMode => 'Reading mode';
  @override
  String get mangaModeWebtoon => 'Scroll';
  @override
  String get mangaModePagedLtr => 'Left to Right';
  @override
  String get mangaModePagedRtl => 'Right to Left';
  @override
  String get mangaStatusBarSection => 'STATUS BAR';
  @override
  String get mangaStatusBar => 'Status bar';
  @override
  String get mangaStatusBarSmart => 'Smart';
  @override
  String get mangaStatusBarHidden => 'Hidden';
  @override
  String get mangaStatusBarVisible => 'Visible';
  @override
  String get mangaGesturesSection => 'GESTURES & DISPLAY';
  @override
  String get mangaTapToTurn => 'Tap to turn page';
  @override
  String get mangaSubtleShadow => 'Edge shadow';
  @override
  String get mangaDownloadsSection => 'DOWNLOADS & STORAGE';
  @override
  String get mangaDownloadDir => 'Download Directory';
  @override
  String get mangaDownloadDirDesc => 'Anime/aniting/Manga (Independent of working/cache directory)';
  @override
  String get loadingPath => 'Loading path...';
  @override
  String get loadingPages => 'Loading pages...';
  @override
  String get endOfChapter => 'End of';
  @override
  String get progressSavedAnilist => 'Progress saved to AniList';
  @override
  String get nextChapter => 'Next Chapter';
  @override
  String get prevChapter => 'Previous Chapter';
  @override
  String get backToManga => 'Back to Manga';
  @override
  String get readingSettingsTooltip => 'Reading settings';
  @override
  String get chapterListTooltip => 'Chapter list';
  @override
  String get page => 'Page';
  @override
  String get noPagesFound => 'No pages found for this chapter.';
  @override
  String get errorLoadingPages => 'Error loading pages';
  @override
  String get errorLoadingPage => 'Error loading page';
  @override
  String get downloadedInStorage => 'Downloaded in storage';
  @override
  String get downloadChapter => 'Download chapter';

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
  String formatFormat(String? format) {
    if (format == null || format.isEmpty) return '';
    switch (format.toUpperCase()) {
      case 'TV':
        return formatTv;
      case 'TV_SHORT':
        return formatTvShort;
      case 'MOVIE':
        return formatMovie;
      case 'SPECIAL':
        return formatSpecial;
      case 'OVA':
        return formatOva;
      case 'ONA':
        return formatOna;
      case 'MANGA':
        return formatManga;
      case 'NOVEL':
        return formatNovel;
      case 'ONE_SHOT':
        return formatOneShot;
      default:
        return format;
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

  // About Screen & Version Check
  @override
  String get nativeClientSubtitle => 'Native client for Anime & Manga';
  @override
  String get developerAndCredits => 'DEVELOPER & CREDITS';
  @override
  String get developerSubtitle => 'Flutter native client developer\nGitHub: github.com/anyyting-es';
  @override
  String get originalServerSubtitle => 'Original backend & media server created by 5rahim\nhttps://seanime.app';
  @override
  String get discordCommunity => 'Discord Community';
  @override
  String get discordSubtitle => 'Join the Aniting community on Discord\ndiscord.gg/FaPcNGURdN';
  @override
  String get systemAndUpdates => 'SYSTEM & UPDATES';
  @override
  String get clientDevice => 'Mobile / PC Client';
  @override
  String get buildRelease => 'Build Release';
  @override
  String get seanimeCoreServer => 'Seanime Core Server';
  @override
  String serverVersionConnected(String version) => 'Version $version (Connected)';
  @override
  String get serverOfflineOrLocal => 'Disconnected or Local Server';
  @override
  String get checkingUpdatesGithub => 'Checking for updates on GitHub...';
  @override
  String get checkLatestGithub => 'Check for the latest version on GitHub';
  @override
  String latestVersionSnackbar(String version) => 'You are on the latest version (v$version). No new updates.';
  @override
  String get failedCheckUpdateSnackbar => 'Could not check for updates. Check your internet connection.';
  @override
  String get openSourceLicenses => 'Open Source Licenses';
  @override
  String get openSourceLicensesDesc => 'View free and open source software licenses and libraries';
  @override
  String get devAndTesting => 'DEVELOPMENT & TESTING';
  @override
  String get welcomeDevPreviewDesc => 'Open the welcome wizard in preview mode';
  @override
  String get welcomeResetDesc => 'Reset welcome wizard to show on next launch';

  // Stream Selection & Modes
  @override
  String get playbackMode => 'Playback Mode';
  @override
  String get communityServers => 'Community servers';
  @override
  String get torrentP2p => 'P2P download & streaming';
  @override
  String get downloadedLibrary => 'Downloaded library';
  @override
  String get onlineSources => 'Online Sources';
  @override
  String availableSourcesCountLabel(int count) => '$count available';
  @override
  String get advancedOptions => 'Advanced options';
  @override
  String get closeModeSelector => 'Close mode selector';
  @override
  String get closeSourceSelector => 'Close source selector';
  @override
  String get audioHeading => 'AUDIO';
  @override
  String get audioDubbedFull => 'Dubbed (Dub)';
  @override
  String get exploreMarketplaceMore => 'Explore more extensions in store';
  @override
  String loadingEpisodesFrom(String provider) => 'Loading episodes from $provider...';
  @override
  String noEpisodesFoundInProvider(String provider) => 'No episodes found on $provider';
  @override
  String get tryAnotherServerOrSubDub => 'Try selecting another server or switching between subtitled and dubbed';
  @override
  String episodeNumber(int number) => 'Episode $number';

  // Settings & Customization
  @override
  String get cornerAndBorders => 'Corners & Borders (Card Radius)';
  @override
  String get adjustCornerRadiusDesc => 'Adjust the visual roundness of components and cards';
  @override
  String get cornerRadiusSquare => '0 px (Square)';
  @override
  String get cornerRadiusSubtle => '6 px (Subtle)';
  @override
  String get cornerRadiusNormal => '10 px (Normal)';
  @override
  String get cornerRadiusRound => '16 px (Round)';
  @override
  String get cornerRadiusCurved => '22 px (Curved)';
  @override
  String get interfaceModeTitle => 'Interface Mode (Adaptive)';
  @override
  String get interfaceModeDesc => 'Layout tailored for your device';
  @override
  String get interfaceModeDialogTitle => 'Interface Mode';
  @override
  String get interfaceModeAuto => 'Automatic';
  @override
  String get interfaceModeAutoDesc => 'Automatic screen size detection';
  @override
  String get interfaceModeDesktop => 'Desktop (PC)';
  @override
  String get interfaceModeDesktopDesc => 'Full 2-column layout with hero banner';
  @override
  String get interfaceModeMobile => 'Mobile';
  @override
  String get interfaceModeMobileDesc => 'Compact vertical layout for phones';
  @override
  String get interfaceModeTv => 'TV Mode (10ft)';
  @override
  String get interfaceModeTvDesc => 'Simplified 10-foot UI for remote control and D-Pad';
  @override
  String get episodeDisplayDetailedDesc => 'Shows large thumbnails with title and synopsis';
  @override
  String get episodeDisplayGridDesc => 'Compact numbered grid of episodes';
  @override
  String get oledTrueBlackTitle => 'Pure Black (OLED True Black)';
  @override
  String get oledTrueBlackDesc => 'Absolute #000000 black background for OLED screens';
  @override
  String get fontSystemDisplayName => 'System';
  @override
  String get fontSystemDesc => 'Default device typography';
  @override
  String get pathRestoredDefault => 'Path restored to default SSD storage';
  @override
  String get workDirSavedSuccess => 'Working directory saved successfully';
  @override
  String get workDirSaveError => 'Error saving working directory';

  // App Update Dialog
  @override
  String get updateDialogTitle => 'New version';
  @override
  String updateDialogCurrentVersion(String version, String size) =>
      'Current version: v$version${size.isNotEmpty ? ' • $size' : ''}';
  @override
  String get updateDialogChangelogTitle => 'Release Notes & Changes';
  @override
  String get updateDialogDefaultNotes => 'Stability, performance improvements, and bug fixes are included in this release.';
  @override
  String get updateDialogDownloading => 'Downloading update...';
  @override
  String get updateDialogLater => 'Later';
  @override
  String get updateDialogUpdateNow => 'Update now';
  @override
  String get updateDialogDownloadingBtn => 'Downloading...';
  @override
  String get updateDialogInstalling => 'Installing...';
  @override
  String get updateDialogInstallUpdate => 'Install update';

  // Empty Feed States & Downloads
  @override
  String get emptyMangaFeedTitle => 'Your manga list is empty';
  @override
  String get emptyAnimeFeedTitle => 'Your anime list is empty';
  @override
  String get emptyMangaFeedDesc => "You don't have any manga in progress. Explore the catalog or search for your favorite series.";
  @override
  String get emptyAnimeFeedDesc => "You don't have any anime in progress. Explore the catalog or search for your favorite series.";
  @override
  String get noDownloadedAnimeTitle => 'No downloaded anime';
  @override
  String get noDownloadedAnimeDesc => 'Episodes downloaded in your local library will appear here for offline viewing.';
  @override
  String get noDownloadedMangaTitle => 'No downloaded manga';
  @override
  String get noDownloadedMangaDesc => 'Chapters downloaded to read in the offline reader will be saved in Anime/aniting/Manga and appear here.';
  @override
  String get exploreManga => 'Explore Manga';
  @override
  String downloadedAnimeCount(int count) => '$count downloaded ${count == 1 ? "anime" : "anime"} in local library';
  @override
  String downloadedMangaCount(int mangaCount, int chaptersCount) => '$mangaCount ${mangaCount == 1 ? "manga" : "manga"} • $chaptersCount ch.';
  @override
  String storageUsed(String formattedSize) => 'Storage used: $formattedSize';
  @override
  String get refreshDownloadsTooltip => 'Refresh downloads';
  @override
  String get activeDownloads => 'In progress';
  @override
  String get noActiveDownloads => 'No active downloads';
  @override
  String get noActiveDownloadsDesc =>
      'There are no active torrents, anime, or manga chapters downloading right now.';
  @override
  String get torrentStreamDownload => 'Active Torrent Stream';
  @override
  String get mangaDownloadQueueTitle => 'Manga Download Queue';
  @override
  String get pauseDownload => 'Pause';
  @override
  String get resumeDownload => 'Resume';
  @override
  String get cancelOrDeleteDownload => 'Drop & Delete';
  @override
  String get pauseQueue => 'Pause queue';
  @override
  String get resumeQueue => 'Resume queue';
  @override
  String get clearQueue => 'Clear queue';
  @override
  String get manageActiveAndCompletedDownloads =>
      'Monitor active downloads, anime, and manga offline files';
  @override
  String get downloadSpeedLabel => 'Download';
  @override
  String get uploadSpeedLabel => 'Upload';
  @override
  String get downloadWithTorrentClient => 'Download with torrent client';
  @override
  String get downloadInBackground => 'Download in background';
  @override
  String get watchNowStream => 'Watch now (Streaming)';
  @override
  String get allBatches => 'All / Batches';
  @override
  String get downloadStarted => 'Download started in torrent client';

  // Player & UI Details
  @override
  String prevEpisodeNumbered(int number) => '← Previous episode: Ep. $number';
  @override
  String scorePercent(String score) => '$score% score';
  @override
  String get anilistConnectedBadge => 'AniList Connected';

  // Play & Reading Button States
  @override
  String get rewatch => 'Watch again';
  @override
  String continueEpisodeNumbered(int number) => 'Continue Ep. $number';
  @override
  String get startWatching => 'Start watching';
  @override
  String get startReading => 'Start reading';
  @override
  String continueChapterNumbered(int number) => 'Continue Ch. $number';

  // Favorites & Actions
  @override
  String get inFavorites => 'In favorites';
  @override
  String get addToFavorites => 'Add to favorites';
  @override
  String get addedToFavorites => 'Added to favorites';
  @override
  String get removedFromFavorites => 'Removed from favorites';
  @override
  String get editInAnilist => 'Edit on AniList';
  @override
  String get share => 'Share';
  @override
  String get watchTrailer => 'Watch trailer';
  @override
  String get viewOnAnilist => 'View on AniList';
  @override
  String get viewOnMal => 'View on MyAnimeList';
  @override
  String linkCopiedFor(String title) => 'Link copied for $title';
  @override
  String get details => 'Details';
  @override
  String get batchDownload => 'Batch download';
  @override
  String get downloadChapterAction => 'Download';
  @override
  String get downloadBatch => 'Download batch';
  @override
  String get readBadge => 'READ';
  @override
  String get progress => 'Progress';
  @override
  String get myProgress => 'My Progress';
  @override
  String get volumes => 'Volumes';
  @override
  String get score => 'Score';
  @override
  String get aired => 'Aired';
  @override
  String get localUser => 'Local User';
  @override
  String get scan => 'Scan';

  // Empty States & Content Tabs
  @override
  String get noRelationsAvailable => 'No relations available';
  @override
  String get noRecommendationsAvailable => 'No recommendations available';
  @override
  String get noCharactersAvailable => 'No characters available';
  @override
  String get noSimilarWorksAvailable => 'No similar titles available';
  @override
  String get noDownloadedChaptersForManga => 'No downloaded chapters for this title';
  @override
  String get noChaptersMatchingFilters => 'No chapters found with current filters';
  @override
  String get resetFilters => 'Reset filters';
  @override
  String get exploreMangaExtensions => 'Explore Manga Extensions';
  @override
  String get reloadChapters => 'Reload chapters';
  @override
  String get oldestFirst => 'Oldest first';
  @override
  String get newestFirst => 'Newest first';
  @override
  String get onlyDownloaded => 'Only downloaded';
  @override
  String get viewAllChapters => 'View all chapters';
  @override
  String get informationTitle => 'Information';
  @override
  String get prevEpisode => '← Previous episode';
  @override
  String get synopsisMore => 'More';
  @override
  String get synopsisLess => 'Less';
  @override
  String get searchChapterPlaceholder => 'Search or Ch. number...';
  @override
  String get installMangaExtensionNotice =>
      'Install a manga extension to read chapters in your library.';
  @override
  String hideReadChapters(int count) => 'Hide read ($count)';
  @override
  String hidingReadChapters(int count) => 'Hiding read ($count)';
  @override
  String downloadedCount(int count) => 'Downloaded ($count)';
  @override
  String chaptersCount(int count) => '$count chapters';
  @override
  String chapterAbbr(String number) => 'Ch. $number';
  @override
  String get noChaptersAvailable => 'No chapters available';
  @override
  String episodeSoon(int number) => 'Ep. $number soon';
  @override
  String get currentEpisodeBadge => 'Current episode';
  @override
  String get batchFiles => 'Batch Files';
  @override
  String filesCount(int count) => '$count files';
  @override
  String get filterFilesOrEpisode => 'Filter files or episode...';
  @override
  String noFilesMatching(String query) => 'No files found with "$query"';
  @override
  String get selectAFile => 'Select a file';
  @override
  String get delete => 'Delete';
  @override
  String get deleteFromAnilist => 'Delete from AniList';
  @override
  String get deleteFromList => 'Delete from your list';
  @override
  String deleteAnilistConfirm(String title) =>
      'Are you sure you want to delete "$title" from your AniList list?';
  @override
  String deleteLocalConfirm(String title) =>
      'Are you sure you want to delete "$title" from your local library?';
  @override
  String get deleteDownload => 'Delete download';
  @override
  String deleteDownloadConfirm(String title) =>
      'Are you sure you want to delete downloads for "$title"?';
  @override
  String get downloadDeleted => 'Download deleted successfully';
  @override
  String deleteEpisodeDownloadConfirm(int episodeNumber) =>
      'Delete download for Episode $episodeNumber?';
  @override
  String get removedFromList => 'Removed from your list';
  @override
  String get selectProviderToDownload => 'Select a provider to download';
  @override
  String downloadingChapter(String chapter) => 'Downloading chapter $chapter...';
  @override
  String errorSchedulingDownload(String error) => 'Error scheduling download: $error';
  @override
  String get downloadChapters => 'Download Chapters';
  @override
  String providerWithUnreadCount(String provider, int unreadCount) =>
      'Provider: $provider • $unreadCount unread';
  @override
  String downloadNextUnread(int count) => 'Download next $count unread';
  @override
  String downloadNextUnreadDesc(int count) =>
      'Save the next $count chapters for offline reading';
  @override
  String downloadAllUnread(int count) => 'Download all unread ($count)';
  @override
  String get downloadAllUnreadDesc => 'Full download of all pending chapters';
  @override
  String downloadingChaptersCount(int count) => 'Downloading $count chapters...';
  @override
  String torrentsFilterCount(int filtered, int total, String quality) =>
      '$filtered of $total torrents ($quality)';
  @override
  String noTorrentsWithQuality(String quality) =>
      'No torrents found with quality "$quality"';
  @override
  String get resetQualityFilterAll => 'Reset filter to "All"';
  @override
  String get myCollection => 'My Collection';
  @override
  String get previous => 'Previous';
  @override
  String get next => 'Next';
  @override
  String pageOf(int current, int total) => 'Page $current of $total';
  @override
  String chapterDownloaded(String number) => 'Chapter $number (Downloaded)';
  @override
  String get errorLoadingChapters => 'Error loading chapters';
  @override
  String exploreAllMarketplaceCountDesc(int count) =>
      'Explore the full catalog with over $count extensions';
  @override
  String get updateNoApkFound => 'No APK file found attached to this release.';
  @override
  String updateDownloadError(String error) => 'Error downloading update: $error';
  @override
  String get updateAndroidOnly => 'Direct installation is only available on Android.';
  @override
  String updateInstallerError(String error) => 'Error opening installer: $error';

  @override
  String get navigationSections => 'Navigation Sections';
  @override
  String get animeSection => 'Anime Section';
  @override
  String get animeSectionDesc => 'Show anime tab in navigation';
  @override
  String get showsSection => 'Shows & Movies Section (TMDB)';
  @override
  String get showsSectionDesc => 'Show TMDB shows and movies tab in navigation';
  @override
  String get mangaSection => 'Manga Section';
  @override
  String get mangaSectionDesc => 'Show manga tab in navigation';
  @override
  String get cannotDisableBothSections => 'You must keep at least one section enabled';
  @override
  String get shows => 'Shows / Movies';
  @override
  String get exploreAnime => 'Anime (AniList)';
  @override
  String get exploreShows => 'Shows (TMDB)';

  // Subtitle Style Customization
  @override
  String get subtitleStyle => 'Subtitle Style';
  @override
  String get subtitleStyleDesc => 'Font family, size, colors, borders and shadow effects';
  @override
  String get subtitlePreviewText => 'The quick brown fox jumps over the lazy dog';
  @override
  String get subtitleFont => 'Font Family';
  @override
  String get subtitleFontSize => 'Font Size';
  @override
  String get subtitleBold => 'Bold';
  @override
  String get subtitleItalic => 'Italic';
  @override
  String get subtitleTextColor => 'Text Color';
  @override
  String get subtitleBgColor => 'Subtitle Background';
  @override
  String get subtitleBorderStyle => 'Border & Shadow';
  @override
  String get subtitleBorderSize => 'Border / Shadow Size';
  @override
  String get subtitleBorderColor => 'Border Color';
  @override
  String get subtitleOverrideAss => 'Override .ass Subtitle Styles (MPV)';
  @override
  String get subtitleOverrideAssDesc =>
      'In MPV, overrides .ass styling and applies your custom style. In ExoPlayer, .ass subtitles always preserve their advanced original styling and typography.';
  @override
  String get subtitleStyleReset => 'Reset Style';
  @override
  String get subtitleStyleResetConfirm =>
      'Reset all subtitle styles and formatting back to default?';
  @override
  String get borderStyleNone => 'None';
  @override
  String get borderStyleOutline => 'Outline';
  @override
  String get borderStyleDropShadow => 'Drop Shadow';
  @override
  String get borderStyleRaised => 'Raised';
  @override
  String get borderStyleDepressed => 'Depressed';
  @override
  String get bgTransparent => 'Transparent';
  @override
  String get bgSubtle => 'Subtle (30%)';
  @override
  String get bgMedium => 'Medium (60%)';
  @override
  String get bgSolid => 'Solid (100%)';

  // Torrent Batch Filter
  @override
  String get showOnlyBatches => 'Only Batches';

  // Download Manager & History
  @override
  String get downloadManager => 'Download Manager';
  @override
  String get downloadManagerDesc => 'Monitor active speeds, ETA, and download history';
  @override
  String get downloadHistory => 'Download History';
  @override
  String get noDownloadHistory => 'No download history';
  @override
  String get noDownloadHistoryDesc => 'Completed anime and manga downloads will appear here.';
  @override
  String get clearHistory => 'Clear History';
  @override
  String get clearHistoryConfirm => 'Are you sure you want to clear the download history?';
  @override
  String get timeRemaining => 'Time remaining';
  @override
  String etaLabel(String eta) => '$eta remaining';
  @override
  String get downloadedAnimeSection => 'Downloaded Anime';
  @override
  String get downloadedMangaSection => 'Downloaded Manga';
  @override
  String get activeDownloadsCount => 'Active Downloads';
  @override
  String get completedDownload => 'Completed';
  @override
  String get completedDownloads => 'Completed & Seeding';
  @override
  String downloadingEpisode(int number) => 'Downloading Episode $number...';
  @override
  String get downloading => 'Downloading';
  @override
  String get downloaded => 'Downloaded';
  @override
  String get viewAll => 'View all';

  // Episode Context Menu
  @override
  String get playEpisode => 'Play Episode';
  @override
  String get markAsWatched => 'Mark as Watched';
  @override
  String get markAsUnwatched => 'Mark as Unwatched';
  @override
  String markedAsWatched(int ep) => 'Episode $ep marked as watched';
  @override
  String markedAsUnwatched(int ep) => 'Episode $ep marked as unwatched';
  @override
  String get downloadEpisode => 'Download Episode';

  // Liquid Glass Effects Preference
  @override
  String get glassEffectSettingTitle => 'Liquid Glass Effects';
  @override
  String get glassEffectSettingSubtitle => 'Enable modern optical refraction and frosted glass styling across the app';
  @override
  String get glassTierFull => 'Full (Liquid Glass)';
  @override
  String get glassTierFullDesc => 'Dynamic backdrop refraction, specular rims, and fluid blur';
  @override
  String get glassTierCheap => 'Performance (Low)';
  @override
  String get glassTierCheapDesc => 'Lightweight translucent tint without sampling backdrops';
  @override
  String get glassTierOpaque => 'Disabled (Opaque)';
  @override
  String get glassTierOpaqueDesc => 'Solid high-contrast surface without transparency';

  // Edit Entry Modal
  @override
  String get editEntryTitle => 'Edit Entry';
  @override
  String get startDate => 'Start date';
  @override
  String get completionDate => 'Completion date';
  @override
  String get selectDate => 'Select a date';
  @override
  String get totalRewatches => 'Total rewatches';
  @override
  String get totalRereads => 'Total rereads';
  @override
  String get noScore => 'No score';
  @override
  String get saveChanges => 'Save changes';

  // TMDB / Series & Seasons
  @override
  String get seasons => 'Seasons';
  @override
  String get specials => 'Specials';
  @override
  String get selectSeason => 'Select season';
  @override
  String get seasonEpisodeCount => 'Episodes';
  @override
  String seasonEpisodesCount(int count) => '$count episodes';
  @override
  String get noEpisodesFound => 'No episodes found';
  @override
  String get tmdbSourceNotice => 'Metadata provided by The Movie Database (TMDB)';
  @override
  String get movieDetails => 'Movie Details';
  @override
  String get streamingComingSoon => 'Streaming providers for series will be available soon';
  @override
  String episodeRuntime(int minutes) => '${minutes}m';
}

