import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool notificationsEnabled;

  const AppSettings({
    required this.themeMode,
    required this.notificationsEnabled,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const String _themeKey = 'theme_mode';
  static const String _notificationsKey = 'notifications_enabled';

  SettingsNotifier()
      : super(
          const AppSettings(
            themeMode: ThemeMode.light,
            notificationsEnabled: true,
          ),
        ) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString(_themeKey);
    final savedNotifications =
        prefs.getBool(_notificationsKey) ?? true;

    state = AppSettings(
      themeMode: _decodeThemeMode(savedTheme),
      notificationsEnabled: savedNotifications,
    );
  }

  ThemeMode _decodeThemeMode(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
      case ThemeMode.system:
        return 'light';
    }
  }

  void toggleDarkMode(bool enabled) {
    final newMode = enabled ? ThemeMode.dark : ThemeMode.light;

    state = state.copyWith(
      themeMode: newMode,
    );

    _saveThemeMode(newMode);
  }

  void setThemeMode(ThemeMode mode) {
    final fixedMode =
        mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;

    state = state.copyWith(
      themeMode: fixedMode,
    );

    _saveThemeMode(fixedMode);
  }

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(
      notificationsEnabled: enabled,
    );

    _saveNotifications(enabled);
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _themeKey,
      _encodeThemeMode(mode),
    );
  }

  Future<void> _saveNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _notificationsKey,
      enabled,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) {
    return SettingsNotifier();
  },
);