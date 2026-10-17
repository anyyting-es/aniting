import 'package:flutter/material.dart';
import 'package:seanime_app/presentation/widgets/whats_new/whats_new_dialog.dart';

void main() {
  runApp(const WhatsNewPreviewApp());
}

class WhatsNewPreviewApp extends StatefulWidget {
  const WhatsNewPreviewApp({super.key});

  @override
  State<WhatsNewPreviewApp> createState() => _WhatsNewPreviewAppState();
}

class _WhatsNewPreviewAppState extends State<WhatsNewPreviewApp> {
  bool isDark = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    const seedColor = Color(0xFFCBA6F7); // Violeta / Lavanda

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0C0F17),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Previsualización: Novedades'),
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
              onPressed: () => setState(() => isDark = !isDark),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: const WhatsNewDialog(),
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (ctx) => FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir como Modal Bottom Sheet'),
                    onPressed: () => WhatsNewDialog.show(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
