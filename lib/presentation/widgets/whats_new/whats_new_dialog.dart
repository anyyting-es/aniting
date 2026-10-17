import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seanime_app/data/models/whats_new_data.dart';

class WhatsNewDialog extends StatelessWidget {
  final VoidCallback? onDismiss;

  const WhatsNewDialog({
    super.key,
    this.onDismiss,
  });

  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop) {
      return showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const WhatsNewDialog(),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: WhatsNewDialog(),
        ),
      );
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF13151B) : theme.colorScheme.surface)
              .withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Badge + Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      LucideIcons.sparkles,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "What's New",
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'v${WhatsNewData.version}',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Discover what's new in Aniting",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // News List (Unified Single Container)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < WhatsNewData.news.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    WhatsNewData.news[i].icon,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    WhatsNewData.news[i].title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i < WhatsNewData.news.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.2),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Socials (Solo iconos: Discord y GitHub)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Community:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Discord Button
                  IconButton.filledTonal(
                    onPressed: () => _launchUrl(WhatsNewData.discordUrl),
                    tooltip: 'Discord',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(10),
                      backgroundColor: const Color(0xFF5865F2).withValues(alpha: 0.18),
                    ),
                    icon: Image.asset(
                      'assets/icons/discord_icon.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      color: const Color(0xFF5865F2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // GitHub Button
                  IconButton.filledTonal(
                    onPressed: () => _launchUrl(WhatsNewData.githubUrl),
                    tooltip: 'GitHub',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(10),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                    ),
                    icon: const Icon(LucideIcons.code, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Button Continue / Dismiss
              M3EButton(
                onPressed: () {
                  if (onDismiss != null) {
                    onDismiss!();
                  } else {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },
                child: const Text(
                  'Got it!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
