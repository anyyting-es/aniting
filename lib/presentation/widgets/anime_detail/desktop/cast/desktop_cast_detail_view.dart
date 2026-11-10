import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/theme/theme_provider.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'desktop_cast_deck.dart';
import 'desktop_cast_info_panel.dart';
import 'desktop_cast_models.dart';
import 'desktop_cast_seiyuu_card.dart';

/// Immersive full-screen detail view for anime characters & cast.
/// Features deep static backdrop blur, Hero card animation, a dynamic 3D deck-of-cards carousel,
/// rock-solid metadata alignment, and a prominent vertical Seiyuu showcase on the right.
class DesktopCastDetailView extends ConsumerStatefulWidget {
  final List<DesktopCastItem> items;
  final int initialIndex;
  final int? mediaId;
  final String? bannerUrl;
  final bool isTmdb;

  const DesktopCastDetailView({
    super.key,
    required this.items,
    required this.initialIndex,
    this.mediaId,
    this.bannerUrl,
    required this.isTmdb,
  });

  /// Opens the detailed cast view seamlessly over the current page.
  static Future<void> open(
    BuildContext context, {
    required List<DesktopCastItem> items,
    required int initialIndex,
    int? mediaId,
    String? bannerUrl,
    bool isTmdb = false,
  }) {
    if (isTmdb) return Future.value();
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return DesktopCastDetailView(
            items: items,
            initialIndex: initialIndex,
            mediaId: mediaId,
            bannerUrl: bannerUrl,
            isTmdb: isTmdb,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<DesktopCastDetailView> createState() => _DesktopCastDetailViewState();
}

class _DesktopCastDetailViewState extends ConsumerState<DesktopCastDetailView> {
  late int _currentIndex;
  late List<DesktopCastItem> _items;
  bool _isLoadingVa = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'desktop_cast_detail');

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
    _items = List.of(widget.items);
    _checkAndFetchVoiceActors();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAndFetchVoiceActors() async {
    if (widget.isTmdb || widget.mediaId == null || _items.isEmpty) return;

    final hasAnyVa = _items.any((item) => item.vaName != null && item.vaName!.isNotEmpty);
    if (hasAnyVa) return;

    setState(() => _isLoadingVa = true);
    try {
      final repo = ref.read(repositoryProvider);
      final rawEdges = await repo.getAnimeCharactersWithVoiceActors(widget.mediaId!);
      if (!mounted || rawEdges == null || rawEdges.isEmpty) return;

      final Map<dynamic, DesktopCastItem> enrichedMap = {};
      for (int i = 0; i < rawEdges.length; i++) {
        final parsed = DesktopCastItem.fromEdge(rawEdges[i], isTmdb: false, index: i);
        enrichedMap[parsed.id] = parsed;
        enrichedMap[parsed.name.toLowerCase()] = parsed;
      }

      setState(() {
        _items = _items.map((item) {
          final match = enrichedMap[item.id] ?? enrichedMap[item.name.toLowerCase()];
          if (match != null) {
            return item.copyWith(
              vaName: match.vaName,
              vaNativeName: match.vaNativeName,
              vaImageUrl: match.vaImageUrl,
              vaLanguage: match.vaLanguage,
              bio: (item.bio == null || item.bio!.isEmpty) ? match.bio : item.bio,
              gender: item.gender ?? match.gender,
              age: item.age ?? match.age,
              birthday: item.birthday ?? match.birthday,
              bloodType: item.bloodType ?? match.bloodType,
              nativeName: item.nativeName ?? match.nativeName,
              alternativeNames: item.alternativeNames.isNotEmpty ? item.alternativeNames : match.alternativeNames,
            );
          }
          return item;
        }).toList();
      });
    } catch (_) {
      // Keep existing items if fetch fails
    } finally {
      if (mounted) setState(() => _isLoadingVa = false);
    }
  }

  void _onSelectCharacter(int index) {
    if (index >= 0 && index < _items.length && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  void _previousCharacter() {
    if (_currentIndex > 0) {
      _onSelectCharacter(_currentIndex - 1);
    }
  }

  void _nextCharacter() {
    if (_currentIndex < _items.length - 1) {
      _onSelectCharacter(_currentIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeSettings = ref.watch(themeProvider);
    final isDark = theme.brightness == Brightness.dark;
    final isOled = themeSettings.isOled && isDark;
    final iconPack = ref.watch(iconPackProvider);

    final currentItem = _items.isNotEmpty ? _items[_currentIndex] : null;

    final backdropBase = isOled
        ? Colors.black
        : (isDark ? const Color(0xFF090B0E) : const Color(0xFF14171C));

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousCharacter();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextCharacter();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ─── 1. Giant character portrait as a heavily blurred backdrop ───
            Positioned.fill(
              child: ColoredBox(color: backdropBase),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // AnimatedSwitcher's default Stack uses loose constraints:
                // CachedNetworkImage would lay itself out at the portrait's
                // intrinsic (square) size and sit centred. Tight constraints
                // make the blurred portrait cover the whole viewport.
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [...previousChildren, ?currentChild],
                ),
                child: currentItem?.imageUrl != null
                    ? _CastBackdropImage(
                        key: ValueKey(
                          'cast_backdrop_${currentItem!.id}_${currentItem.imageUrl}',
                        ),
                        imageUrl: currentItem.imageUrl!,
                        isDark: isDark,
                        isOled: isOled,
                      )
                    : const SizedBox.expand(),
              ),
            ),

            // ─── 1b. Legibility scrim: the portrait still reads through, but
            // the name, biography and seiyuu card stay perfectly readable. ───
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        backdropBase.withValues(
                          alpha: isOled ? 0.58 : 0.46,
                        ),
                        backdropBase.withValues(
                          alpha: isOled ? 0.74 : 0.64,
                        ),
                        backdropBase.withValues(
                          alpha: isOled ? 0.92 : 0.84,
                        ),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ─── 2. Simple Minimal Back Button (Identical to the anime detail screen) ───
            Positioned(
              top: 24,
              left: 28,
              child: SafeArea(
                child: M3EIconButton(
                  decoration: M3EIconButtonDecoration(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return Colors.white.withValues(alpha: 0.24);
                      }
                      if (states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)) {
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
                  ),
                  size: M3EIconButtonSize.sm,
                  icon: Icon(
                    AppIcons.arrowLeft(iconPack),
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // ─── 3. Center Stage: Deck of Cards (Left) | Bio & Attributes (Center) | Seiyuu (Right) ───
            Positioned.fill(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: currentItem != null
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ── Left: Dynamic 3D Perspective Deck of Cards ──
                              DesktopCastDeck(
                                items: _items,
                                currentIndex: _currentIndex,
                                onSelectIndex: _onSelectCharacter,
                                mediaId: widget.mediaId,
                                cardWidth: 265,
                                cardHeight: 395,
                              ),

                              const SizedBox(width: 32),

                              // ── Center: Character Roles, Attributes, and Bio ──
                              Expanded(
                                child: DesktopCastInfoPanel(
                                  key: ValueKey('char_info_${currentItem.id}_$_currentIndex'),
                                  item: currentItem,
                                ),
                              ),

                              const SizedBox(width: 28),

                              // ── Right: Prominent Vertical Seiyuu Card ──
                              DesktopCastSeiyuuCard(
                                item: currentItem,
                                isLoadingVa: _isLoadingVa,
                                width: 235,
                                height: 405,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen character portrait rendered as a giant, heavily blurred
/// backdrop. It is scaled past the viewport so the blur never shows a
/// transparent fringe at the edges.
class _CastBackdropImage extends StatelessWidget {
  final String imageUrl;
  final bool isDark;
  final bool isOled;

  const _CastBackdropImage({
    super.key,
    required this.imageUrl,
    required this.isDark,
    required this.isOled,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: 46,
          sigmaY: 46,
          tileMode: TileMode.decal,
        ),
        child: Transform.scale(
          scale: 1.22,
          child: Opacity(
            opacity: isOled ? 0.74 : (isDark ? 0.68 : 0.52),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              fadeInDuration: const Duration(milliseconds: 280),
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
