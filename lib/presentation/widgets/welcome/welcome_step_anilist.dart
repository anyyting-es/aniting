import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/app_providers.dart';
import '../anilist_auth_sheet.dart';

class WelcomeStepAniList extends ConsumerWidget {
  final VoidCallback onFinish;

  const WelcomeStepAniList({
    super.key,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverNotifierProvider);
    final status = serverState.status;
    final isLoggedIn = status?.isLoggedIn == true;
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final colors = context.themeColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF02A9FF).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.account_circle_rounded, size: 46, color: Color(0xFF02A9FF)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sincronización con AniList',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.welcomeAnilistPrompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          if (isLoggedIn) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                    backgroundImage: status?.avatarUrl != null ? NetworkImage(status!.avatarUrl!) : null,
                    child: status?.avatarUrl == null
                        ? const Icon(Icons.person, color: Colors.green)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status?.username ?? 'Usuario AniList',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          l10n.welcomeAnilistConnected,
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(l10n.welcomeFinish),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sync_rounded, color: Color(0xFF02A9FF)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sincroniza animes, mangas, episodios y puntuaciones en tiempo real.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => AnilistAuthSheet.show(context),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: Text(l10n.anilistLoginTitle),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFF02A9FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onFinish,
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(l10n.welcomeFinish),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onFinish,
              child: Text(
                l10n.welcomeAnilistSkip,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
