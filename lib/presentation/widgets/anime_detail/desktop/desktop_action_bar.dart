import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

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
    this.playFocusNode,
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
          _editFocusNode.requestFocus();
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
            _editFocusNode.requestFocus();
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
            return KeyEventResult.handled; // Lock right boundary
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
              _editFocusNode.requestFocus();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
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
    super.dispose();
  }

  Future<void> _launchTmdb(int mediaId) async {
    try {
      await launchUrlString(
        'https://www.themoviedb.org/${widget.isMovie ? "movie" : "tv"}/$mediaId',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _shareAnime(BuildContext context, String title, AppTranslations l10n) {
    final shareUrl = widget.isTmdb
        ? 'https://www.themoviedb.org/${widget.isMovie ? "movie" : "tv"}/${widget.mediaId}'
        : 'https://anilist.co/anime/${widget.mediaId}';
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.linkCopiedFor(title)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String newStatus,
  ) async {
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
      final nextEp = (widget.progress + 1).clamp(1, widget.totalEpisodes ?? (widget.progress + 1));
      playLabel = l10n.continueEpisodeNumbered(nextEp);
    } else {
      playLabel = l10n.watchEpisodeOne;
    }

    // Monochromatic Black & White button styling (clean contrast, no Material dynamic tint)
    final playButtonDecoration = M3EButtonDecoration(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return isDark ? Colors.white70 : Colors.black87;
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
          return isDark ? Colors.white.withValues(alpha: 0.92) : Colors.black.withValues(alpha: 0.90);
        }
        return isDark ? Colors.white : Colors.black;
      }),
      foregroundColor: WidgetStateProperty.all(isDark ? Colors.black : Colors.white),
    );

    final iconButtonDecoration = M3EIconButtonDecoration(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return Colors.white.withValues(alpha: 0.24);
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
          return Colors.white.withValues(alpha: 0.18);
        }
        return Colors.white.withValues(alpha: 0.10);
      }),
      foregroundColor: WidgetStateProperty.all(Colors.white),
      side: WidgetStateProperty.all(
        BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.0,
        ),
      ),
    );

    final activeToggleButtonDecoration = M3EIconButtonDecoration(
      backgroundColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.28)),
      foregroundColor: WidgetStateProperty.all(Colors.white),
      side: WidgetStateProperty.all(
        BorderSide(
          color: Colors.white.withValues(alpha: 0.40),
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
                                      Icon(AppIcons.info(iconPack),
                                          color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(l10n.streamingComingSoon)),
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

        // Quick Action 1: Status / Bookmark Dropdown (Always visible)
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
                icon: Icon(
                  AppIcons.edit(iconPack),
                  size: 18,
                ),
                onPressed: () => widget.onOpenEditEntryModal(widget.title),
              ),
          ],
          builder: (context, controller) {
            return M3EIconButton(
              focusNode: _editFocusNode,
              tooltip: widget.isTmdb ? l10n.editDetails : l10n.editInAnilist,
              icon: Icon(AppIcons.edit(iconPack), size: 21, color: Colors.white),
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
                      icon: Icon(AppIcons.share(iconPack), size: 21, color: Colors.white),
                      decoration: iconButtonDecoration,
                      size: M3EIconButtonSize.md,
                      onPressed: () => _shareAnime(context, widget.title, l10n),
                    ),

                    // Download Button (Torrents modal - Anime only)
                    if (!widget.isTmdb && widget.onDownload != null) ...[
                      const SizedBox(width: 10),
                      M3EIconButton(
                        focusNode: _downloadFocusNode,
                        tooltip: l10n.downloadWithTorrentClient,
                        icon: Icon(AppIcons.download(iconPack), size: 21, color: Colors.white),
                        decoration: iconButtonDecoration,
                        size: M3EIconButtonSize.md,
                        onPressed: widget.onDownload!,
                      ),
                    ],

                    // External Link (TMDB)
                    if (widget.isTmdb) ...[
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'The Movie Database (TMDB)',
                        child: M3EIconButton(
                          focusNode: _tmdbFocusNode,
                          icon: Icon(AppIcons.openInNew(iconPack), size: 21, color: Colors.white),
                          decoration: iconButtonDecoration,
                          size: M3EIconButtonSize.md,
                          onPressed: () => _launchTmdb(widget.mediaId),
                        ),
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
                _isExpanded ? AppIcons.chevronLeft(iconPack) : AppIcons.moreHoriz(iconPack),
                size: 21,
                color: Colors.white,
              ),
            ),
            decoration: _isExpanded ? activeToggleButtonDecoration : iconButtonDecoration,
            size: M3EIconButtonSize.md,
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
          ),
        ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

