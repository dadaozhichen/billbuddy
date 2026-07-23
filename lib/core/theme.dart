import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _greenSeed = Color(0xFF2E7D32);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _greenSeed,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(centerTitle: true),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _greenSeed,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(centerTitle: true),
      );
}
