import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_progress.dart';

class TvProgressService {
  static const String _storageKey = 'tv_progress';

  Future<List<TvProgress>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];

    return data.map((item) {
      return TvProgress.fromJson(jsonDecode(item));
    }).toList();
  }

  Future<void> save(List<TvProgress> shows) async {
    final prefs = await SharedPreferences.getInstance();

    final data = shows.map((show) {
      return jsonEncode(show.toJson());
    }).toList();

    await prefs.setStringList(_storageKey, data);
  }
}