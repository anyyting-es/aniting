import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/providers/debrid_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';

class DebridSettingsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const DebridSettingsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<DebridSettingsScreen> createState() =>
      _DebridSettingsScreenState();
}

class _DebridSettingsScreenState extends ConsumerState<DebridSettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _isSaving = false;

  static const List<Map<String, String>> _providers = [
    {'id': 'realdebrid', 'name': 'Real-Debrid'},
    {'id': 'torbox', 'name': 'TorBox'},
    {'id': 'alldebrid', 'name': 'AllDebrid'},
    {'id': 'debridlink', 'name': 'Debrid-Link'},
    {'id': 'premiumize', 'name': 'Premiumize'},
  ];

  static const List<String> _resolutions = ['1080p', '720p', '4K'];

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _pasteApiKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() {
        _apiKeyController.text = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final debridAsync = ref.watch(debridSettingsProvider);

    return debridAsync.when(
      loading: () => PixelSubpageScaffold(
        title: l10n.debridSettings,
        isEmbedded: widget.isEmbedded,
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
      error: (err, _) => PixelSubpageScaffold(
        title: l10n.debridSettings,
        isEmbedded: widget.isEmbedded,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'Error: $err',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
      data: (settings) {
        if (_apiKeyController.text.isEmpty && settings.apiKey.isNotEmpty) {
          _apiKeyController.text = settings.apiKey;
        }

        return PixelSubpageScaffold(
          title: l10n.debridSettings,
          isEmbedded: widget.isEmbedded,
          children: [
            // 1. Maestro Switch (Card principal)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.zap,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.enableDebrid,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.enableDebridDesc,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.enabled,
                      onChanged: (val) async {
                        final updated = settings.copyWith(enabled: val);
                        await ref
                            .read(debridSettingsProvider.notifier)
                            .updateSettings(updated);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (settings.enabled) ...[
              SettingsSectionHeader(title: l10n.debridProvider),
              const SizedBox(height: 8),

              // 2. Selector de proveedor
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _providers.any((p) => p['id'] == settings.provider)
                          ? settings.provider
                          : _providers.first['id'],
                      isExpanded: true,
                      icon: const Icon(LucideIcons.chevronDown),
                      items: _providers.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'],
                          child: Row(
                            children: [
                              const Icon(LucideIcons.cloud, size: 18),
                              const SizedBox(width: 12),
                              Text(
                                p['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newProvider) async {
                        if (newProvider != null) {
                          final updated = settings.copyWith(
                            provider: newProvider,
                          );
                          await ref
                              .read(debridSettingsProvider.notifier)
                              .updateSettings(updated);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. API Key / Token
              SettingsSectionHeader(title: l10n.debridApiKey),
              const SizedBox(height: 8),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        decoration: InputDecoration(
                          hintText: l10n.debridApiKeyHint,
                          prefixIcon: const Icon(
                            LucideIcons.keyRound,
                            size: 20,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Paste API Key',
                                icon: const Icon(
                                  LucideIcons.clipboardPaste,
                                  size: 18,
                                ),
                                onPressed: _pasteApiKey,
                              ),
                              IconButton(
                                icon: Icon(
                                  _obscureApiKey
                                      ? LucideIcons.eye
                                      : LucideIcons.eyeOff,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureApiKey = !_obscureApiKey;
                                  });
                                },
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.debridApiKeyDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  setState(() => _isSaving = true);
                                  final updated = settings.copyWith(
                                    apiKey: _apiKeyController.text.trim(),
                                  );
                                  final ok = await ref
                                      .read(debridSettingsProvider.notifier)
                                      .updateSettings(updated);
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'API Key guardada correctamente'
                                            : 'Error al guardar API Key',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.check, size: 16),
                          label: const Text('Guardar Token'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. Opciones de Streaming Debrid
              const SettingsSectionHeader(title: 'Streaming & Selección'),
              const SizedBox(height: 8),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.debridAutoSelect,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.debridAutoSelectDesc,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: settings.streamAutoSelect,
                            onChanged: (val) async {
                              final updated = settings.copyWith(
                                streamAutoSelect: val,
                              );
                              await ref
                                  .read(debridSettingsProvider.notifier)
                                  .updateSettings(updated);
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.debridPreferredResolution,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  _resolutions.contains(
                                    settings.streamPreferredResolution,
                                  )
                                  ? settings.streamPreferredResolution
                                  : _resolutions.first,
                              items: _resolutions.map((res) {
                                return DropdownMenuItem<String>(
                                  value: res,
                                  child: Text(
                                    res,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newRes) async {
                                if (newRes != null) {
                                  final updated = settings.copyWith(
                                    streamPreferredResolution: newRes,
                                  );
                                  await ref
                                      .read(debridSettingsProvider.notifier)
                                      .updateSettings(updated);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
