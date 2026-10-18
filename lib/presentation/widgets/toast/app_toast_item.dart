import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/presentation/widgets/toast/app_toast.dart';

class AppToastItem extends ConsumerStatefulWidget {
  final ToastMessage toast;

  const AppToastItem({
    super.key,
    required this.toast,
  });

  @override
  ConsumerState<AppToastItem> createState() => _AppToastItemState();
}

class _AppToastItemState extends ConsumerState<AppToastItem>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  late final AnimationController _progressController;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    // Spring entry animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, -0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutBack,
      ),
    );

    // Duration timer animation
    _progressController = AnimationController(
      vsync: this,
      duration: widget.toast.duration,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleDismiss();
      }
    });

    _entryController.forward();
    _progressController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _pauseTimer() {
    if (_progressController.isAnimating) {
      _progressController.stop();
    }
  }

  void _resumeTimer() {
    if (!_isDismissing && !_progressController.isCompleted) {
      _progressController.forward();
    }
  }

  Future<void> _handleDismiss() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _progressController.stop();

    await _entryController.reverse();
    if (mounted) {
      AppToast.dismiss(widget.toast.id, context: context);
    }
  }

  Color _getStatusColor(ThemeData theme, AppThemeColors colors) {
    switch (widget.toast.type) {
      case ToastType.success:
        return const Color(0xFF10B981); // Emerald 500
      case ToastType.error:
        return const Color(0xFFEF4444); // Crimson / Rose 500
      case ToastType.warning:
        return const Color(0xFFF59E0B); // Amber 500
      case ToastType.info:
        return colors.accent;
    }
  }

  IconData _getDefaultIcon() {
    switch (widget.toast.type) {
      case ToastType.success:
        return LucideIcons.check;
      case ToastType.error:
        return LucideIcons.circleAlert;
      case ToastType.warning:
        return LucideIcons.triangleAlert;
      case ToastType.info:
        return LucideIcons.info;
    }
  }

  GlassFinish _getGlassFinish(bool isDark, Color statusColor) {
    final base = isDark ? GlassFinish.regularDark : GlassFinish.regularLight;
    return base.copyWith(
      tint: statusColor.withValues(alpha: isDark ? 0.16 : 0.10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOled = ref.watch(themeProvider.select((s) => s.isOled));
    final colors = context.themeColors;
    final statusColor = _getStatusColor(theme, colors);
    final iconData = widget.toast.icon ?? _getDefaultIcon();

    return MouseRegion(
      onEnter: (_) => _pauseTimer(),
      onExit: (_) => _resumeTimer(),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Dismissible(
            key: ValueKey(widget.toast.id),
            direction: DismissDirection.horizontal,
            onDismissed: (_) {
              AppToast.dismiss(widget.toast.id, context: context);
            },
            child: Material(
              type: MaterialType.transparency,
              child: GlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: EdgeInsets.zero,
                finish: _getGlassFinish(isDark, statusColor),
                child: Container(
                  decoration: BoxDecoration(
                    color: isOled
                        ? Colors.black.withValues(alpha: 0.85)
                        : (isDark ? const Color(0xFF13151B) : Colors.white)
                            .withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                        blurRadius: 18,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Icon badge
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: isDark ? 0.18 : 0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.35),
                                    width: 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  iconData,
                                  size: 16,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Text message & optional title
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.toast.title != null &&
                                        widget.toast.title!.isNotEmpty) ...[
                                      Text(
                                        widget.toast.title!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.1,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      widget.toast.message,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.90)
                                            : Colors.black87,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Optional action button
                              if (widget.toast.actionLabel != null &&
                                  widget.toast.onAction != null) ...[
                                const SizedBox(width: 8),
                                M3EButton(
                                  onPressed: () {
                                    widget.toast.onAction!();
                                    _handleDismiss();
                                  },
                                  style: M3EButtonStyle.tonal,
                                  size: M3EButtonSize.sm,
                                  child: Text(widget.toast.actionLabel!),
                                ),
                              ],

                              const SizedBox(width: 4),

                              // Close button
                              M3EIconButton(
                                onPressed: _handleDismiss,
                                variant: M3EIconButtonVariant.standard,
                                size: M3EIconButtonSize.xs,
                                tooltip: l10n.close,
                                icon: Icon(
                                  LucideIcons.x,
                                  size: 14,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Mini progress indicator bar
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, _) {
                            final progress = 1.0 - _progressController.value;
                            return Container(
                              height: 2.0,
                              color: Colors.transparent,
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.65),
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
