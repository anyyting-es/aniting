import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'anime_detail_advanced_sheet.dart';

/// Modal popup moderno con vidrio líquido de `g1455` (GlassCard) para seleccionar fuentes de streaming.
/// Abre con animación suave de resorte y desenfoque de cristal líquido.
class AnimeDetailSourcePopup extends ConsumerStatefulWidget {
  final List<OnlinestreamProvider> providers;
  final OnlinestreamProvider? selectedProvider;
  final bool isDubbed;
  final ValueChanged<OnlinestreamProvider?> onProviderChanged;
  final ValueChanged<bool> onToggleDubbed;
  final VoidCallback? onOpenManualMapping;
  final VoidCallback? onRefreshCache;

  const AnimeDetailSourcePopup({
    super.key,
    required this.providers,
    required this.selectedProvider,
    required this.isDubbed,
    required this.onProviderChanged,
    required this.onToggleDubbed,
    this.onOpenManualMapping,
    this.onRefreshCache,
  });

  static Future<void> show({
    required BuildContext context,
    required List<OnlinestreamProvider> providers,
    required OnlinestreamProvider? selectedProvider,
    required bool isDubbed,
    required ValueChanged<OnlinestreamProvider?> onProviderChanged,
    required ValueChanged<bool> onToggleDubbed,
    VoidCallback? onOpenManualMapping,
    VoidCallback? onRefreshCache,
  }) {
    final parentTheme = Theme.of(context);
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close source selector',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final bounceCurve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(bounceCurve),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim, secondaryAnim) => Theme(
        data: parentTheme,
        child: AnimeDetailSourcePopup(
          providers: providers,
          selectedProvider: selectedProvider,
          isDubbed: isDubbed,
          onProviderChanged: onProviderChanged,
          onToggleDubbed: onToggleDubbed,
          onOpenManualMapping: onOpenManualMapping,
          onRefreshCache: onRefreshCache,
        ),
      ),
    );
  }

  @override
  ConsumerState<AnimeDetailSourcePopup> createState() => _AnimeDetailSourcePopupState();
}

class _AnimeDetailSourcePopupState extends ConsumerState<AnimeDetailSourcePopup> {
  late OnlinestreamProvider? _selectedProv;

  @override
  void initState() {
    super.initState();
    _selectedProv = widget.selectedProvider;
  }

  void _openAdvancedSheet() {
    final parentTheme = Theme.of(context);
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Theme(
        data: parentTheme,
        child: AnimeDetailAdvancedSheet(
          selectedProvider: _selectedProv,
          isDubbed: widget.isDubbed,
          onToggleDubbed: widget.onToggleDubbed,
          onOpenManualMapping: widget.onOpenManualMapping,
          onRefreshCache: widget.onRefreshCache,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.public_rounded,
                              size: 19,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.onlineSources,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  l10n.availableSourcesCountLabel(widget.providers.length),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 19),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 0.8,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                    ),

                    // 2. Providers List
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: widget.providers.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.extension_off_rounded,
                                      size: 19, color: theme.colorScheme.outline),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l10n.noOnlineExtensionsInstalled,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                shrinkWrap: true,
                                itemCount: widget.providers.length,
                                itemBuilder: (context, index) {
                                  final p = widget.providers[index];
                                  final isSelected = _selectedProv?.id == p.id;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Material(
                                      color: isSelected
                                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setState(() => _selectedProv = p);
                                          widget.onProviderChanged(p);
                                          Navigator.pop(context);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 10),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? Icons.radio_button_checked_rounded
                                                    : Icons.radio_button_off_rounded,
                                                size: 18,
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  p.name,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    color: isSelected
                                                        ? theme.colorScheme.primary
                                                        : theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (p.lang.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.surfaceContainerHighest
                                                        .withValues(alpha: 0.5),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    p.lang.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              if (p.supportsDub) ...[
                                                const SizedBox(width: 5),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.surfaceContainerHighest
                                                        .withValues(alpha: 0.5),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'DUB',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 0.8,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                    ),

                    // 3. Clean "Opciones avanzadas" button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openAdvancedSheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l10n.advancedOptions,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  size: 17, color: theme.colorScheme.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
