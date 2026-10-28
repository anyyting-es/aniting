import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Volume control widget providing a sleek M3 Expressive vertical popover on hover
/// for desktop (with scroll wheel support) and a mute/unmute icon for mobile.
class VolumeSlider extends ConsumerStatefulWidget {
  final double volume; // 0.0 to 100.0
  final ValueChanged<double> onVolumeChanged;
  final bool? isDesktopOverride;
  final ValueChanged<bool>? onHoverChanged;
  final double? iconSize;

  const VolumeSlider({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    this.isDesktopOverride,
    this.onHoverChanged,
    this.iconSize,
  });

  @override
  ConsumerState<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends ConsumerState<VolumeSlider>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portalController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _hideTimer;
  bool _isHovering = false;
  bool _isDragging = false;

  bool get _isDesktop =>
      widget.isDesktopOverride ?? (!Platform.isAndroid && !Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _animController.dispose();
    super.dispose();
  }

  void _startHover() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_isHovering) {
      _isHovering = true;
      widget.onHoverChanged?.call(true);
    }
    if (!_portalController.isShowing) {
      _portalController.show();
    }
    if (_animController.status != AnimationStatus.forward &&
        _animController.status != AnimationStatus.completed) {
      _animController.forward();
    }
  }

  void _scheduleHide() {
    if (_isDragging) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _isDragging) return;
      _isHovering = false;
      widget.onHoverChanged?.call(false);
      _animController.reverse().then((_) {
        if (!_isHovering && mounted && _portalController.isShowing) {
          _portalController.hide();
        }
      });
    });
  }

  void _handleScroll(PointerScrollEvent event) {
    _startHover();
    final delta = event.scrollDelta.dy;
    // Scroll up is negative delta (increase volume), scroll down is positive (decrease volume)
    final change = delta < 0 ? 5.0 : -5.0;
    widget.onVolumeChanged((widget.volume + change).clamp(0.0, 100.0));
  }

  IconData _getVolumeIcon([AppIconPack? pack]) {
    if (widget.volume <= 0) return AppIcons.volumeMute(pack);
    if (widget.volume < 35) return AppIcons.volumeLow(pack);
    if (widget.volume < 70) return AppIcons.volumeDown(pack);
    return AppIcons.volume(pack);
  }

  Widget _buildVolumePopup(BuildContext context, Color primaryColor, AppIconPack iconPack) {
    final normalizedVolume = (widget.volume / 100.0).clamp(0.0, 1.0);

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.topCenter,
      followerAnchor: Alignment.bottomCenter,
      offset: const Offset(0, -6),
      child: UnconstrainedBox(
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            alignment: Alignment.bottomCenter,
            child: MouseRegion(
              opaque: true,
              onEnter: (_) => _startHover(),
              onHover: (_) => _startHover(),
              onExit: (_) => _scheduleHide(),
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _handleScroll(event);
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 200,
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xF216151E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getVolumeIcon(iconPack),
                          size: 18,
                          color: widget.volume == 0 ? Colors.white38 : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              activeTrackColor: primaryColor,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.20),
                              thumbColor: primaryColor,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: normalizedVolume,
                              onChangeStart: (_) {
                                _isDragging = true;
                                _startHover();
                              },
                              onChanged: (newVal) =>
                                  widget.onVolumeChanged(newVal * 100.0),
                              onChangeEnd: (_) {
                                _isDragging = false;
                                _startHover();
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${widget.volume.round()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isMaterial = iconPack == AppIconPack.material;
    final double volumeIconSize = widget.iconSize ??
        (_isDesktop
            ? (isMaterial ? 28.0 : 23.0)
            : (isMaterial ? 24.0 : 21.0));

    if (!_isDesktop) {
      // Mobile compact mode: Mute / Unmute toggle button
      return IconButton(
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.all(2),
        ),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(_getVolumeIcon(iconPack), color: Colors.white, size: volumeIconSize),
        tooltip: widget.volume > 0 ? l10n.mute : l10n.unmute,
        onPressed: () {
          if (widget.volume > 0) {
            widget.onVolumeChanged(0.0);
          } else {
            widget.onVolumeChanged(100.0);
          }
        },
      );
    }

    // Desktop mode: Hover vertical M3 expressive popover with scroll wheel support
    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (ctx) => _buildVolumePopup(ctx, primaryColor, iconPack),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: MouseRegion(
          opaque: true,
          onEnter: (_) => _startHover(),
          onHover: (_) => _startHover(),
          onExit: (_) => _scheduleHide(),
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _handleScroll(event);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _startHover();
                if (widget.volume > 0) {
                  widget.onVolumeChanged(0.0);
                } else {
                  widget.onVolumeChanged(100.0);
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: Center(
                  child: Icon(
                    _getVolumeIcon(iconPack),
                    color: Colors.white,
                    size: volumeIconSize,
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
