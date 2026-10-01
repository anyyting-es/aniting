import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';

class GenreDetailScreen extends ConsumerStatefulWidget {
  final String genre;
  final String? displayGenreName;

  const GenreDetailScreen({
    super.key,
    required this.genre,
    this.displayGenreName,
  });

  @override
  ConsumerState<GenreDetailScreen> createState() => _GenreDetailScreenState();
}

class _GenreDetailScreenState extends ConsumerState<GenreDetailScreen> {
  final ScrollController _scrollController = SmoothScrollController();
  String _mediaType = 'ANIME'; // 'ANIME' or 'MANGA'
  String _sort = 'TRENDING_DESC'; // TRENDING_DESC, SCORE_DESC, POPULARITY_DESC, START_DATE_DESC
  int? _selectedYear;

  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  final List<AnimeEntry> _animeList = [];
  final List<MangaEntry> _mangaList = [];

  @override
  void initState() {
    super.initState();
    _fetchData(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400 &&
        !_isLoading &&
        _hasMore) {
      _fetchData(reset: false);
    }
  }

  Future<void> _fetchData({bool reset = false}) async {
    if (_isLoading) return;

    final serverState = ref.read(serverNotifierProvider);
    if (!serverState.isOnline) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _animeList.clear();
        _mangaList.clear();
        _isLoading = true;
      });
    } else {
      setState(() => _isLoading = true);
    }

    final repo = ref.read(repositoryProvider);
    final pageToFetch = reset ? 1 : _currentPage;

    if (_mediaType == 'ANIME') {
      final results = await repo.getAnimeByGenre(
        genre: widget.genre,
        sort: _sort,
        year: _selectedYear,
        page: pageToFetch,
        perPage: 24,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentPage = pageToFetch + 1;
          if (results.isEmpty) {
            _hasMore = false;
          } else {
            _animeList.addAll(results);
            if (results.length < 24) _hasMore = false;
          }
        });
      }
    } else {
      final results = await repo.getMangaByGenre(
        genre: widget.genre,
        sort: _sort,
        year: _selectedYear,
        page: pageToFetch,
        perPage: 24,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentPage = pageToFetch + 1;
          if (results.isEmpty) {
            _hasMore = false;
          } else {
            _mangaList.addAll(results);
            if (results.length < 24) _hasMore = false;
          }
        });
      }
    }
  }

  void _showYearFilterDialog() {
    final currentYear = DateTime.now().year;
    final years = List.generate(35, (i) => currentYear - i);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  ref.read(translationsProvider).filterByYear,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                title: Text(ref.read(translationsProvider).allYears),
                trailing: _selectedYear == null ? const Icon(Icons.check_rounded, color: Colors.green) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedYear = null);
                  _fetchData(reset: true);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: years.length,
                  itemBuilder: (c, i) {
                    final yr = years[i];
                    final isSelected = yr == _selectedYear;
                    return ListTile(
                      title: Text(yr.toString()),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: Colors.green) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedYear = yr);
                        _fetchData(reset: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final title = widget.displayGenreName ?? widget.genre;
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    final sortOptions = [
      {'key': 'TRENDING_DESC', 'label': l10n.sortTrending, 'icon': Icons.local_fire_department_rounded},
      {'key': 'SCORE_DESC', 'label': l10n.sortScore, 'icon': Icons.star_rounded},
      {'key': 'POPULARITY_DESC', 'label': l10n.sortPopularity, 'icon': Icons.favorite_rounded},
      {'key': 'START_DATE_DESC', 'label': l10n.sortStartDate, 'icon': Icons.calendar_today_rounded},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: Icon(
              _selectedYear != null ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              color: _selectedYear != null ? theme.colorScheme.primary : null,
            ),
            tooltip: l10n.filterByYear,
            onPressed: _showYearFilterDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Media Type Toggle (Anime / Manga) & Active Year Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'ANIME',
                      label: Text(l10n.anime),
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'MANGA',
                      label: Text(l10n.manga),
                      icon: const Icon(Icons.menu_book_rounded, size: 16),
                    ),
                  ],
                  selected: {_mediaType},
                  onSelectionChanged: (newSet) {
                    setState(() => _mediaType = newSet.first);
                    _fetchData(reset: true);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                if (_selectedYear != null)
                  Chip(
                    label: Text(_selectedYear.toString(), style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () {
                      setState(() => _selectedYear = null);
                      _fetchData(reset: true);
                    },
                  ),
              ],
            ),
          ),

          // Sorter Chips Bar
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: sortOptions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final opt = sortOptions[i];
                final isSelected = opt['key'] == _sort;
                return ChoiceChip(
                  avatar: Icon(
                    opt['icon'] as IconData,
                    size: 14,
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(opt['label'] as String),
                  selected: isSelected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) {
                    if (selected && _sort != opt['key']) {
                      setState(() => _sort = opt['key'] as String);
                      _fetchData(reset: true);
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 6),
          const Divider(height: 1),

          // Results Grid
          Expanded(
            child: _isLoading && (_animeList.isEmpty && _mangaList.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : (_mediaType == 'ANIME' ? _animeList.isEmpty : _mangaList.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.movie_filter_rounded, size: 52, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noResultsFound,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchData(reset: true),
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isDesktop ? 210 : 135,
                            childAspectRatio: isDesktop ? 0.58 : 0.52,
                            crossAxisSpacing: isDesktop ? 10 : 8,
                            mainAxisSpacing: isDesktop ? 14 : 12,
                          ),
                          itemCount: (_mediaType == 'ANIME' ? _animeList.length : _mangaList.length) +
                              (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            final totalItems = _mediaType == 'ANIME' ? _animeList.length : _mangaList.length;

                            if (index >= totalItems) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                              );
                            }

                            if (_mediaType == 'ANIME') {
                              final item = _animeList[index];
                              return AnimeCard(
                                entry: item,
                                onTap: () {
                                  AnimeDetailScreen.navigate(
                                    context,
                                    mediaId: item.mediaId,
                                    initialEntry: item,
                                  );
                                },
                              );
                            } else {
                              final item = _mangaList[index];
                              return MangaCard(
                                entry: item,
                                onTap: () {
                                  MangaDetailScreen.navigate(
                                    context,
                                    mediaId: item.mediaId,
                                    initialEntry: item,
                                  );
                                },
                              );
                            }
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
