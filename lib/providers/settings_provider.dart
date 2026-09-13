import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_progress_settings.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final WatchProgressSettings watchProgressSettings;

  const AppSettings({
    required this.themeMode,
    required this.notificationsEnabled,
    required this.watchProgressSettings,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    WatchProgressSettings? watchProgressSettings,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      watchProgressSettings:
          watchProgressSettings ?? this.watchProgressSettings,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const String _themeKey = 'theme_mode';
  static const String _notificationsKey = 'notifications_enabled';

  static const String _episodeMarkingKey = 'episode_marking_behavior';
  static const String _episodeUnmarkingKey = 'episode_unmarking_behavior';
  static const String _seasonMarkingKey = 'season_marking_behavior';
  static const String _seasonUnmarkingKey = 'season_unmarking_behavior';

  SettingsNotifier()
      : super(
          const AppSettings(
            themeMode: ThemeMode.light,
            notificationsEnabled: true,
            watchProgressSettings: WatchProgressSettings(),
          ),
        ) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString(_themeKey);
    final savedNotifications = prefs.getBool(_notificationsKey) ?? true;

    final savedEpisodeMarking = prefs.getString(_episodeMarkingKey);
    final savedEpisodeUnmarking = prefs.getString(_episodeUnmarkingKey);
    final savedSeasonMarking = prefs.getString(_seasonMarkingKey);
    final savedSeasonUnmarking = prefs.getString(_seasonUnmarkingKey);

    state = AppSettings(
      themeMode: _decodeThemeMode(savedTheme),
      notificationsEnabled: savedNotifications,
      watchProgressSettings: WatchProgressSettings(
        episodeMarking: _decodeEpisodeMarkingBehavior(savedEpisodeMarking),
        episodeUnmarking:
            _decodeEpisodeUnmarkingBehavior(savedEpisodeUnmarking),
        seasonMarking: _decodeSeasonMarkingBehavior(savedSeasonMarking),
        seasonUnmarking: _decodeSeasonUnmarkingBehavior(savedSeasonUnmarking),
      ),
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

  EpisodeMarkingBehavior _decodeEpisodeMarkingBehavior(String? value) {
    switch (value) {
      case 'onlyThisEpisode':
        return EpisodeMarkingBehavior.onlyThisEpisode;
      case 'askEveryTime':
        return EpisodeMarkingBehavior.askEveryTime;
      case 'previousReleased':
      default:
        return EpisodeMarkingBehavior.previousReleased;
    }
  }

  EpisodeUnmarkingBehavior _decodeEpisodeUnmarkingBehavior(String? value) {
    switch (value) {
      case 'onlyThisEpisode':
        return EpisodeUnmarkingBehavior.onlyThisEpisode;
      case 'askEveryTime':
        return EpisodeUnmarkingBehavior.askEveryTime;
      case 'laterReleased':
      default:
        return EpisodeUnmarkingBehavior.laterReleased;
    }
  }

  SeasonMarkingBehavior _decodeSeasonMarkingBehavior(String? value) {
    switch (value) {
      case 'onlyThisSeason':
        return SeasonMarkingBehavior.onlyThisSeason;
      case 'askEveryTime':
        return SeasonMarkingBehavior.askEveryTime;
      case 'previousReleased':
      default:
        return SeasonMarkingBehavior.previousReleased;
    }
  }

  SeasonUnmarkingBehavior _decodeSeasonUnmarkingBehavior(String? value) {
    switch (value) {
      case 'onlyThisSeason':
        return SeasonUnmarkingBehavior.onlyThisSeason;
      case 'askEveryTime':
        return SeasonUnmarkingBehavior.askEveryTime;
      case 'laterReleased':
      default:
        return SeasonUnmarkingBehavior.laterReleased;
    }
  }

  String _encodeEpisodeMarkingBehavior(EpisodeMarkingBehavior value) {
    switch (value) {
      case EpisodeMarkingBehavior.previousReleased:
        return 'previousReleased';
      case EpisodeMarkingBehavior.onlyThisEpisode:
        return 'onlyThisEpisode';
      case EpisodeMarkingBehavior.askEveryTime:
        return 'askEveryTime';
    }
  }

  String _encodeEpisodeUnmarkingBehavior(EpisodeUnmarkingBehavior value) {
    switch (value) {
      case EpisodeUnmarkingBehavior.laterReleased:
        return 'laterReleased';
      case EpisodeUnmarkingBehavior.onlyThisEpisode:
        return 'onlyThisEpisode';
      case EpisodeUnmarkingBehavior.askEveryTime:
        return 'askEveryTime';
    }
  }

  String _encodeSeasonMarkingBehavior(SeasonMarkingBehavior value) {
    switch (value) {
      case SeasonMarkingBehavior.previousReleased:
        return 'previousReleased';
      case SeasonMarkingBehavior.onlyThisSeason:
        return 'onlyThisSeason';
      case SeasonMarkingBehavior.askEveryTime:
        return 'askEveryTime';
    }
  }

  String _encodeSeasonUnmarkingBehavior(SeasonUnmarkingBehavior value) {
    switch (value) {
      case SeasonUnmarkingBehavior.laterReleased:
        return 'laterReleased';
      case SeasonUnmarkingBehavior.onlyThisSeason:
        return 'onlyThisSeason';
      case SeasonUnmarkingBehavior.askEveryTime:
        return 'askEveryTime';
    }
  }

  void toggleDarkMode(bool enabled) {
    final newMode = enabled ? ThemeMode.dark : ThemeMode.light;
    state = state.copyWith(themeMode: newMode);
    _saveThemeMode(newMode);
  }

  void setThemeMode(ThemeMode mode) {
    final fixedMode = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    state = state.copyWith(themeMode: fixedMode);
    _saveThemeMode(fixedMode);
  }

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
    _saveNotifications(enabled);
  }

  void setEpisodeMarkingBehavior(EpisodeMarkingBehavior behavior) {
    final updated = state.watchProgressSettings.copyWith(
      episodeMarking: behavior,
    );
    state = state.copyWith(watchProgressSettings: updated);
    _saveEpisodeMarkingBehavior(behavior);
  }

  void setEpisodeUnmarkingBehavior(EpisodeUnmarkingBehavior behavior) {
    final updated = state.watchProgressSettings.copyWith(
      episodeUnmarking: behavior,
    );
    state = state.copyWith(watchProgressSettings: updated);
    _saveEpisodeUnmarkingBehavior(behavior);
  }

  void setSeasonMarkingBehavior(SeasonMarkingBehavior behavior) {
    final updated = state.watchProgressSettings.copyWith(
      seasonMarking: behavior,
    );
    state = state.copyWith(watchProgressSettings: updated);
    _saveSeasonMarkingBehavior(behavior);
  }

  void setSeasonUnmarkingBehavior(SeasonUnmarkingBehavior behavior) {
    final updated = state.watchProgressSettings.copyWith(
      seasonUnmarking: behavior,
    );
    state = state.copyWith(watchProgressSettings: updated);
    _saveSeasonUnmarkingBehavior(behavior);
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _encodeThemeMode(mode));
  }

  Future<void> _saveNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }

  Future<void> _saveEpisodeMarkingBehavior(
    EpisodeMarkingBehavior behavior,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _episodeMarkingKey,
      _encodeEpisodeMarkingBehavior(behavior),
    );
  }

  Future<void> _saveEpisodeUnmarkingBehavior(
    EpisodeUnmarkingBehavior behavior,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _episodeUnmarkingKey,
      _encodeEpisodeUnmarkingBehavior(behavior),
    );
  }

  Future<void> _saveSeasonMarkingBehavior(
    SeasonMarkingBehavior behavior,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _seasonMarkingKey,
      _encodeSeasonMarkingBehavior(behavior),
    );
  }

  Future<void> _saveSeasonUnmarkingBehavior(
    SeasonUnmarkingBehavior behavior,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _seasonUnmarkingKey,
      _encodeSeasonUnmarkingBehavior(behavior),
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) {
    return SettingsNotifier();
  },
);
