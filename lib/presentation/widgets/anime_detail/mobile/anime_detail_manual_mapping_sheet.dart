import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

/// Full glass modal sheet for searching and linking an anime to an online streaming provider.
class AnimeDetailManualMappingSheet extends ConsumerStatefulWidget {
  final OnlinestreamProvider provider;
  final int mediaId;
  final AnimeDetails? animeDetails;
  final bool isDubbed;
  final String? currentMappedAnimeId;
  final VoidCallback onMappingSuccess;

  const AnimeDetailManualMappingSheet({
    super.key,
    required this.provider,
    required this.mediaId,
    this.animeDetails,
    required this.isDubbed,
    this.currentMappedAnimeId,
    required this.onMappingSuccess,
  });

  @override
  ConsumerState<AnimeDetailManualMappingSheet> createState() => _AnimeDetailManualMappingSheetState();
}

class _AnimeDetailManualMappingSheetState extends ConsumerState<AnimeDetailManualMappingSheet> {
  late final TextEditingController _textController;
  bool _isSearching = false;
  List<OnlinestreamSearchResult> _searchResults = [];
  String? _searchError;
  bool _hasSearched = false;
  String? _currentMappedId;

  @override
  void initState() {
    super.initState();
    _currentMappedId = widget.currentMappedAnimeId;
    final defaultQuery = widget.animeDetails?.romajiTitle ??
        widget.animeDetails?.englishTitle ??
        widget.animeDetails?.title ??
        '';
    _textController = TextEditingController(text: defaultQuery);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _doSearch([String? customQuery]) async {
    final query = (customQuery ?? _textController.text).trim();
    if (query.isEmpty) return;
    if (customQuery != null) {
      _textController.text = customQuery;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _hasSearched = true;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final l10n = ref.read(translationsProvider);
      final results = await repo.searchOnlinestreamManual(
        provider: widget.provider.id,
        query: query,
        dubbed: widget.isDubbed,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          if (results.isEmpty) {
            _searchError = l10n.noAnimeFoundInProvider(widget.provider.name, query);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = ref.read(translationsProvider);
        setState(() {
          _searchError = '${l10n.error}: $e';
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _linkAnime(OnlinestreamSearchResult res) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(repositoryProvider);
    final l10n = ref.read(translationsProvider);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await repo.setOnlinestreamManualMapping(
      provider: widget.provider.id,
      mediaId: widget.mediaId,
      animeId: res.id,
    );

    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${l10n.animeLinkedSuccess} "${res.title}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onMappingSuccess();
      }
    }
  }

  Future<void> _unlinkAnime() async {
    HapticFeedback.lightImpact();
    final repo = ref.read(repositoryProvider);
    final l10n = ref.read(translationsProvider);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await repo.removeOnlinestreamMapping(
      provider: widget.provider.id,
      mediaId: widget.mediaId,
    );

    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.linkRemoved),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onMappingSuccess();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : theme.colorScheme.primary;
    final secondaryTextColor = isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.70;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 6,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Icon(AppIcons.link(iconPack), size: 22, color: primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.linkWith} ${widget.provider.name}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.searchAndSelectInProvider,
                          style: TextStyle(fontSize: 11.5, color: secondaryTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ClipOval(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(AppIcons.close(iconPack), size: 20, color: secondaryTextColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Existing Mapping Active Badge
              if (_currentMappedId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.checkCircleFilled(iconPack), size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.linkedTo} $_currentMappedId',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _unlinkAnime,
                        icon: Icon(AppIcons.linkOff(iconPack), size: 14),
                        label: Text(l10n.unlink, style: const TextStyle(fontSize: 11.5)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: isDark ? Colors.white70 : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Search Row with GlassTextField & GlassButton
              Row(
                children: [
                  Expanded(
                    child: GlassTextField.search(
                      controller: _textController,
                      placeholder: l10n.searchAnimePlaceholder,
                      onSubmitted: (_) => _doSearch(),
                      autofocus: _currentMappedId == null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    onPressed: _isSearching ? null : () => _doSearch(),
                    child: _isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.search(iconPack), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                l10n.search,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Title Suggestion Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    if (widget.animeDetails?.romajiTitle != null)
                      _buildSuggestionChip(
                        theme,
                        widget.animeDetails!.romajiTitle!,
                        () => _doSearch(widget.animeDetails!.romajiTitle),
                      ),
                    if (widget.animeDetails?.englishTitle != null)
                      _buildSuggestionChip(
                        theme,
                        widget.animeDetails!.englishTitle!,
                        () => _doSearch(widget.animeDetails!.englishTitle),
                      ),
                    if (widget.animeDetails?.aniZipData?.titles['es'] != null)
                      _buildSuggestionChip(
                        theme,
                        'ES: ${widget.animeDetails!.aniZipData!.titles['es']}',
                        () => _doSearch(widget.animeDetails!.aniZipData!.titles['es']),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Results View
              Expanded(
                child: _isSearching
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              l10n.searchingProviderCatalog,
                              style: TextStyle(fontSize: 12, color: secondaryTextColor),
                            ),
                          ],
                        ),
                      )
                    : _searchError != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _searchError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: secondaryTextColor),
                              ),
                            ),
                          )
                        : !_hasSearched
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.search(iconPack), size: 36, color: secondaryTextColor.withValues(alpha: 0.5)),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.searchPromptMapping,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final res = _searchResults[i];
                                  final isCurrentlySelected = _currentMappedId == res.id;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isCurrentlySelected
                                          ? (isDark
                                              ? Colors.white.withValues(alpha: 0.12)
                                              : theme.colorScheme.primaryContainer.withValues(alpha: 0.4))
                                          : (isDark
                                              ? Colors.white.withValues(alpha: 0.05)
                                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isCurrentlySelected
                                            ? primaryColor
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.1)
                                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                res.title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'ID: ${res.id}',
                                                style: TextStyle(fontSize: 11, color: secondaryTextColor),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GlassButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                          onPressed: () => _linkAnime(res),
                                          child: Text(
                                            isCurrentlySelected ? l10n.linked : l10n.link,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isCurrentlySelected ? primaryColor : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSuggestionChip(ThemeData theme, String text, VoidCallback onTap) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
