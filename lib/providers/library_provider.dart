import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../services/media_library_service.dart';

final mediaLibraryServiceProvider =
    Provider<MediaLibraryService>((ref) {
  return MediaLibraryService();
});

final libraryProvider = StateNotifierProvider<
    LibraryNotifier,
    List<MediaLibraryItem>>((ref) {
  final service = ref.watch(
    mediaLibraryServiceProvider,
  );

  return LibraryNotifier(service);
});

class LibraryNotifier
    extends StateNotifier<List<MediaLibraryItem>> {
  LibraryNotifier(this._service) : super([]) {
    MediaLibraryService.libraryChanges.addListener(
      _handleExternalLibraryChange,
    );

    loadLibrary();
  }

  final MediaLibraryService _service;

  Future<void> loadLibrary() async {
    state = await _service.getLibrary();
  }

  void _handleExternalLibraryChange() {
    loadLibrary();
  }

  Future<void> addMedia(
    Movie movie,
    MediaStatus status,
  ) async {
    await _service.addMedia(
      movie,
      status,
    );

    await loadLibrary();
  }

  Future<void> removeMedia(int id) async {
    await _service.removeMedia(id);
    await loadLibrary();
  }

  Future<void> updateStatus(
    int id,
    MediaStatus status,
  ) async {
    await _service.updateStatus(
      id,
      status,
    );

    await loadLibrary();
  }

  Future<void> upsertMovieStatus(
    Movie movie,
    MediaStatus status,
  ) async {
    final existing = getItemById(movie.id);

    if (existing == null) {
      await _service.addMedia(
        movie,
        status,
      );
    } else {
      await _service.updateStatus(
        movie.id,
        status,
      );
    }

    await loadLibrary();
  }

  List<MediaLibraryItem> byStatus(
    MediaStatus status,
  ) {
    return state
        .where(
          (item) => item.status == status,
        )
        .toList();
  }

  List<MediaLibraryItem> byMediaType(
    String mediaType,
  ) {
    return state
        .where(
          (item) => item.mediaType == mediaType,
        )
        .toList();
  }

  List<MediaLibraryItem> byMediaTypeAndStatus(
    String mediaType,
    MediaStatus status,
  ) {
    return state
        .where(
          (item) =>
              item.mediaType == mediaType &&
              item.status == status,
        )
        .toList();
  }

  MediaLibraryItem? getItemById(int id) {
    try {
      return state.firstWhere(
        (item) => item.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    MediaLibraryService.libraryChanges.removeListener(
      _handleExternalLibraryChange,
    );

    super.dispose();
  }
}