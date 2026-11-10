import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/data/models/manga_entry.dart';
import 'package:aniting/presentation/providers/app_providers.dart';

class MangaManualMatchDialog extends ConsumerStatefulWidget {
  final int mediaId;
  final String initialTitle;
  final MangaProvider provider;
  final VoidCallback onMatched;

  const MangaManualMatchDialog({
    super.key,
    required this.mediaId,
    required this.initialTitle,
    required this.provider,
    required this.onMatched,
  });

  static Future<void> show(
    BuildContext context, {
    required int mediaId,
    required String initialTitle,
    required MangaProvider provider,
    required VoidCallback onMatched,
  }) {
    return showDialog(
      context: context,
      builder: (_) => MangaManualMatchDialog(
        mediaId: mediaId,
        initialTitle: initialTitle,
        provider: provider,
        onMatched: onMatched,
      ),
    );
  }

  @override
  ConsumerState<MangaManualMatchDialog> createState() => _MangaManualMatchDialogState();
}

class _MangaManualMatchDialogState extends ConsumerState<MangaManualMatchDialog> {
  late final TextEditingController _queryController = TextEditingController(text: widget.initialTitle);
  bool _isSearching = false;
  bool _isMapping = false;
  List<Map<String, dynamic>> _results = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final res = await repo.manualSearchManga(
        provider: widget.provider.id,
        query: q,
      );
      if (mounted) {
        setState(() {
          _results = res;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectMatch(String mangaId) async {
    setState(() => _isMapping = true);
    try {
      final repo = ref.read(repositoryProvider);
      final success = await repo.manualMapManga(
        provider: widget.provider.id,
        mediaId: widget.mediaId,
        mangaId: mangaId,
      );
      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          widget.onMatched();
        } else {
          setState(() {
            _isMapping = false;
            _error = 'Failed to map manga';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMapping = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: GlassCard(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.search_rounded, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${l10n.manualMatch} • ${widget.provider.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Input
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _queryController,
                        onSubmitted: (_) => _performSearch(),
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: '${l10n.search}...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSearching ? null : _performSearch,
                    icon: _isSearching
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded, size: 18),
                    label: Text(l10n.search),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Content / Results
              Expanded(
                child: _isMapping
                    ? const Center(child: CircularProgressIndicator())
                    : _isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(
                                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                              )
                            : _results.isEmpty
                                ? Center(
                                    child: Text(
                                      l10n.noResultsFound,
                                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _results.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = _results[index];
                                      final id = item['id']?.toString() ?? '';
                                      final title = item['title']?.toString() ?? id;
                                      final url = item['url']?.toString();

                                      return InkWell(
                                        onTap: () => _selectMatch(id),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.04)
                                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.08)
                                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      title,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (url != null && url.isNotEmpty) ...[
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        url,
                                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(Icons.link_rounded, color: theme.colorScheme.primary, size: 20),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
