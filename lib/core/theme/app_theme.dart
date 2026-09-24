import 'package:flutter/material.dart';

/// Tema aplikasi dengan Material 3.
///
/// Mendukung mode terang dan gelap. Secara bawaan mengikuti
/// pengaturan sistem lewat [ThemeMode.system] di [main.dart].
class AppTheme {
  const AppTheme._();

  static const Color _seedColor = Colors.indigo;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}
