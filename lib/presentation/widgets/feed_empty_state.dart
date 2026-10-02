import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/anilist_auth_sheet.dart';

/// Clean, minimalist Material Design 3 empty state displayed when
/// the user is not logged in or has no items in their anime/manga library.
/// Placed near the top with a compact illustration and sleek action buttons.
class FeedEmptyState extends ConsumerWidget {
  final bool isLoggedIn;
  final bool isManga;
  final bool isOffline;
  final VoidCallback? onRetry;
  final VoidCallback? onExplore;
  final VoidCallback? onLogin;
  final AppIconPack iconPack;

  const FeedEmptyState({
    super.key,
    required this.isLoggedIn,
    this.isManga = false,
    this.isOffline = false,
    this.onRetry,
    this.onExplore,
    this.onLogin,
    this.iconPack = AppIconPack.lucide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;

    final title = isOffline
        ? (isSpanish ? 'Sin conexión a internet' : 'No internet connection')
        : (!isLoggedIn
            ? (isManga
                ? (isSpanish ? 'Comienza a leer' : 'Start reading')
                : (isSpanish ? 'Comienza a explorar' : 'Start exploring'))
            : (isManga ? l10n.emptyMangaFeedTitle : l10n.emptyAnimeFeedTitle));

    final description = isOffline
        ? (isSpanish
            ? 'No pudimos conectar con los servidores. Revisa tu conexión a internet.'
            : 'Could not connect to the servers. Please check your internet connection.')
        : (!isLoggedIn
            ? (isSpanish
                ? (isManga
                    ? 'Explora el catálogo o lee cualquier capítulo para armar tu feed automáticamente, o conecta tu cuenta de AniList si deseas sincronizar tus listas.'
                    : 'Explora el catálogo o reproduce cualquier serie para armar tu feed automáticamente, o conecta tu cuenta de AniList si deseas sincronizar tus listas.')
                : (isManga
                    ? 'Explore the catalog or read any chapter to build your feed automatically, or connect AniList to sync your lists.'
                    : 'Explore the catalog or play any episode to build your feed automatically, or connect AniList to sync your lists.'))
            : (isManga
                ? l10n.emptyMangaFeedDesc
                : l10n.emptyAnimeFeedDesc));

    final mainIcon = isOffline
        ? Icons.wifi_off_rounded
        : (!isLoggedIn
            ? Icons.account_circle_outlined
            : (isManga ? Icons.auto_stories_outlined : Icons.live_tv_rounded));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Compact confused anime character illustration
              Image.asset(
                'assets/images/confused.png',
                height: 85,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      mainIcon,
                      size: 26,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 2. Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),

              // 3. Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // 4. Minimalist Action Buttons
              if (isOffline) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (onRetry != null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onRetry!();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          l10n.retry,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    if (onExplore != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onExplore?.call();
                        },
                        icon: const Icon(Icons.explore_outlined, size: 16),
                        label: Text(
                          isSpanish ? 'Explorar' : 'Explore',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ] else if (!isLoggedIn) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (onExplore != null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onExplore?.call();
                        },
                        icon: const Icon(Icons.explore_outlined, size: 16),
                        label: Text(
                          isSpanish ? 'Explorar' : 'Explore',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (onLogin != null) {
                          onLogin!();
                        } else {
                          AnilistAuthSheet.show(context);
                        }
                      },
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: Text(
                        isSpanish ? 'Conectar con AniList' : 'Connect AniList',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ] else if (onExplore != null) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onExplore?.call();
                  },
                  icon: const Icon(Icons.explore_rounded, size: 16),
                  label: Text(
                    l10n.navExplore,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
