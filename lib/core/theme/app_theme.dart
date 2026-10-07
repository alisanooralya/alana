import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Palet dari ikon aplikasi (icon.png).
  static const Color _primer = Color(0xFF94E1FE); // cyan ikon
  static const Color _navy = Color(0xFF070D21); // latar ikon
  static const Color _putih = Color(0xFFFCFBFC); // putih ikon

  static const Color _seedColor = _primer;

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
    final skema = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: skema.copyWith(surface: _navy, onSurface: _putih),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}
