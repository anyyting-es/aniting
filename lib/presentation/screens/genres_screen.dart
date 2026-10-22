import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/presentation/screens/genre_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';

class GenreItem {
  final String key;
  final String nameEs;
  final String nameEn;
  final String imageUrl;
  final IconData icon;
  final List<Color> gradientColors;

  const GenreItem({
    required this.key,
    required this.nameEs,
    required this.nameEn,
    required this.imageUrl,
    required this.icon,
    this.gradientColors = const [Color(0xFF1E1E2C), Color(0xFF12121A)],
  });
}

const List<GenreItem> kAppGenres = [
  GenreItem(
    key: 'Action',
    nameEs: 'Acción',
    nameEn: 'Action',
    imageUrl: 'https://image.tmdb.org/t/p/w300/lTDtH9YnFWJdwOgNuB4dUAzGOQl.jpg',
    icon: Icons.local_fire_department_rounded,
    gradientColors: [Color(0xFF5A1818), Color(0xFF1E0E0E)],
  ),
  GenreItem(
    key: 'Romance',
    nameEs: 'Romance',
    nameEn: 'Romance',
    imageUrl: 'https://image.tmdb.org/t/p/w300/aneTvaOGDbCYtAlwF1Zc4A2O7at.jpg',
    icon: Icons.favorite_rounded,
    gradientColors: [Color(0xFF5A1838), Color(0xFF1E0E18)],
  ),
  GenreItem(
    key: 'Fantasy',
    nameEs: 'Fantasía',
    nameEn: 'Fantasy',
    imageUrl: 'https://image.tmdb.org/t/p/w300/qOyARkfwp6imzDtdz1RMVgg1EyF.jpg',
    icon: Icons.auto_awesome_rounded,
    gradientColors: [Color(0xFF38185A), Color(0xFF140A24)],
  ),
  GenreItem(
    key: 'Isekai',
    nameEs: 'Isekai',
    nameEn: 'Isekai',
    imageUrl: 'https://image.tmdb.org/t/p/w300/pfgndj46RLPVJRWkUSCJBgLJ93w.jpg',
    icon: Icons.travel_explore_rounded,
    gradientColors: [Color(0xFF18385A), Color(0xFF0A1828)],
  ),
  GenreItem(
    key: 'Adventure',
    nameEs: 'Aventura',
    nameEn: 'Adventure',
    imageUrl: 'https://image.tmdb.org/t/p/w300/2rmK7mnchw9Xr3XdiTFSxTTLXqv.jpg',
    icon: Icons.explore_rounded,
    gradientColors: [Color(0xFF184A38), Color(0xFF0A2018)],
  ),
  GenreItem(
    key: 'Comedy',
    nameEs: 'Comedia',
    nameEn: 'Comedy',
    imageUrl: 'https://image.tmdb.org/t/p/w300/shXdGFZIEaSmiOkVW2BeEaPihuA.jpg',
    icon: Icons.sentiment_very_satisfied_rounded,
    gradientColors: [Color(0xFF5A4418), Color(0xFF221808)],
  ),
  GenreItem(
    key: 'Sci-Fi',
    nameEs: 'Ciencia Ficción',
    nameEn: 'Sci-Fi',
    imageUrl: 'https://image.tmdb.org/t/p/w300/ly0tvRfOp936Zmr6vepusFeo7lp.jpg',
    icon: Icons.rocket_launch_rounded,
    gradientColors: [Color(0xFF18285A), Color(0xFF0A1028)],
  ),
  GenreItem(
    key: 'Slice of Life',
    nameEs: 'Vida Cotidiana',
    nameEn: 'Slice of Life',
    imageUrl: 'https://image.tmdb.org/t/p/w300/1rfiXsdRf2cYQOzV2CosFKYuF6d.jpg',
    icon: Icons.coffee_rounded,
    gradientColors: [Color(0xFF4A3828), Color(0xFF1E140C)],
  ),
  GenreItem(
    key: 'Drama',
    nameEs: 'Drama',
    nameEn: 'Drama',
    imageUrl: 'https://image.tmdb.org/t/p/w300/2BgABDABstTVOiAFnoZpkFnePAS.jpg',
    icon: Icons.theater_comedy_rounded,
    gradientColors: [Color(0xFF2E243A), Color(0xFF14101A)],
  ),
  GenreItem(
    key: 'Mystery',
    nameEs: 'Misterio',
    nameEn: 'Mystery',
    imageUrl: 'https://image.tmdb.org/t/p/w300/k0iYs0nAH2ouXFb7elRIKshxEWD.jpg',
    icon: Icons.psychology_alt_rounded,
    gradientColors: [Color(0xFF1E1E3A), Color(0xFF0A0A1A)],
  ),
  GenreItem(
    key: 'Horror',
    nameEs: 'Terror',
    nameEn: 'Horror',
    imageUrl: 'https://image.tmdb.org/t/p/w300/3Nz7ZiEebqwOYYEzoK2jo1LQsug.jpg',
    icon: Icons.nightlight_round,
    gradientColors: [Color(0xFF4A1414), Color(0xFF1A0606)],
  ),
  GenreItem(
    key: 'Supernatural',
    nameEs: 'Sobrenatural',
    nameEn: 'Supernatural',
    imageUrl: 'https://image.tmdb.org/t/p/w300/z8IPicmEKXUO4I2UDdMEqw7RqOE.jpg',
    icon: Icons.blur_on_rounded,
    gradientColors: [Color(0xFF3E1E4A), Color(0xFF180A20)],
  ),
  GenreItem(
    key: 'Sports',
    nameEs: 'Deportes',
    nameEn: 'Sports',
    imageUrl: 'https://image.tmdb.org/t/p/w300/12mYMPE7Jy7rhDv0rn95GEtF94V.jpg',
    icon: Icons.sports_basketball_rounded,
    gradientColors: [Color(0xFF5A3018), Color(0xFF241006)],
  ),
  GenreItem(
    key: 'Music',
    nameEs: 'Música',
    nameEn: 'Music',
    imageUrl: 'https://image.tmdb.org/t/p/w300/3X2DJjlEKszFwclHsTV8SaySyXy.jpg',
    icon: Icons.music_note_rounded,
    gradientColors: [Color(0xFF184A4A), Color(0xFF0A2020)],
  ),
  GenreItem(
    key: 'Mecha',
    nameEs: 'Mecha',
    nameEn: 'Mecha',
    imageUrl: 'https://image.tmdb.org/t/p/w300/2NNKYsWXoO9w8fMctWX7utqyh95.jpg',
    icon: Icons.precision_manufacturing_rounded,
    gradientColors: [Color(0xFF28384A), Color(0xFF101820)],
  ),
  GenreItem(
    key: 'Psychological',
    nameEs: 'Psicológico',
    nameEn: 'Psychological',
    imageUrl: 'https://image.tmdb.org/t/p/w300/A1Larywbw79kZQqkvCEiPHJqdLN.jpg',
    icon: Icons.track_changes_rounded,
    gradientColors: [Color(0xFF401828), Color(0xFF1A0810)],
  ),
  GenreItem(
    key: 'Thriller',
    nameEs: 'Suspenso',
    nameEn: 'Thriller',
    imageUrl: 'https://image.tmdb.org/t/p/w300/zTNsCRFjWaBxM6Ca5c510e1ewPo.jpg',
    icon: Icons.flash_on_rounded,
    gradientColors: [Color(0xFF4A2818), Color(0xFF1E0C06)],
  ),
  GenreItem(
    key: 'Ecchi',
    nameEs: 'Ecchi',
    nameEn: 'Ecchi',
    imageUrl: 'https://image.tmdb.org/t/p/w300/oF8PNdntjZ7DUrAvnhNPPNRi0q6.jpg',
    icon: Icons.whatshot_rounded,
    gradientColors: [Color(0xFF5A1840), Color(0xFF200614)],
  ),
];

class GenresScreen extends ConsumerStatefulWidget {
  const GenresScreen({super.key});

  @override
  ConsumerState<GenresScreen> createState() => _GenresScreenState();
}

class _GenresScreenState extends ConsumerState<GenresScreen> {
  bool _canLoadImages = false;
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeAnimation == null) {
      final animation = ModalRoute.of(context)?.animation;
      _routeAnimation = animation;
      if (animation == null || animation.isCompleted) {
        _canLoadImages = true;
      } else {
        animation.addStatusListener(_onRouteAnimationStatus);
      }

      // Safety fallback: only enable after transition comfortably completes (600ms)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_canLoadImages && mounted) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && !_canLoadImages) {
              setState(() => _canLoadImages = true);
            }
          });
        }
      });
    }
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted && !_canLoadImages) {
        setState(() => _canLoadImages = true);
      }
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: DesktopSafeAppBar(
        child: AppBar(
          title: Text(l10n.genresTitle),
          titleSpacing: 0,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              16,
              isDesktop ? 24 : 16,
              isDesktop ? 40 : 30,
            ),
            cacheExtent: 600,
            gridDelegate: isDesktop
                ? const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    childAspectRatio: 1.65,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  )
                : const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
            itemCount: kAppGenres.length,
            itemBuilder: (context, index) {
              final g = kAppGenres[index];
              final displayName = isSpanish ? g.nameEs : g.nameEn;

              return _GenreCard(
                genre: g,
                displayName: displayName,
                isDesktop: isDesktop,
                canLoadImage: _canLoadImages,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GenreCard extends StatefulWidget {
  final GenreItem genre;
  final String displayName;
  final bool isDesktop;
  final bool canLoadImage;

  const _GenreCard({
    required this.genre,
    required this.displayName,
    required this.isDesktop,
    required this.canLoadImage,
  });

  @override
  State<_GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<_GenreCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  void _triggerTap() {
    Navigator.push(
      context,
      SlideRightToLeftPageRoute(
        child: GenreDetailScreen(
          genre: widget.genre.key,
          displayGenreName: widget.displayName,
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _triggerTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onEnter: (_) {
            if (widget.isDesktop) setState(() => _isHovered = true);
          },
          onExit: (_) {
            if (widget.isDesktop) setState(() => _isHovered = false);
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _triggerTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.genre.gradientColors,
                ),
                border: Border.all(
                  color: _isActive ? Colors.white : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                  width: _isActive ? 2.0 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Image (loads only after route transition settles)
                    if (widget.canLoadImage)
                      CachedNetworkImage(
                        imageUrl: widget.genre.imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.none,
                        memCacheWidth: widget.isDesktop ? 320 : 180,
                        memCacheHeight: widget.isDesktop ? 200 : 120,
                        maxWidthDiskCache: 280,
                        maxHeightDiskCache: 180,
                        fadeInDuration: const Duration(milliseconds: 250),
                        placeholder: (context, url) => const SizedBox.expand(),
                        errorWidget: (context, url, error) => const SizedBox.shrink(),
                      ),

                    // M3 Dark Overlay with gradient
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.40),
                            Colors.black.withValues(alpha: 0.76),
                          ],
                        ),
                      ),
                    ),

                    // Centered Genre Title & Icon
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.genre.icon,
                              size: widget.isDesktop ? 26 : 22,
                              color: Colors.white.withValues(alpha: 0.95),
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: widget.isDesktop ? 17 : 15,
                                letterSpacing: 0.2,
                                shadows: const [
                                  Shadow(blurRadius: 8, color: Colors.black),
                                  Shadow(blurRadius: 4, color: Colors.black87),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
