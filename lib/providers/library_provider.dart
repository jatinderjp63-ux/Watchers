import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../services/media_library_service.dart';
import 'tv_progress_provider.dart';

final mediaLibraryServiceProvider = Provider<MediaLibraryService>((ref) {
  return MediaLibraryService();
});

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, List<MediaLibraryItem>>((ref) {
  final service = ref.watch(
    mediaLibraryServiceProvider,
  );

  return LibraryNotifier(service, ref);
});

class LibraryNotifier extends StateNotifier<List<MediaLibraryItem>> {
  LibraryNotifier(this._service, this._ref) : super([]) {
    MediaLibraryService.libraryChanges.addListener(
      _handleExternalLibraryChange,
    );

    loadLibrary();
  }

  final MediaLibraryService _service;
  final Ref _ref;

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
    final item = await _service.getItem(id);

    if (item == null) {
      return;
    }

    final oldStatus = item.status;

    if (item.mediaType == 'tv' &&
        status == MediaStatus.watched &&
        oldStatus != MediaStatus.watched) {
      final tvNotifier = _ref.read(tvProgressProvider.notifier);

      await tvNotifier.ensureShow(
        id: id,
        title: item.title,
        posterPath: item.posterPath,
        totalEpisodes: 0,
        totalSeasons: 0,
      );

      await tvNotifier.markAllReleasedEpisodesWatched(id);
    }

    await _service.updateStatus(id, status);

    await loadLibrary();
  }

  Future<void> upsertMovieStatus(
    Movie movie,
    MediaStatus status,
  ) async {
    final existing = getItemById(movie.id);
    final oldStatus = existing?.status;

    if (existing == null) {
      await _service.addMedia(
        movie,
        status,
      );
    } else {
      // If changing to Watched for a TV show, also mark episodes.
      if (existing.mediaType == 'tv' &&
          status == MediaStatus.watched &&
          oldStatus != MediaStatus.watched) {
        final tvNotifier = _ref.read(tvProgressProvider.notifier);

        await tvNotifier.ensureShow(
          id: movie.id,
          title: existing.title,
          posterPath: existing.posterPath,
          totalEpisodes: 0,
          totalSeasons: 0,
        );

        await tvNotifier.markAllReleasedEpisodesWatched(movie.id);
      }

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
          (item) => item.mediaType == mediaType && item.status == status,
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

  Future<MediaLibraryItem?> getItemByIdAsync(int id) async {
    final storedItem = await _service.getItem(id);

    if (storedItem != null) {
      return storedItem;
    }

    return getItemById(id);
  }

  @override
  void dispose() {
    MediaLibraryService.libraryChanges.removeListener(
      _handleExternalLibraryChange,
    );

    super.dispose();
  }
}
