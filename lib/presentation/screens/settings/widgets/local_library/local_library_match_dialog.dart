import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/local_file_item.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/local_library_provider.dart';

class LocalLibraryMatchDialog extends ConsumerStatefulWidget {
  final UnmatchedFolderGroup group;

  const LocalLibraryMatchDialog({super.key, required this.group});

  static Future<bool?> show(BuildContext context, UnmatchedFolderGroup group) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LocalLibraryMatchDialog(group: group),
    );
  }

  @override
  ConsumerState<LocalLibraryMatchDialog> createState() =>
      _LocalLibraryMatchDialogState();
}

class _LocalLibraryMatchDialogState
    extends ConsumerState<LocalLibraryMatchDialog> {
  final TextEditingController _searchController = TextEditingController();
  bool _isTmdbMode = false;
  List<AnimeEntry> _suggestions = [];
  List<AnimeEntry> _searchResults = [];
  bool _isLoadingSuggestions = true;
  bool _isSearching = false;
  AnimeEntry? _selectedAnime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _isTmdbMode = widget.group.isTmdb;
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoadingSuggestions = true);
    if (_isTmdbMode) {
      final tmdb = ref.read(tmdbServiceProvider);
      final isSpanish = ref.read(appLanguageProvider) == AppLanguage.es;
      final lang = isSpanish ? 'es-ES' : 'en-US';
      try {
        final list = await tmdb.searchShows(
          query: widget.group.guessedTitle,
          language: lang,
        );
        if (mounted) {
          setState(() {
            _suggestions = list;
            _isLoadingSuggestions = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingSuggestions = false);
      }
    } else {
      final repo = ref.read(repositoryProvider);
      try {
        final list = await repo.getAnimeSuggestions(widget.group.folderPath);
        if (mounted) {
          setState(() {
            _suggestions = list;
            _isLoadingSuggestions = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingSuggestions = false);
      }
    }
  }

  Future<void> _onSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      if (_isTmdbMode) {
        final tmdb = ref.read(tmdbServiceProvider);
        final isSpanish = ref.read(appLanguageProvider) == AppLanguage.es;
        final lang = isSpanish ? 'es-ES' : 'en-US';
        final results = await tmdb.searchShows(query: trimmed, language: lang);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } else {
        final repo = ref.read(repositoryProvider);
        final results = await repo.searchAnime(trimmed);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _switchProviderMode(bool tmdb) {
    if (_isTmdbMode == tmdb) return;
    setState(() {
      _isTmdbMode = tmdb;
      _selectedAnime = null;
      _searchResults = [];
    });
    if (_searchController.text.trim().isNotEmpty) {
      _onSearch(_searchController.text);
    } else {
      _loadSuggestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final displayList = _searchController.text.trim().isNotEmpty
        ? _searchResults
        : _suggestions;

    final hasAnyMatched = widget.group.files.any((f) => f.isMatched);

    return Dialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isTmdbMode
                              ? l10n.matchProviderTmdb
                              : l10n.matchWithAnimeAction,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          widget.group.folderName,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Segmented Provider Selector
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(
                      l10n.matchProviderAniList,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    icon: const Icon(Icons.animation_rounded, size: 16),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      l10n.matchProviderTmdb,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    icon: const Icon(Icons.movie_filter_rounded, size: 16),
                  ),
                ],
                selected: {_isTmdbMode},
                onSelectionChanged: (newSelection) =>
                    _switchProviderMode(newSelection.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(height: 12),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: _isTmdbMode
                      ? 'Buscar serie o película en TMDB...'
                      : l10n.searchAnimePrompt,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Subheader
              Text(
                _searchController.text.trim().isNotEmpty
                    ? l10n.optionsCountLabel(displayList.length)
                    : l10n.suggestionsDetected,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              // Candidate List
              Expanded(
                child: _isLoadingSuggestions || _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : displayList.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noEpisodesFound,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: displayList.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final anime = displayList[i];
                          final isSelected = _selectedAnime?.id == anime.id;

                          return InkWell(
                            onTap: () => setState(() => _selectedAnime = anime),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.15,
                                      )
                                    : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Cover Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 44,
                                      height: 60,
                                      child: anime.coverImage != null
                                          ? CachedNetworkImage(
                                              imageUrl: anime.coverImage!,
                                              fit: BoxFit.cover,
                                              errorWidget:
                                                  (
                                                    context,
                                                    url,
                                                    err,
                                                  ) => Container(
                                                    color: theme
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                      Icons.movie_outlined,
                                                      size: 20,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                Icons.movie_outlined,
                                                size: 20,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Titles & info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          anime.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if (anime.format != null)
                                              anime.format,
                                            if (anime.year != null)
                                              '${anime.year}',
                                            if (anime.totalEpisodes != null &&
                                                anime.totalEpisodes! > 0)
                                              '${anime.totalEpisodes} eps',
                                          ].join(' • '),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selected radio check
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 22,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                children: [
                  if (hasAnyMatched)
                    TextButton.icon(
                      icon: const Icon(Icons.link_off_rounded, size: 16),
                      label: Text(l10n.unmatchAction),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              setState(() => _isSubmitting = true);
                              final notifier = ref.read(
                                localLibraryProvider.notifier,
                              );
                              await notifier.unmatchShowGroup(widget.group);
                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.unmatchSuccess),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (_selectedAnime == null || _isSubmitting)
                        ? null
                        : () async {
                            setState(() => _isSubmitting = true);
                            final notifier = ref.read(
                              localLibraryProvider.notifier,
                            );
                            bool ok;
                            if (_isTmdbMode) {
                              final isMovie =
                                  _selectedAnime!.format?.toUpperCase() ==
                                  'MOVIE';
                              ok = await notifier.matchShowGroup(
                                group: widget.group,
                                tmdbId: _selectedAnime!.id,
                                mediaType: isMovie ? 'movie' : 'tv',
                                title: _selectedAnime!.title,
                              );
                            } else {
                              ok = await notifier.manualMatchGroup(
                                widget.group,
                                _selectedAnime!.id,
                              );
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop(ok);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? l10n.matchConfirmedSuccess
                                        : 'Error al emparejar archivos',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isTmdbMode
                                ? 'Vincular TMDB'
                                : l10n.matchWithAnimeAction,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
