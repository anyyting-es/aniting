import 'package:flutter/material.dart';

enum AppLanguage {
  en('en', 'English', 'US'),
  es('es', 'Español', 'ES');

  final String code;
  final String displayName;
  final String countryCode;

  const AppLanguage(this.code, this.displayName, this.countryCode);

  Locale get locale => Locale(code, countryCode);

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'en':
        return AppLanguage.en;
      case 'es':
        return AppLanguage.es;
      default:
        return AppLanguage.es;
    }
  }
}
