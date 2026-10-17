import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../core/i18n/i18n_provider.dart';
import '../../providers/debrid_provider.dart';

class WelcomeStepDebrid extends ConsumerStatefulWidget {
  const WelcomeStepDebrid({super.key});

  @override
  ConsumerState<WelcomeStepDebrid> createState() => _WelcomeStepDebridState();
}

class _WelcomeStepDebridState extends ConsumerState<WelcomeStepDebrid> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  String _selectedProvider = 'realdebrid';
  bool _enabled = false;
  bool _initialized = false;

  static const List<Map<String, String>> _providers = [
    {'id': 'realdebrid', 'name': 'Real-Debrid'},
    {'id': 'torbox', 'name': 'TorBox'},
    {'id': 'alldebrid', 'name': 'AllDebrid'},
    {'id': 'debridlink', 'name': 'Debrid-Link'},
    {'id': 'premiumize', 'name': 'Premiumize'},
  ];

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final current = ref.read(debridSettingsProvider).value;
    if (current == null) return;
    final updated = current.copyWith(
      enabled: _enabled,
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
    );
    ref.read(debridSettingsProvider.notifier).updateSettings(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final debridAsync = ref.watch(debridSettingsProvider);

    if (!_initialized && debridAsync.hasValue) {
      final s = debridAsync.value!;
      _enabled = s.enabled;
      _selectedProvider = s.provider.isNotEmpty ? s.provider : 'realdebrid';
      _apiKeyController.text = s.apiKey;
      _initialized = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Icon + Title only (clean, matching previous steps) ───
          Row(
            children: [
              GlassCard(
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  LucideIcons.zap,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                l10n.welcomeStepDebrid,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Master Switch Glass Card
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.enableDebrid,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stream cloud-cached torrents directly at high speeds',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  M3ESwitch(
                    value: _enabled,
                    onChanged: (val) {
                      setState(() => _enabled = val);
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Provider selector & API Key
          AnimatedOpacity(
            opacity: _enabled ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_enabled,
              child: GlassCard(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debrid Provider',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _providers.map((p) {
                          final isSelected = _selectedProvider == p['id'];
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedProvider = p['id']!);
                              _saveSettings();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.16)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                p['name']!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'API Key / Token',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        onChanged: (_) => _saveSettings(),
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Enter your API key or token',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureApiKey
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 18,
                            ),
                            onPressed: () => setState(
                                () => _obscureApiKey = !_obscureApiKey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
