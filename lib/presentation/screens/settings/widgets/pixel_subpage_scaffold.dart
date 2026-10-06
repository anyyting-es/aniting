import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';

/// Scaffold envolvente para subpantallas de ajustes con soporte adaptativo y cabecera colapsable fluida
class PixelSubpageScaffold extends StatelessWidget {
  final String title;
  final bool isEmbedded;
  final List<Widget> children;

  const PixelSubpageScaffold({
    super.key,
    required this.title,
    required this.isEmbedded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extraDesktopTop = DesktopWindowFrame.isDesktopPlatform ? DesktopTitleBar.height : 0.0;
    final topPadding = MediaQuery.paddingOf(context).top + extraDesktopTop;

    // En pantallas grandes (PC / Tablet): centrado compacto sin estiramiento exagerado
    if (isEmbedded) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                PixelPageHeader(
                  title: title,
                  showBackButton: false,
                ),
                const SizedBox(height: 12),
                ...children,
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      );
    }

    // En móvil: Cabecera colapsable fluida estilo Pixel/Material 3
    // El título se desplaza y escala continuamente hacia la derecha del botón atrás sin saltos ni solapamiento
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _PixelSubpageHeaderDelegate(
                  title: title,
                  topPadding: topPadding,
                  theme: theme,
                  onBackPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ...children,
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delegado de cabecera persistente que interpola fluidamente el título y el botón de retroceso
class _PixelSubpageHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final double topPadding;
  final ThemeData theme;
  final VoidCallback onBackPressed;

  const _PixelSubpageHeaderDelegate({
    required this.title,
    required this.topPadding,
    required this.theme,
    required this.onBackPressed,
  });

  @override
  double get minExtent => kToolbarHeight + topPadding;

  @override
  double get maxExtent => 128.0 + topPadding;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double delta = maxExtent - minExtent;
    final double progress = delta > 0 ? (shrinkOffset / delta).clamp(0.0, 1.0) : 0.0;
    final double curveProgress = Curves.easeInOutCubic.transform(progress);

    // Interpolación continua de posición, tamaño de fuente y espaciado
    final double currentLeft = ui.lerpDouble(16.0, 60.0, curveProgress)!;
    final double currentBottom = ui.lerpDouble(14.0, (kToolbarHeight - 24) / 2, curveProgress)!;
    final double currentFontSize = ui.lerpDouble(26.0, 19.0, curveProgress)!;
    final double currentLetterSpacing = ui.lerpDouble(-0.5, -0.2, curveProgress)!;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Divisor tenue inferior que aparece gradualmente al hacer scroll
          if (progress > 0.05)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.2 * progress,
                ),
              ),
            ),

          // Botón de atrás fijo en la barra superior
          Positioned(
            top: topPadding + (kToolbarHeight - 40) / 2,
            left: 12,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                color: theme.colorScheme.onSurface,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBackPressed,
              ),
            ),
          ),

          // Título de la página con animación y desplazamiento fluido
          Positioned(
            left: currentLeft,
            right: 16,
            bottom: currentBottom,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: currentFontSize,
                letterSpacing: currentLetterSpacing,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PixelSubpageHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.theme != theme;
  }
}

/// Cabecera de subpantalla con Botón Circular Atrás y Large Title (Estilo Pixel Settings)
class PixelPageHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;

  const PixelPageHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extraDesktopTop = DesktopWindowFrame.isDesktopPlatform ? DesktopTitleBar.height : 0.0;
    final topPadding = (showBackButton ? MediaQuery.paddingOf(context).top : 0.0) +
        (showBackButton ? extraDesktopTop : 0.0);

    return Padding(
      padding: EdgeInsets.only(top: topPadding + 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                color: theme.colorScheme.onSurface,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
