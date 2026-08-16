import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';

class MediaLibraryService {
  static const String _storageKey = 'media_library';

  static final ValueNotifier<int> libraryChanges =
      ValueNotifier<int>(0);

  Future<List<MediaLibraryItem>> getLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];

    final library = data
        .map(
          (item) => MediaLibraryItem.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        )
        .toList();

    library.sort(
      (a, b) => b.addedDate.compareTo(a.addedDate),
    );

    return library;
  }

  Future<void> saveLibrary(
    List<MediaLibraryItem> library,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final data = library
        .map(
          (item) => jsonEncode(item.toJson()),
        )
        .toList();

    await prefs.setStringList(
      _storageKey,
      data,
    );

    libraryChanges.value++;
  }

  Future<void> addMedia(
    Movie movie,
    MediaStatus status,
  ) async {
    final library = await getLibrary();

    final existingIndex = library.indexWhere(
      (item) => item.id == movie.id,
    );

    final existingItem =
        existingIndex == -1 ? null : library[existingIndex];

    if (existingIndex != -1) {
      library.removeAt(existingIndex);
    }

    final parsedReleaseDate =
        DateTime.tryParse(movie.releaseDate);

    library.add(
      MediaLibraryItem(
        id: movie.id,
        title: movie.title,
        posterPath: movie.posterPath,
        backdropPath: movie.backdropPath,
        mediaType: movie.mediaType,
        status: status,
        currentSeason: existingItem?.currentSeason ?? 0,
        currentEpisode: existingItem?.currentEpisode ?? 0,
        addedDate: existingItem?.addedDate ?? DateTime.now(),
        releaseDate:
            parsedReleaseDate ?? existingItem?.releaseDate,
      ),
    );

    await saveLibrary(library);
  }

  Future<void> removeMedia(int id) async {
    final library = await getLibrary();

    library.removeWhere(
      (item) => item.id == id,
    );

    await saveLibrary(library);
  }

  Future<MediaLibraryItem?> getItem(int id) async {
    final library = await getLibrary();

    try {
      return library.firstWhere(
        (item) => item.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> updateStatus(
    int id,
    MediaStatus status,
  ) async {
    final library = await getLibrary();

    final index = library.indexWhere(
      (item) => item.id == id,
    );

    if (index == -1) {
      return;
    }

    library[index] = library[index].copyWith(
      status: status,
    );

    await saveLibrary(library);
  }

  Future<void> updateProgress({
    required int id,
    int? currentSeason,
    int? currentEpisode,
  }) async {
    final library = await getLibrary();

    final index = library.indexWhere(
      (item) => item.id == id,
    );

    if (index == -1) {
      return;
    }

    library[index] = library[index].copyWith(
      currentSeason: currentSeason,
      currentEpisode: currentEpisode,
    );

    await saveLibrary(library);
  }
}