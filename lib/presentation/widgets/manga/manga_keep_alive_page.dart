import 'package:flutter/material.dart';

/// Mantiene las páginas de manga vivas en memoria una vez montadas.
/// Evita que el viewport (ListView o PageView) destruya el widget y
/// su imagen decodificada al scrollear, garantizando que el usuario
/// pueda avanzar y retroceder con 0ms de latencia y sin recargas visuales.
class MangaKeepAlivePage extends StatefulWidget {
  final Widget child;

  const MangaKeepAlivePage({
    super.key,
    required this.child,
  });

  @override
  State<MangaKeepAlivePage> createState() => _MangaKeepAlivePageState();
}

class _MangaKeepAlivePageState extends State<MangaKeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
