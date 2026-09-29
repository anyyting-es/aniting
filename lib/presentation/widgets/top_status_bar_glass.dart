import 'package:flutter/material.dart';

/// Un widget sutil colocado en la parte superior de la pantalla que protege
/// el área de la barra de estado de Android (safe area) con una sombrita difuminada
/// para que la barra de estado permanezca nítida mientras el contenido
/// fluye elegantemente por detrás.
///
/// OPTIMIZACIÓN: Se eliminó BackdropFilter + ShaderMask que forzaban al GPU a
/// hacer readback + Gaussian blur + saveLayer en cada frame de scroll.
/// El gradiente sólido con opacidad aumentada produce un efecto visual
/// prácticamente idéntico sin costo GPU.
class TopStatusBarGlass extends StatelessWidget {
  final bool isVisible;

  const TopStatusBarGlass({
    super.key,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    if (topPadding <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalHeight = topPadding + 20.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: SizedBox(
            height: totalHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.75 : 0.70),
                    (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.35 : 0.30),
                    Colors.transparent,
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
