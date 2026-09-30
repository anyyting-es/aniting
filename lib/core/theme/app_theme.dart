import 'package:flutter/material.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F0D13),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F378B),
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F0D13),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: WebPageTransitionsBuilder(),
        TargetPlatform.iOS: WebPageTransitionsBuilder(),
        TargetPlatform.linux: WebPageTransitionsBuilder(),
        TargetPlatform.macOS: WebPageTransitionsBuilder(),
        TargetPlatform.windows: WebPageTransitionsBuilder(),
        TargetPlatform.fuchsia: WebPageTransitionsBuilder(),
      },
    ),
  );
}
