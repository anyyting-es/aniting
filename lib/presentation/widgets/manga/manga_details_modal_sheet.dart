import 'package:flutter/material.dart';

/// Modal bottom sheet displaying detailed synopsis and genres for a manga entry.
class MangaDetailsModalSheet extends StatelessWidget {
  final String? description;
  final List<String> genres;

  const MangaDetailsModalSheet({
    super.key,
    this.description,
    this.genres = const [],
  });

  static Future<void> show(
    BuildContext context, {
    String? description,
    List<String> genres = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => MangaDetailsModalSheet(
        description: description,
        genres: genres,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanDesc = description?.replaceAll(RegExp(r'<[^>]*>'), '') ??
        'No hay descripción disponible.';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sinopsis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                cleanDesc,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              if (genres.isNotEmpty) ...[
                const Text(
                  'Géneros',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: genres.map((g) {
                    return Chip(
                      label: Text(g, style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
