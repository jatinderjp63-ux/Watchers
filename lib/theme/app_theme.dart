import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFC89B5C), // gold
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFFFFFFF), // ivory
      onSurface: const Color(0xFF1F1A17),
      onSurfaceVariant: const Color(0xFF6D6258),
      outline: const Color(0xFFE2DBD0),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F0E6),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F0E6),
      foregroundColor: Color(0xFF1F1A17),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: const Color(0xFFE2DBD0),
    cardColor: const Color(0xFFFFFFFF),
    splashFactory: NoSplash.splashFactory,
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFC89B5C), // gold
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF111111), // charcoal
      onSurface: const Color(0xFFF4F4F4),
      onSurfaceVariant: const Color(0xFFB8B8B8),
      outline: const Color(0xFF262626),
    ),
    scaffoldBackgroundColor: const Color(0xFF0E0E0E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0E0E0E),
      foregroundColor: Color(0xFFF4F4F4),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: const Color(0xFF262626),
    cardColor: const Color(0xFF111111),
    splashFactory: NoSplash.splashFactory,
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
  );
}