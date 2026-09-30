import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/onboarding_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/welcome_screen.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';
import 'package:seanime_app/data/services/app_update_service.dart';
import 'package:seanime_app/presentation/providers/app_update_provider.dart';
import 'package:seanime_app/presentation/widgets/update/app_update_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA: ACERCA DE LA APLICACIÓN (INFORMACIÓN Y CRÉDITOS)
// ─────────────────────────────────────────────────────────────────────────────
class AboutSettingsScreen extends ConsumerWidget {
  final bool isEmbedded;
  const AboutSettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final serverState = ref.watch(serverNotifierProvider);
    final status = serverState.status;
    final updateState = ref.watch(appUpdateNotifierProvider);

    return PixelSubpageScaffold(
      title: l10n.aboutApp,
      isEmbedded: isEmbedded,
      children: [
        // ─── HERO CARD DE LA APP ──────────────────────────────
        PixelCardContainer(
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/icons/logo.png',
                    width: 76,
                    height: 76,
                    cacheWidth: 152,
                    cacheHeight: 152,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aniting',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cliente nativo para Anime y Manga',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Versión 1.0.0 (Flutter)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── DESARROLLADOR & CRÉDITOS ─────────────────────────
        const SettingsSectionHeader(title: 'DESARROLLADOR & CRÉDITOS'),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/icons/logo.png',
                  width: 44,
                  height: 44,
                  cacheWidth: 88,
                  cacheHeight: 88,
                  fit: BoxFit.contain,
                ),
              ),
              title: const Text(
                'anyyting-es (Anthony An.)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                'Desarrollador del cliente nativo Flutter\nGitHub: github.com/anyyting-es',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              trailing: Icon(
                AppIcons.openInNew(iconPack),
                size: 20,
                color: theme.colorScheme.primary,
              ),
              onTap: () => launchUrl(
                Uri.parse('https://github.com/anyyting-es'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const PixelTileDivider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AppIcons.server(iconPack),
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 22,
                ),
              ),
              title: const Text(
                'Seanime Media Server',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                'Backend y servidor multimedia original creado por 5rahim\nhttps://seanime.app',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              trailing: Icon(
                AppIcons.openInNew(iconPack),
                size: 20,
                color: theme.colorScheme.primary,
              ),
              onTap: () => launchUrl(
                Uri.parse('https://seanime.app/'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── SISTEMA & VERSIONES ──────────────────────────────
        const SettingsSectionHeader(title: 'SISTEMA Y ACTUALIZACIONES'),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _LeadingIcon(icon: AppIcons.devices(iconPack)),
              title: const Text(
                'Cliente Móvil / PC',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                'v1.0.0 (Build Release)',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const PixelTileDivider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (serverState.isOnline ? const Color(0xFF22C55E) : theme.colorScheme.error)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  serverState.isOnline ? AppIcons.server(iconPack) : AppIcons.serverOff(iconPack),
                  color: serverState.isOnline ? const Color(0xFF22C55E) : theme.colorScheme.error,
                  size: 22,
                ),
              ),
              title: const Text(
                'Servidor Seanime Core',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                serverState.isOnline
                    ? 'Versión ${status?.version ?? "3.10.2"} (Conectado)'
                    : 'Desconectado o Servidor Local',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const PixelTileDivider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _LeadingIcon(icon: AppIcons.update(iconPack)),
              title: const Text(
                'Comprobar Actualizaciones',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                updateState.isChecking
                    ? 'Buscando actualizaciones en GitHub...'
                    : 'Buscar la versión más reciente en GitHub',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: updateState.isChecking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      AppIcons.refresh(iconPack),
                      color: theme.colorScheme.primary,
                    ),
              onTap: updateState.isChecking
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          content: const Text('Buscando actualizaciones en GitHub...'),
                          duration: const Duration(seconds: 1),
                        ),
                      );

                      final info = await ref
                          .read(appUpdateNotifierProvider.notifier)
                          .checkForUpdate();

                      if (!context.mounted) return;

                      if (info != null && info.hasUpdate) {
                        AppUpdateDialog.show(context, info);
                      } else if (info != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            content: Text(
                              'Estás en la versión más reciente (v${AppUpdateService.currentAppVersion}). No hay nuevas actualizaciones.',
                            ),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            content: const Text('No se pudo comprobar la actualización. Revisa tu conexión a internet.'),
                            action: SnackBarAction(
                              label: 'GitHub',
                              onPressed: () => launchUrl(
                                Uri.parse('https://github.com/anyyting-es/aniting/releases'),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          ),
                        );
                      }
                    },
            ),
            const PixelTileDivider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _LeadingIcon(icon: AppIcons.shield(iconPack)),
              title: const Text(
                'Licencias de Código Abierto',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                'Ver licencias y librerías de software libre',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                AppIcons.chevronRight(iconPack),
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Aniting',
                applicationVersion: '1.0.0',
                applicationLegalese: l10n.aboutLegalese,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── DESARROLLO & PRUEBAS ─────────────────────────────
        const SettingsSectionHeader(title: 'DESARROLLO & PRUEBAS'),
        const SizedBox(height: 10),
        PixelSettingsGroupCard(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _LeadingIcon(icon: AppIcons.wavingHand(iconPack)),
              title: Text(
                l10n.welcomeDevPreview,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                'Abrir el asistente de bienvenida en modo vista previa',
                style: TextStyle(fontSize: 12.5),
              ),
              trailing: Icon(
                AppIcons.play(iconPack),
                color: theme.colorScheme.primary,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WelcomeScreen(isDevPreview: true),
                  ),
                );
              },
            ),
            const PixelTileDivider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _LeadingIcon(icon: AppIcons.restore(iconPack)),
              title: Text(
                l10n.welcomeResetPrompt,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                'Restablece la bienvenida para mostrarla en el siguiente arranque',
                style: TextStyle(fontSize: 12.5),
              ),
              trailing: Icon(
                AppIcons.restore(iconPack),
                color: theme.colorScheme.error,
              ),
              onTap: () async {
                await ref.read(onboardingProvider.notifier).resetOnboarding();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      content: Text(l10n.welcomeResetDone),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  final IconData icon;
  const _LeadingIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: theme.colorScheme.onSecondaryContainer,
        size: 22,
      ),
    );
  }
}
