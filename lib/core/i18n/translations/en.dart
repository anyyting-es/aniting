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
  String get aboutSubtitle => 'Native Aniting Flutter Client v1.0.0';
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
  String get defaultDirectoryHint => 'Default (~/.cache/seanime/torrentstream on SSD)';
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
  String get exploreAllMarketplace => 'Explore Full Marketplace';
  @override
  String get allRecommended => 'All Recommended';
  @override
  String get searchExtensionsPrompt => 'Search extensions...';

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
