import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/m3_expressive_slider.dart';

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
    final isMaterial = iconPack == AppIconPack.material;
    final double volumeIconSize = isMaterial ? 24 : 22;

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomCenter,
      followerAnchor: Alignment.bottomCenter,
      offset: const Offset(0, 4),
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
                    width: 42,
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 3),
                    decoration: BoxDecoration(
                      color: const Color(0xF216151E),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Porcentaje superior: sin "%", número más visible
                        Text(
                          '${widget.volume.round()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Slider vertical Material 3 Expressive compacto sin palito
                        M3ExpressiveVerticalSlider(
                          value: normalizedVolume,
                          height: 100,
                          trackWidth: 16,
                          showThumb: false,
                          activeColor: primaryColor,
                          inactiveColor: Colors.white.withValues(alpha: 0.18),
                          onChanged: (newVal) =>
                              widget.onVolumeChanged(newVal * 100.0),
                          onChangeStart: () {
                            _isDragging = true;
                            _startHover();
                          },
                          onChangeEnd: () {
                            _isDragging = false;
                            _startHover();
                          },
                        ),

                        const SizedBox(height: 4),

                        // Icono de volumen integrado dentro del recuadro
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _startHover();
                            if (widget.volume > 0) {
                              widget.onVolumeChanged(0.0);
                            } else {
                              widget.onVolumeChanged(100.0);
                            }
                          },
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(
                              child: Icon(
                                _getVolumeIcon(iconPack),
                                size: volumeIconSize,
                                color: widget.volume == 0
                                    ? Colors.white38
                                    : primaryColor,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
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
        tooltip: widget.volume > 0 ? 'Silenciar' : 'Activar sonido',
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
              if (event is PointerScrollEvent && !_portalController.isShowing) {
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
              child: SizedBox(
                width: 36,
                height: 36,
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
