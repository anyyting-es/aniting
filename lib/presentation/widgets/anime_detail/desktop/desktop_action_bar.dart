import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/theme/app_focus_coordinator.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
import 'package:aniting/data/services/offline_library_service.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/widgets/anime_detail/anime_episode_target.dart';

class DesktopActionBar extends ConsumerStatefulWidget {
  final int mediaId;
  final String title;
  final int progress;
  final int? idMal;
  final String? trailerId;
  final String? trailerSite;
  final bool hasTrailer;
  final AnimeDetailTab currentTab;
  final bool onlineEnabled;
  final bool torrentEnabled;
  final bool isTmdb;
  final bool isMovie;
  final String? userStatus;
  final int? totalEpisodes;
  final VoidCallback onPlayNext;
  final void Function(String title) onOpenEditEntryModal;
  final ValueChanged<AnimeDetailTab> onTabChanged;
  final VoidCallback? onDownload;
  final bool isLocalMode;
  final bool hasLocalFiles;
  final VoidCallback? onToggleLocalMode;
  final void Function(String mode)? onModeChanged;
  final VoidCallback? onPlayFocused;

  /// Shows the Online / Torrent / Local source selector on the right edge of
  /// the action bar. Only AniList entries use this flow: TMDB, Plex and
  /// Jellyfin resolve their source when an episode is clicked.
  final bool showSourceSelector;

  /// Installed online streaming extensions shown inside the source selector.
  final List<OnlinestreamProvider> providers;
  final OnlinestreamProvider? selectedProvider;
  final ValueChanged<OnlinestreamProvider?>? onProviderChanged;

  /// When set, the share action copies this URL instead of the AniList/TMDB
  /// link, so data sources outside those catalogs (Plex/Jellyfin) can share
  /// their own deep link.
  final String? shareUrl;

  /// Whether AniList tracking (status/edit menu) applies to this entry.
  final bool showTracking;

  const DesktopActionBar({
    super.key,
    required this.mediaId,
    required this.title,
    required this.progress,
    required this.idMal,
    this.trailerId,
    this.trailerSite,
    this.hasTrailer = false,
    required this.currentTab,
    required this.onlineEnabled,
    required this.torrentEnabled,
    this.isTmdb = false,
    this.isMovie = false,
    this.userStatus,
    this.totalEpisodes,
    required this.onPlayNext,
    required this.onOpenEditEntryModal,
    required this.onTabChanged,
    this.onDownload,
    this.isLocalMode = false,
    this.hasLocalFiles = false,
    this.onToggleLocalMode,
    this.onModeChanged,
    this.onPlayFocused,
    this.showSourceSelector = false,
    this.providers = const [],
    this.selectedProvider,
    this.onProviderChanged,
    this.playFocusNode,
    this.shareUrl,
    this.showTracking = true,
  });

  final FocusNode? playFocusNode;

  @override
  ConsumerState<DesktopActionBar> createState() => _DesktopActionBarState();
}

class _DesktopActionBarState extends ConsumerState<DesktopActionBar> {
  bool _isExpanded = false;
  late final FocusNode _playFocusNode;
  bool _ownsPlayFocusNode = false;
  late final FocusNode _editFocusNode;
  late final FocusNode _shareFocusNode;
  late final FocusNode _downloadFocusNode;
  late final FocusNode _tmdbFocusNode;
  late final FocusNode _expandFocusNode;
  late final FocusNode _sourceModeFocusNode;
  late final FocusNode _providerFocusNode;
  final GlassMenuController _sourceModeMenuController = GlassMenuController();
  final GlassMenuController _providerMenuController = GlassMenuController();

  bool get _isOnlineMode =>
      !widget.isLocalMode && widget.currentTab == AnimeDetailTab.online;
  bool get _isTorrentMode =>
      !widget.isLocalMode && widget.currentTab == AnimeDetailTab.torrent;
  bool get _isLocalMode => widget.isLocalMode;
  bool get _providerSelectorVisible =>
      widget.showSourceSelector && _isOnlineMode;

  @override
  void initState() {
    super.initState();
    if (widget.playFocusNode != null) {
      _playFocusNode = widget.playFocusNode!;
      _ownsPlayFocusNode = false;
    } else {
      _playFocusNode = FocusNode(debugLabel: 'desktop_play_button');
      _ownsPlayFocusNode = true;
    }
    _playFocusNode.addListener(_handlePlayFocusChange);
    _playFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          return KeyEventResult.handled; // Lock left boundary
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (widget.showTracking) {
            _editFocusNode.requestFocus();
          } else if (_isExpanded) {
            _shareFocusNode.requestFocus();
          } else {
            _expandFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    _editFocusNode = FocusNode(
      debugLabel: 'desktop_edit_button',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _playFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (_isExpanded) {
              _shareFocusNode.requestFocus();
            } else {
              _expandFocusNode.requestFocus();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _shareFocusNode = FocusNode(
      debugLabel: 'desktop_share_button',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (widget.showTracking) {
              _editFocusNode.requestFocus();
            } else {
              _playFocusNode.requestFocus();
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (!widget.isTmdb && widget.onDownload != null) {
              _downloadFocusNode.requestFocus();
            } else if (widget.isTmdb) {
              _tmdbFocusNode.requestFocus();
            } else {
              _expandFocusNode.requestFocus();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _downloadFocusNode = FocusNode(
      debugLabel: 'desktop_download_button',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _shareFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _expandFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _tmdbFocusNode = FocusNode(
      debugLabel: 'desktop_tmdb_button',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _shareFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _expandFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _expandFocusNode = FocusNode(
      debugLabel: 'desktop_expand_button',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (widget.showSourceSelector) {
              _sourceModeFocusNode.requestFocus();
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (_isExpanded) {
              if (!widget.isTmdb && widget.onDownload != null) {
                _downloadFocusNode.requestFocus();
              } else if (widget.isTmdb) {
                _tmdbFocusNode.requestFocus();
              } else {
                _shareFocusNode.requestFocus();
              }
            } else {
              if (widget.showTracking) {
                _editFocusNode.requestFocus();
              } else {
                _playFocusNode.requestFocus();
              }
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _sourceModeFocusNode = FocusNode(
      debugLabel: 'desktop_source_mode_selector',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            _expandFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            if (_providerSelectorVisible) {
              _providerFocusNode.requestFocus();
            }
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            _sourceModeMenuController.open();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _providerFocusNode = FocusNode(
      debugLabel: 'desktop_source_provider_selector',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            _sourceModeFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            _providerMenuController.open();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  void _selectMode(String mode) {
    if (widget.onModeChanged != null) {
      widget.onModeChanged!(mode);
      return;
    }
    if (mode == 'local') {
      if (!widget.isLocalMode) widget.onToggleLocalMode?.call();
      return;
    }
    if (widget.isLocalMode) widget.onToggleLocalMode?.call();
    widget.onTabChanged(
      mode == 'torrent' ? AnimeDetailTab.torrent : AnimeDetailTab.online,
    );
  }

  void _selectProvider(OnlinestreamProvider provider) {
    if (widget.selectedProvider?.id == provider.id) return;
    widget.onProviderChanged?.call(provider);
  }

  void _handlePlayFocusChange() {
    if (_playFocusNode.hasFocus) {
      widget.onPlayFocused?.call();
    }
  }

  @override
  void dispose() {
    _playFocusNode.removeListener(_handlePlayFocusChange);
    if (_ownsPlayFocusNode) {
      _playFocusNode.dispose();
    }
    _editFocusNode.dispose();
    _shareFocusNode.dispose();
    _downloadFocusNode.dispose();
    _tmdbFocusNode.dispose();
    _expandFocusNode.dispose();
    _sourceModeFocusNode.dispose();
    _providerFocusNode.dispose();
    super.dispose();
  }

  void _shareAnime(BuildContext context, String title, AppTranslations l10n) {
    final shareUrl =
        widget.shareUrl ??
        (widget.isTmdb
            ? 'https://www.themoviedb.org/${widget.isMovie ? "movie" : "tv"}/${widget.mediaId}'
            : 'https://anilist.co/anime/${widget.mediaId}');
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.linkCopiedFor(title)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    final repo = ref.read(repositoryProvider);
    final serverState = ref.read(serverNotifierProvider);
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;
    final l10n = ref.read(translationsProvider);

    if (isLoggedIn && !widget.isTmdb) {
      await repo.editAnilistListEntry(
        mediaId: widget.mediaId,
        type: 'anime',
        status: newStatus,
        progress: widget.progress,
      );
    }

    await OfflineLibraryService.instance.saveAnimeEntryFromEdit(
      mediaId: widget.mediaId,
      title: widget.title,
      status: newStatus,
      progress: widget.progress,
      totalCount: widget.totalEpisodes,
      isTmdb: widget.isTmdb,
    );

    if (context.mounted) {
      ref.invalidate(animeCollectionProvider);
      ref.invalidate(continueWatchingProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsSaved),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildSourceModeSelector(
    bool isDark,
    AppIconPack iconPack,
    AppTranslations l10n,
  ) {
    final icon = _isLocalMode
        ? AppIcons.folderFilled(iconPack)
        : (_isTorrentMode
              ? AppIcons.cloudDownload(iconPack)
              : AppIcons.globe(iconPack));
    final label = _isLocalMode
        ? l10n.localLibrary
        : (_isTorrentMode ? l10n.torrentStreaming : l10n.onlineStreaming);

    return GlassMenuAnchor(
      controller: _sourceModeMenuController,
      width: 232,
      barrierLabel: l10n.closeSourceSelector,
      items: [
        if (widget.onlineEnabled)
          GlassMenuItem(
            label: l10n.onlineStreaming,
            icon: Icon(
              _isOnlineMode
                  ? AppIcons.checkCircleFilled(iconPack)
                  : AppIcons.globe(iconPack),
              size: 18,
              color: _isOnlineMode ? const Color(0xFF10B981) : null,
            ),
            onPressed: () => _selectMode('online'),
          ),
        if (widget.torrentEnabled)
          GlassMenuItem(
            label: l10n.torrentStreaming,
            icon: Icon(
              _isTorrentMode
                  ? AppIcons.checkCircleFilled(iconPack)
                  : AppIcons.cloudDownload(iconPack),
              size: 18,
              color: _isTorrentMode ? const Color(0xFF3B82F6) : null,
            ),
            onPressed: () => _selectMode('torrent'),
          ),
        if (widget.hasLocalFiles)
          GlassMenuItem(
            label: l10n.localLibrary,
            icon: Icon(
              _isLocalMode
                  ? AppIcons.checkCircleFilled(iconPack)
                  : AppIcons.folderFilled(iconPack),
              size: 18,
              color: _isLocalMode ? const Color(0xFFF59E0B) : null,
            ),
            onPressed: () => _selectMode('local'),
          ),
      ],
      builder: (context, controller) => _DesktopSourcePill(
        focusNode: _sourceModeFocusNode,
        icon: icon,
        label: label,
        isDark: isDark,
        iconPack: iconPack,
        tooltip: l10n.selectSource,
        onTap: controller.open,
      ),
    );
  }

  Widget _buildProviderSelector(
    BuildContext context,
    bool isDark,
    AppIconPack iconPack,
    AppTranslations l10n,
  ) {
    final theme = Theme.of(context);
    final selected = widget.selectedProvider;

    return GlassMenuAnchor(
      controller: _providerMenuController,
      width: 240,
      barrierLabel: l10n.closeSourceSelector,
      items: widget.providers.isEmpty
          ? [
              GlassMenuItem(
                label: l10n.noOnlineExtensionsInstalled,
                icon: Icon(AppIcons.extensionOff(iconPack), size: 18),
              ),
            ]
          : [
              for (final provider in widget.providers)
                GlassMenuItem(
                  label: provider.name,
                  icon: Icon(
                    selected?.id == provider.id
                        ? AppIcons.checkCircleFilled(iconPack)
                        : AppIcons.globe(iconPack),
                    size: 18,
                    color: selected?.id == provider.id
                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                        : null,
                  ),
                  onPressed: () => _selectProvider(provider),
                ),
            ],
      builder: (context, controller) => _DesktopSourcePill(
        focusNode: _providerFocusNode,
        icon: AppIcons.globe(iconPack),
        label: selected?.name ?? l10n.source,
        isDark: isDark,
        iconPack: iconPack,
        tooltip: l10n.source,
        maxWidth: 150,
        onTap: controller.open,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);

    // Dynamic Reactive Play Label
    final String playLabel;
    if (widget.userStatus == 'COMPLETED') {
      playLabel = l10n.rewatch;
    } else if (widget.isMovie) {
      playLabel = widget.progress > 0 ? l10n.continueWatching : l10n.play;
    } else if (widget.progress > 0) {
      final nextEp = resolveNextEpisodeNumber(
        progress: widget.progress,
        totalEpisodes: widget.totalEpisodes,
        userStatus: widget.userStatus,
      );
      playLabel = l10n.continueEpisodeNumbered(nextEp);
    } else {
      playLabel = l10n.watchEpisodeOne;
    }

    // Monochromatic Black & White button styling (clean contrast, no Material dynamic tint)
    final playButtonDecoration = M3EButtonDecoration(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return isDark ? Colors.white70 : Colors.black87;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return isDark
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.black.withValues(alpha: 0.90);
        }
        return isDark ? Colors.white : Colors.black;
      }),
      foregroundColor: WidgetStateProperty.all(
        isDark ? Colors.black : Colors.white,
      ),
    );

    // Secondary icon buttons: white-on-media in dark mode, theme surfaces in
    // light mode (the hero banner gets a light scrim there, so white would
    // vanish).
    final actionIconColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final iconChipBase = isDark
        ? Colors.white
        : theme.colorScheme.surfaceContainerHighest;

    final iconButtonDecoration = M3EIconButtonDecoration(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return iconChipBase.withValues(alpha: isDark ? 0.24 : 0.95);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return iconChipBase.withValues(alpha: isDark ? 0.18 : 0.85);
        }
        return iconChipBase.withValues(alpha: isDark ? 0.10 : 0.65);
      }),
      foregroundColor: WidgetStateProperty.all(
        isDark ? Colors.white : theme.colorScheme.onSurface,
      ),
      side: WidgetStateProperty.all(
        BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : theme.colorScheme.outlineVariant,
          width: 1.0,
        ),
      ),
    );

    final activeToggleButtonDecoration = M3EIconButtonDecoration(
      backgroundColor: WidgetStateProperty.all(
        iconChipBase.withValues(alpha: isDark ? 0.28 : 0.95),
      ),
      foregroundColor: WidgetStateProperty.all(
        isDark ? Colors.white : theme.colorScheme.onSurface,
      ),
      side: WidgetStateProperty.all(
        BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.40)
              : theme.colorScheme.primary.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reactive Play Button (Same standard height as all buttons, contracts horizontally on expand)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  constraints: BoxConstraints(
                    minWidth: _isExpanded ? 220 : 270,
                    maxWidth: _isExpanded ? 245 : 330,
                  ),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent || event is KeyRepeatEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: M3EButton.icon(
                      focusNode: _playFocusNode,
                      autofocus: true,
                      style: M3EButtonStyle.filled,
                      decoration: playButtonDecoration,
                      size: M3EButtonSize.md,
                      shape: M3EButtonShape.round,
                      icon: Icon(
                        AppIcons.play(iconPack),
                        size: 21,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                      label: Text(
                        playLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                      onPressed: widget.isTmdb
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        AppIcons.info(iconPack),
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(l10n.streamingComingSoon),
                                      ),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : widget.onPlayNext,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Quick Action 1: Status / Bookmark Dropdown (Always visible on tracked entries)
                if (widget.showTracking)
                  GlassMenuAnchor(
                    width: 210,
                    items: [
                      GlassMenuItem(
                        label: l10n.statusWatching,
                        icon: Icon(
                          AppIcons.playCircleFilled(iconPack),
                          size: 18,
                          color: const Color(0xFF10B981),
                        ),
                        onPressed: () => _updateStatus(context, 'CURRENT'),
                      ),
                      GlassMenuItem(
                        label: l10n.statusPlanning,
                        icon: Icon(
                          AppIcons.bookmarkAdded(iconPack),
                          size: 18,
                          color: const Color(0xFF3B82F6),
                        ),
                        onPressed: () => _updateStatus(context, 'PLANNING'),
                      ),
                      GlassMenuItem(
                        label: l10n.statusCompleted,
                        icon: Icon(
                          AppIcons.checkCircleFilled(iconPack),
                          size: 18,
                          color: const Color(0xFF8B5CF6),
                        ),
                        onPressed: () => _updateStatus(context, 'COMPLETED'),
                      ),
                      GlassMenuItem(
                        label: l10n.statusPaused,
                        icon: Icon(
                          AppIcons.pauseCircleFilled(iconPack),
                          size: 18,
                          color: const Color(0xFFF59E0B),
                        ),
                        onPressed: () => _updateStatus(context, 'PAUSED'),
                      ),
                      GlassMenuItem(
                        label: l10n.statusDropped,
                        icon: Icon(
                          AppIcons.cancel(iconPack),
                          size: 18,
                          color: const Color(0xFFEF4444),
                        ),
                        onPressed: () => _updateStatus(context, 'DROPPED'),
                      ),
                      if (!widget.isTmdb)
                        GlassMenuItem(
                          label: l10n.editDetails,
                          icon: Icon(AppIcons.edit(iconPack), size: 18),
                          onPressed: () =>
                              widget.onOpenEditEntryModal(widget.title),
                        ),
                    ],
                    builder: (context, controller) {
                      return M3EIconButton(
                        focusNode: _editFocusNode,
                        tooltip: widget.isTmdb
                            ? l10n.editDetails
                            : l10n.editInAnilist,
                        icon: Icon(
                          AppIcons.edit(iconPack),
                          size: 21,
                          color: actionIconColor,
                        ),
                        decoration: iconButtonDecoration,
                        size: M3EIconButtonSize.md,
                        onPressed: controller.open,
                      );
                    },
                  ),

                // ─── Collapsible Secondary Actions (Smoothly expands to the LEFT of the expand button) ───
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: _isExpanded
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 10),

                            // Share Button
                            M3EIconButton(
                              focusNode: _shareFocusNode,
                              tooltip: l10n.share,
                              icon: Icon(
                                AppIcons.share(iconPack),
                                size: 21,
                                color: actionIconColor,
                              ),
                              decoration: iconButtonDecoration,
                              size: M3EIconButtonSize.md,
                              onPressed: () =>
                                  _shareAnime(context, widget.title, l10n),
                            ),

                            // Download Button (Torrents modal - Anime only)
                            if (!widget.isTmdb &&
                                widget.onDownload != null) ...[
                              const SizedBox(width: 10),
                              M3EIconButton(
                                focusNode: _downloadFocusNode,
                                tooltip: l10n.downloadWithTorrentClient,
                                icon: Icon(
                                  AppIcons.download(iconPack),
                                  size: 21,
                                  color: actionIconColor,
                                ),
                                decoration: iconButtonDecoration,
                                size: M3EIconButtonSize.md,
                                onPressed: widget.onDownload!,
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 10),

                // Quick Action 2: Expand / Collapse Toggle Button (Focusable with D-PAD, pushes to the right)
                Tooltip(
                  message: _isExpanded ? l10n.collapse : l10n.moreOptions,
                  child: M3EIconButton(
                    focusNode: _expandFocusNode,
                    icon: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        _isExpanded
                            ? AppIcons.chevronLeft(iconPack)
                            : AppIcons.moreHoriz(iconPack),
                        size: 21,
                        color: actionIconColor,
                      ),
                    ),
                    decoration: _isExpanded
                        ? activeToggleButtonDecoration
                        : iconButtonDecoration,
                    size: M3EIconButtonSize.md,
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.showSourceSelector) ...[
          const SizedBox(width: 12),
          _buildSourceModeSelector(isDark, iconPack, l10n),
          if (_providerSelectorVisible) ...[
            const SizedBox(width: 8),
            _buildProviderSelector(context, isDark, iconPack, l10n),
          ],
        ],
      ],
    );
  }
}

/// Compact liquid-glass pill used by the desktop action bar to expose the
/// playback source (Online / Torrent / Local) and the online extension.
class _DesktopSourcePill extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool isDark;
  final AppIconPack iconPack;
  final String tooltip;
  final double maxWidth;
  final VoidCallback onTap;

  const _DesktopSourcePill({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.isDark,
    required this.iconPack,
    required this.tooltip,
    required this.onTap,
    this.maxWidth = 180,
  });

  @override
  State<_DesktopSourcePill> createState() => _DesktopSourcePillState();
}

class _DesktopSourcePillState extends State<_DesktopSourcePill> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _DesktopSourcePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != widget.focusNode.hasFocus) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
      if (widget.focusNode.hasFocus) {
        AppFocusCoordinator.onNodeFocused(widget.focusNode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _isFocused || _isHovered;
    final background = widget.isDark
        ? Colors.white.withValues(alpha: isActive ? 0.20 : 0.10)
        : theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: isActive ? 0.95 : 0.65,
          );
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: _isFocused ? 0.45 : 0.18)
        : theme.colorScheme.outlineVariant;
    final foreground = widget.isDark
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Tooltip(
      message: widget.tooltip,
      child: Focus(
        focusNode: widget.focusNode,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            AppFocusCoordinator.switchToMouse(widget.focusNode);
            setState(() => _isHovered = true);
          },
          onExit: (_) {
            if (AppFocusCoordinator.lastHoveredNode == widget.focusNode) {
              AppFocusCoordinator.lastHoveredNode = null;
            }
            setState(() => _isHovered = false);
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              canRequestFocus: false,
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(25),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: borderColor,
                    width: _isFocused ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 19, color: foreground),
                    const SizedBox(width: 7),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: widget.maxWidth),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      AppIcons.arrowDropDown(widget.iconPack),
                      size: 19,
                      color: foreground.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
