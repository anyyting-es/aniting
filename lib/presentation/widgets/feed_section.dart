import 'package:flutter/material.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';

class FeedSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<AnimeEntry> entries;
  final bool isLoading;

  const FeedSection({
    super.key,
    required this.title,
    this.icon,
    required this.entries,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: entries.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = entries[index];
                    return SizedBox(
                      width: 130,
                      child: AnimeCard(
                        entry: item,
                        onTap: () {
                          AnimeDetailScreen.navigate(
                            context,
                            mediaId: item.mediaId,
                            initialEntry: item,
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
