import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

/// Everything the preview pane renders, extracted from either media type.
typedef _DetailsDescription = ({
  String title,
  String? subtitle,
  String? cover,
  List<String> meta,
  List<String> genres,
  String synopsis,
});

/// Opens the floating quick search used by the anime and manga feeds.
///
/// A command-palette style overlay: the whole page dims, a translucent glass
/// field and a floating glass results panel sit in the middle of the window.
/// Returns the entry the user picked (an [AnimeEntry] or a [MangaEntry]), or
/// `null` when dismissed.
Future<Object?> showFeedQuickSearch({
  required BuildContext context,
  required bool isManga,
}) {
  return showGeneralDialog<Object>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    // The palette is meant to feel instant (Spotlight-like), so it grows into
    // place from a slightly smaller size instead of fading (glass must never
    // sit under an opacity layer).
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final scale = animation.drive(
        Tween<double>(begin: 0.92, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
      );
      return ScaleTransition(scale: scale, child: child);
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(dialogContext).bottom,
      ),
      child: SafeArea(
        child: Center(
          child: FeedQuickSearch(isManga: isManga),
        ),
      ),
    ),
  );
}

/// The palette itself: a glass search field over a floating glass panel with
/// live results. Right-click or `→` on a result slides the palette left and
/// reveals a preview pane on the right.
class FeedQuickSearch extends ConsumerStatefulWidget {
  final bool isManga;

  const FeedQuickSearch({super.key, required this.isManga});

  @override
  ConsumerState<FeedQuickSearch> createState() => _FeedQuickSearchState();
}

class _FeedQuickSearchState extends ConsumerState<FeedQuickSearch>
    with SingleTickerProviderStateMixin {
  static const Duration _debounceDelay = Duration(milliseconds: 280);
  static const double _tileExtent = 72;
  static const int _maxResults = 8;
  static const double _gap = 16;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// Drives the preview reveal (0 = closed, 1 = fully open).
  late final AnimationController _detailsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );

  Timer? _debounce;
  int _requestId = 0;
  String _query = '';
  List<Object> _results = const [];
  bool _isLoading = false;
  int _selectedIndex = 0;
  bool _navigatingResults = false;

  /// Entry shown in the preview pane. Kept while the pane is closing so its
  /// content can wipe out instead of vanishing.
  Object? _detailsEntry;

  @override
  void dispose() {
    _debounce?.cancel();
    _detailsController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _previewOpen => _detailsEntry != null;

  bool get _caretAtEnd {
    final selection = _controller.selection;
    if (!selection.isValid) return true;
    return selection.isCollapsed &&
        selection.baseOffset >= _controller.text.length;
  }

  void _onChanged(String value) {
    final trimmed = value.trim();
    _debounce?.cancel();
    _navigatingResults = false;

    if (_previewOpen) _closeDetails();

    if (trimmed.isEmpty) {
      _requestId++;
      setState(() {
        _query = '';
        _results = const [];
        _isLoading = false;
        _selectedIndex = 0;
      });
      return;
    }

    setState(() {
      _query = trimmed;
      _isLoading = true;
      _selectedIndex = 0;
    });

    final requestId = ++_requestId;
    _debounce = Timer(_debounceDelay, () => _search(trimmed, requestId));
  }

  Future<void> _search(String query, int requestId) async {
    final repo = ref.read(repositoryProvider);
    List<Object> results = const [];
    try {
      if (widget.isManga) {
        results = await repo.searchManga(query, perPage: _maxResults);
      } else {
        final animeEnabled = ref.read(animeSectionEnabledProvider);
        final isLoggedIn =
            ref.read(serverNotifierProvider).status?.isLoggedIn ?? false;
        if (animeEnabled && isLoggedIn) {
          results = await repo.searchAnime(query, perPage: _maxResults);
        }
        // Without AniList (disabled or not signed in) quick search falls back
        // to TMDB, which also covers anime as TV shows.
        if (results.isEmpty) {
          final isSpanish =
              ref.read(appLanguageProvider) == AppLanguage.es;
          results = await ref.read(tmdbServiceProvider).searchShows(
                query: query,
                language: isSpanish ? 'es-ES' : 'en-US',
              );
        }
      }
    } catch (_) {
      results = const [];
    }

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _results = results;
      _isLoading = false;
      _selectedIndex = 0;
    });
    // A new result set belongs to a new query: drop a preview opened while
    // this search was still in flight.
    if (_previewOpen) _closeDetails();
  }

  void _moveSelection(int delta) {
    if (_results.isEmpty) return;
    final count = _results.length;
    setState(() {
      _selectedIndex = (_selectedIndex + delta) % count;
      if (_selectedIndex < 0) _selectedIndex += count;
      _navigatingResults = true;
      if (_previewOpen) _detailsEntry = _results[_selectedIndex];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
  }

  void _revealSelection() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final top = _selectedIndex * _tileExtent;
    final bottom = top + _tileExtent;
    if (top < position.pixels) {
      _scrollController.animateTo(
        top,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
    } else if (bottom > position.pixels + position.viewportDimension) {
      _scrollController.animateTo(
        bottom - position.viewportDimension,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
    }
  }

  void _openSelected() {
    if (_results.isEmpty) return;
    final index = _selectedIndex.clamp(0, _results.length - 1);
    Navigator.of(context).pop(_results[index]);
  }

  void _openDetails(Object entry) {
    setState(() => _detailsEntry = entry);
    // Restarts the reveal if it was closing, and is a no-op once fully open.
    _detailsController.forward();
  }

  void _openDetailsForSelection() {
    if (_results.isEmpty) return;
    _openDetails(_results[_selectedIndex.clamp(0, _results.length - 1)]);
  }

  void _closeDetails() {
    if (_detailsEntry == null) return;
    if (!_detailsController.isAnimating && _detailsController.value == 0) {
      setState(() => _detailsEntry = null);
      return;
    }
    final closing = _detailsEntry;
    _detailsController.reverse().whenComplete(() {
      if (!mounted || !identical(_detailsEntry, closing)) return;
      setState(() => _detailsEntry = null);
    });
  }

  void _clearQuery() {
    _controller.clear();
    _onChanged('');
    _focusNode.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (!_previewOpen &&
          _results.isNotEmpty &&
          (_navigatingResults || _caretAtEnd)) {
        _openDetailsForSelection();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_previewOpen) {
        _closeDetails();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_previewOpen) {
        _closeDetails();
      } else {
        Navigator.of(context).maybePop();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Title, poster and one metadata line for a result of either media type.
  ({String title, String? cover, String meta}) _describe(
    Object item,
    TitleLanguage titleLanguage,
    AppTranslations l10n,
  ) {
    if (item is AnimeEntry) {
      final meta = <String>[
        if ((item.format ?? '').trim().isNotEmpty) item.format!.trim(),
        if (item.year != null) '${item.year}',
        if (item.totalEpisodes != null && item.totalEpisodes! > 0)
          '${item.totalEpisodes} ${l10n.episodes}',
      ];
      return (
        title: item.displayTitle(titleLanguage),
        cover: item.coverImage,
        meta: meta.join(' · '),
      );
    }

    final manga = item as MangaEntry;
    final meta = <String>[
      if ((manga.format ?? '').trim().isNotEmpty) manga.format!.trim(),
      if (manga.year != null) '${manga.year}',
      if (manga.totalChapters != null && manga.totalChapters! > 0)
        '${manga.totalChapters} ${l10n.chapters}',
    ];
    return (
      title: manga.displayTitle(titleLanguage),
      cover: manga.coverImage ?? manga.localCoverPath,
      meta: meta.join(' · '),
    );
  }

  /// Everything the preview pane needs, for either media type.
  ({
    String title,
    String? subtitle,
    String? cover,
    List<String> meta,
    List<String> genres,
    String synopsis,
  })
  _describeDetails(
    Object item,
    TitleLanguage titleLanguage,
    AppTranslations l10n,
  ) {
    if (item is AnimeEntry) {
      final title = item.displayTitle(titleLanguage);
      final score = _scoreLabel(item.score);
      return (
        title: title,
        subtitle: _secondaryTitle(title, item.englishTitle, item.romajiTitle),
        cover: item.coverImage,
        meta: [
          if ((item.format ?? '').trim().isNotEmpty) item.format!.trim(),
          if (item.year != null) '${item.year}',
          if (item.totalEpisodes != null && item.totalEpisodes! > 0)
            '${item.totalEpisodes} ${l10n.episodes}',
          ?score,
        ],
        genres: item.genres.take(4).toList(),
        synopsis: _cleanDescription(item.description),
      );
    }

    final manga = item as MangaEntry;
    final title = manga.displayTitle(titleLanguage);
    final score = _scoreLabel(manga.score);
    return (
      title: title,
      subtitle: _secondaryTitle(title, manga.englishTitle, manga.romajiTitle),
      cover: manga.coverImage ?? manga.localCoverPath,
      meta: [
        if ((manga.format ?? '').trim().isNotEmpty) manga.format!.trim(),
        if (manga.year != null) '${manga.year}',
        if (manga.totalChapters != null && manga.totalChapters! > 0)
          '${manga.totalChapters} ${l10n.chapters}',
        if (manga.totalVolumes != null && manga.totalVolumes! > 0)
          '${manga.totalVolumes} ${l10n.volumes}',
        ?score,
      ],
      genres: manga.genres.take(4).toList(),
      synopsis: _cleanDescription(manga.description),
    );
  }

  static String? _secondaryTitle(
    String title,
    String? english,
    String? romaji,
  ) {
    final candidates = [english, romaji];
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null &&
          trimmed.isNotEmpty &&
          trimmed.toLowerCase() != title.trim().toLowerCase()) {
        return trimmed;
      }
    }
    return null;
  }

  static String? _scoreLabel(double? score) {
    if (score == null || score <= 0) return null;
    final normalized = score > 10 ? score / 10 : score;
    return '★ ${normalized.toStringAsFixed(1)}';
  }

  static String _cleanDescription(String? text) {
    if (text == null) return '';
    return text
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final titleLanguage = ref.watch(titleLanguageProvider);
    final screen = MediaQuery.sizeOf(context);
    final panelMaxHeight = math.min(screen.height * 0.55, 420.0);
    final detailsHeight = math.min(screen.height * 0.58, 440.0);
    final detailsEntry = _detailsEntry;

    final searchColumn = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTextField.search(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            placeholder: widget.isManga
                ? l10n.quickSearchMangaHint
                : l10n.quickSearchHint,
            onChanged: _onChanged,
            onSubmitted: (_) => _openSelected(),
            trailing: _query.isEmpty
                ? null
                : Semantics(
                    button: true,
                    label: l10n.close,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _clearQuery,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, size: 16),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(28),
            // Results grow and shrink with the query, so the panel eases
            // between heights instead of snapping to each new size.
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              reverseDuration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // The preview pane matches this column's height, so keep
                  // enough room for both while it is open.
                  minHeight: _previewOpen
                      ? math.max(0, detailsHeight - kGlassFieldHeight - 12)
                      : 0,
                ),
                child: _buildPanel(
                  l10n: l10n,
                  iconPack: iconPack,
                  titleLanguage: titleLanguage,
                  panelMaxHeight: panelMaxHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final detailsPanel = detailsEntry == null
        ? null
        : _QuickSearchDetails(
            description: _describeDetails(
              detailsEntry,
              titleLanguage,
              l10n,
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final detailsWidth = (available * 0.34).clamp(260.0, 400.0);

          return Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onKeyEvent,
            child: GlassAbove(
              lift: kGlassModalLift,
              child: AnimatedBuilder(
                animation: _detailsController,
                // The search column is passed as a child so typing, scrolling
                // and result updates are not rebuilt on every animation frame.
                child: searchColumn,
                builder: (context, child) {
                  final t = Curves.easeOutCubic.transform(
                    _detailsController.value,
                  );
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(child: child!),
                      if (detailsPanel != null) ...[
                        SizedBox(width: _gap * t),
                        ClipRect(
                          child: SizedBox(
                            width: detailsWidth * t,
                            height: detailsHeight * t,
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: detailsWidth,
                              maxWidth: detailsWidth,
                              minHeight: detailsHeight,
                              maxHeight: detailsHeight,
                              child: detailsPanel,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanel({
    required AppTranslations l10n,
    required AppIconPack iconPack,
    required TitleLanguage titleLanguage,
    required double panelMaxHeight,
  }) {
    if (_query.isEmpty) {
      return _QuickSearchMessage(
        icon: AppIcons.search(iconPack),
        title: widget.isManga
            ? l10n.quickSearchMangaPrompt
            : l10n.quickSearchPrompt,
        hint: l10n.quickSearchKeyboardHint,
      );
    }

    if (_isLoading && _results.isEmpty) {
      return const _QuickSearchMessage(loading: true);
    }

    if (_results.isEmpty) {
      return _QuickSearchMessage(
        icon: AppIcons.searchOff(iconPack),
        title: '${l10n.noResultsFor} "$_query"',
        hint: l10n.quickSearchKeyboardHint,
      );
    }

    final height = math.min(
      _results.length * _tileExtent + 8,
      panelMaxHeight,
    );

    return SizedBox(
      height: height,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemExtent: _tileExtent,
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final description = _describe(
            _results[index],
            titleLanguage,
            l10n,
          );
          return _QuickSearchTile(
            title: description.title,
            coverUrl: description.cover,
            meta: description.meta,
            selected: index == _selectedIndex,
            onTap: () => Navigator.of(context).pop(_results[index]),
            onSecondaryTap: () {
              setState(() => _selectedIndex = index);
              _openDetails(_results[index]);
            },
          );
        },
      ),
    );
  }
}

/// Centred prompt / empty / loading state inside the results panel.
class _QuickSearchMessage extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final String? hint;
  final bool loading;

  const _QuickSearchMessage({
    this.icon,
    this.title,
    this.hint,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;
    return SizedBox(
      height: 132,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else if (icon != null)
                Icon(
                  icon,
                  size: 26,
                  color: baseStyle.color?.withValues(alpha: 0.7),
                ),
              if (title != null) ...[
                const SizedBox(height: 12),
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: baseStyle.color?.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One floating result row: poster, title, metadata and the keyboard hint on
/// the selected row.
class _QuickSearchTile extends StatefulWidget {
  final String title;
  final String? coverUrl;
  final String meta;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  const _QuickSearchTile({
    required this.title,
    required this.coverUrl,
    required this.meta,
    required this.selected,
    required this.onTap,
    this.onSecondaryTap,
  });

  @override
  State<_QuickSearchTile> createState() => _QuickSearchTileState();
}

class _QuickSearchTileState extends State<_QuickSearchTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final highlighted = widget.selected || _hovered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          onSecondaryTap: widget.onSecondaryTap,
          onHover: (hovering) => setState(() => _hovered = hovering),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: highlighted
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                _CoverThumb(url: widget.coverUrl, width: 38, height: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: baseStyle.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      if (widget.meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: baseStyle.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: baseStyle.color?.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.selected)
                  Icon(
                    Icons.keyboard_return_rounded,
                    size: 16,
                    color: baseStyle.color?.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Preview pane revealed to the right of the palette.
class _QuickSearchDetails extends StatelessWidget {
  final _DetailsDescription description;

  const _QuickSearchDetails({required this.description});

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(28),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverThumb(
                  url: description.cover,
                  width: 96,
                  height: 136,
                  radius: 14,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: baseStyle.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      if (description.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: baseStyle.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: baseStyle.color?.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                      if (description.meta.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final entry in description.meta)
                              _DetailChip(label: entry),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (description.genres.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final genre in description.genres)
                    _DetailChip(
                      label: genre,
                      accent: true,
                    ),
                ],
              ),
            ],
            if (description.synopsis.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                description.synopsis,
                style: baseStyle.copyWith(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: baseStyle.color?.withValues(alpha: 0.86),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_left_rounded,
                  size: 13,
                  color: baseStyle.color?.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context).backButtonTooltip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: baseStyle.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: baseStyle.color?.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small metadata capsule used by the preview pane.
class _DetailChip extends StatelessWidget {
  final String label;
  final bool accent;

  const _DetailChip({required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = DefaultTextStyle.of(context).style;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : (baseStyle.color ?? theme.colorScheme.onSurface).withValues(
                alpha: 0.08,
              ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: accent ? theme.colorScheme.primary : null,
        ),
      ),
    );
  }
}

/// Rounded poster used by both the result rows and the preview pane.
class _CoverThumb extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final double radius;

  const _CoverThumb({
    required this.url,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: (width * 2.4).round(),
                filterQuality: FilterQuality.medium,
                errorWidget: (_, _, _) => _placeholder(theme),
              )
            : _placeholder(theme),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Icon(
        Icons.image_outlined,
        size: math.max(14, width * 0.35),
        color: theme.colorScheme.outline,
      ),
    );
  }
}
