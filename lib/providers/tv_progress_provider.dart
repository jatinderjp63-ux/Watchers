import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tv_progress.dart';
import '../services/tmdb_service.dart';
import '../services/tv_progress_service.dart';
import 'tmdb_service_provider.dart';

final tvProgressServiceProvider = Provider<TvProgressService>((ref) {
  return TvProgressService();
});

final tvProgressProvider =
    StateNotifierProvider<TvProgressNotifier, List<TvProgress>>((ref) {
  final progressService = ref.watch(tvProgressServiceProvider);
  final tmdbService = ref.watch(tmdbServiceProvider);

  return TvProgressNotifier(progressService, tmdbService);
});

class TvEpisodePosition {
  final int seasonNumber;
  final int episodeNumber;
  final DateTime? airDate;

  const TvEpisodePosition({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.airDate,
  });
}

class TvProgressSnapshot {
  final TvProgress progress;
  final List<TvEpisodePosition> releasedEpisodes;
  final List<TvEpisodePosition> allEpisodes;
  final List<TvEpisodePosition> todayEpisodes;
  final List<TvEpisodePosition> futureEpisodes;

  const TvProgressSnapshot({
    required this.progress,
    required this.releasedEpisodes,
    required this.allEpisodes,
    required this.todayEpisodes,
    required this.futureEpisodes,
  });

  int get watchedReleasedEpisodes {
    return progress.watchedEpisodes.clamp(0, releasedEpisodes.length);
  }

  bool get hasStarted {
    return watchedReleasedEpisodes > 0;
  }

  bool get hasFinishedReleasedEpisodes {
    return releasedEpisodes.isNotEmpty &&
        watchedReleasedEpisodes >= releasedEpisodes.length;
  }

  bool get hasFutureEpisodes {
    return futureEpisodes.isNotEmpty;
  }

  TvEpisodePosition? get lastWatched {
    if (!hasStarted || releasedEpisodes.isEmpty) {
      return null;
    }

    return releasedEpisodes[watchedReleasedEpisodes - 1];
  }

  /// Next unwatched released episode that aired BEFORE today.
  /// Used for Resume.
  TvEpisodePosition? get nextUnwatchedPastEpisode {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < releasedEpisodes.length; i++) {
      if (i >= watchedReleasedEpisodes) {
        final episode = releasedEpisodes[i];
        if (episode.airDate == null) {
          continue;
        }

        final dateOnly = DateTime(
          episode.airDate!.year,
          episode.airDate!.month,
          episode.airDate!.day,
        );

        if (dateOnly.isBefore(today)) {
          return episode;
        }
      }
    }

    return null;
  }

  /// Next episode for Airing:
  /// - If there is an unwatched episode airing today, return it.
  /// - Else if there is a future episode, return the earliest.
  /// - Else if all released episodes are watched and there are future episodes,
  ///   return the earliest future episode.
  TvEpisodePosition? get nextAiringEpisode {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check today's episodes first
    for (var i = 0; i < releasedEpisodes.length; i++) {
      final episode = releasedEpisodes[i];
      if (episode.airDate == null) {
        continue;
      }

      final dateOnly = DateTime(
        episode.airDate!.year,
        episode.airDate!.month,
        episode.airDate!.day,
      );

      if (dateOnly == today) {
        // Include both watched and unwatched for Airing
        return episode;
      }
    }

    // Then future episodes
    if (futureEpisodes.isNotEmpty) {
      return futureEpisodes.first;
    }

    return null;
  }

  /// All episodes for Airing section:
  /// - Today's episodes (watched or unwatched).
  /// - Future episodes.
  List<TvEpisodePosition> get airingEpisodes {
    return [...todayEpisodes, ...futureEpisodes];
  }

  int watchedInSeason(int seasonNumber) {
    return releasedEpisodes
        .take(watchedReleasedEpisodes)
        .where((episode) => episode.seasonNumber == seasonNumber)
        .length;
  }

  bool isEpisodeWatched(
    int seasonNumber,
    int episodeNumber,
  ) {
    final index = releasedEpisodes.indexWhere(
      (episode) =>
          episode.seasonNumber == seasonNumber &&
          episode.episodeNumber == episodeNumber,
    );

    if (index == -1) {
      return false;
    }

    return index < watchedReleasedEpisodes;
  }

  bool isSeasonWatched(int seasonNumber) {
    final seasonEpisodes = releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonEpisodes.isEmpty) {
      return false;
    }

    return seasonEpisodes.every(
      (episode) => isEpisodeWatched(
        episode.seasonNumber,
        episode.episodeNumber,
      ),
    );
  }
}

class TvProgressNotifier extends StateNotifier<List<TvProgress>> {
  TvProgressNotifier(this._service, this._tmdbService) : super([]) {
    load();
  }

  final TvProgressService _service;
  final TmdbService _tmdbService;

  final Map<int, Future<List<TvEpisodePosition>>> _catalogRequests = {};
  final Map<int, List<TvEpisodePosition>> _catalogCache = {};

  Future<void> load() async {
    state = await _service.load();
  }

  Future<void> addShow(TvProgress show) async {
    _replaceShow(_normalizeShow(show));
    await _saveInBackground();
  }

  Future<void> updateShow(TvProgress updated) async {
    _replaceShow(_normalizeShow(updated));
    await _saveInBackground();
  }

  Future<void> removeShow(int id) async {
    state = state.where((show) => show.id != id).toList();
    await _saveInBackground();
  }

  TvProgress? getShowById(int id) {
    try {
      return state.firstWhere((show) => show.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<TvProgress> ensureShow({
    required int id,
    required String title,
    required String posterPath,
    required int totalEpisodes,
    required int totalSeasons,
  }) async {
    final existing = getShowById(id);
    if (existing != null) {
      return existing;
    }

    final created = TvProgress(
      id: id,
      title: title,
      posterPath: posterPath,
      currentSeason: 1,
      currentEpisode: 1,
      watchedEpisodes: 0,
      totalEpisodes: totalEpisodes < 0 ? 0 : totalEpisodes,
      totalSeasons: totalSeasons < 0 ? 0 : totalSeasons,
    );

    _replaceShow(created);
    await _saveInBackground();
    return created;
  }

  Future<TvProgressSnapshot?> getSnapshot(int id) async {
    final progress = getShowById(id);
    if (progress == null) {
      return null;
    }

    final allEpisodes = await _getEpisodeCatalog(id);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final releasedEpisodes = <TvEpisodePosition>[];
    final todayEpisodes = <TvEpisodePosition>[];
    final futureEpisodes = <TvEpisodePosition>[];

    for (final episode in allEpisodes) {
      if (episode.airDate == null) {
        // Treat as unreleased; do not include in released/today/future
        continue;
      }

      final dateOnly = DateTime(
        episode.airDate!.year,
        episode.airDate!.month,
        episode.airDate!.day,
      );

      if (dateOnly.isBefore(today)) {
        releasedEpisodes.add(episode);
      } else if (dateOnly == today) {
        releasedEpisodes.add(episode);
        todayEpisodes.add(episode);
      } else {
        futureEpisodes.add(episode);
      }
    }

    // Sort all lists by season/episode
    _sortEpisodes(releasedEpisodes);
    _sortEpisodes(todayEpisodes);
    _sortEpisodes(futureEpisodes);

    return TvProgressSnapshot(
      progress: progress,
      releasedEpisodes: releasedEpisodes,
      allEpisodes: allEpisodes,
      todayEpisodes: todayEpisodes,
      futureEpisodes: futureEpisodes,
    );
  }

  void _sortEpisodes(List<TvEpisodePosition> episodes) {
    episodes.sort((a, b) {
      if (a.seasonNumber != b.seasonNumber) {
        return a.seasonNumber.compareTo(b.seasonNumber);
      }
      return a.episodeNumber.compareTo(b.episodeNumber);
    });
  }

  Future<void> toggleEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    final targetIndex = snapshot.releasedEpisodes.indexWhere(
      (episode) =>
          episode.seasonNumber == seasonNumber &&
          episode.episodeNumber == episodeNumber,
    );

    if (targetIndex == -1) {
      return;
    }

    final targetWatchedCount = targetIndex + 1;
    final isAlreadyWatched =
        snapshot.watchedReleasedEpisodes >= targetWatchedCount;

    final nextWatchedCount = isAlreadyWatched
        ? targetIndex
        : targetWatchedCount;

    await _setWatchedReleasedCount(
      snapshot,
      nextWatchedCount,
    );
  }

  Future<void> toggleSeasonWatched(
    int id,
    int seasonNumber,
  ) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    final seasonEpisodes = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonEpisodes.isEmpty) {
      return;
    }

    final lastEpisode = seasonEpisodes.last;
    final lastIndex = snapshot.releasedEpisodes.indexWhere(
      (episode) =>
          episode.seasonNumber == lastEpisode.seasonNumber &&
          episode.episodeNumber == lastEpisode.episodeNumber,
    );

    if (lastIndex == -1) {
      return;
    }

    final watchedThroughSeason = lastIndex + 1;
    final seasonAlreadyWatched =
        snapshot.watchedReleasedEpisodes >= watchedThroughSeason;

    final nextWatchedCount = seasonAlreadyWatched
        ? _watchedCountBeforeSeason(snapshot, seasonNumber)
        : watchedThroughSeason;

    await _setWatchedReleasedCount(
      snapshot,
      nextWatchedCount,
    );
  }

  Future<void> markEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    final targetIndex = snapshot.releasedEpisodes.indexWhere(
      (episode) =>
          episode.seasonNumber == seasonNumber &&
          episode.episodeNumber == episodeNumber,
    );

    if (targetIndex == -1) {
      return;
    }

    await _setWatchedReleasedCount(
      snapshot,
      targetIndex + 1,
    );
  }

  Future<void> markSeasonWatched(
    int id,
    int seasonNumber,
  ) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    final seasonEpisodes = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonEpisodes.isEmpty) {
      return;
    }

    final lastEpisode = seasonEpisodes.last;
    final lastIndex = snapshot.releasedEpisodes.indexWhere(
      (episode) =>
          episode.seasonNumber == lastEpisode.seasonNumber &&
          episode.episodeNumber == lastEpisode.episodeNumber,
    );

    if (lastIndex == -1) {
      return;
    }

    await _setWatchedReleasedCount(
      snapshot,
      lastIndex + 1,
    );
  }

  Future<void> markAllReleasedEpisodesWatched(int id) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null || snapshot.releasedEpisodes.isEmpty) {
      return;
    }

    await _setWatchedReleasedCount(
      snapshot,
      snapshot.releasedEpisodes.length,
    );
  }

  Future<void> clearEpisodeProgress(int id) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    await _setWatchedReleasedCount(snapshot, 0);
  }

  Future<void> setProgress({
    required int id,
    required int season,
    required int episode,
    int? watchedEpisodes,
    int? totalEpisodes,
  }) async {
    final existing = getShowById(id);
    if (existing == null) {
      return;
    }

    if (watchedEpisodes != null) {
      final snapshot = await getSnapshot(id);
      if (snapshot != null) {
        await _setWatchedReleasedCount(
          snapshot,
          watchedEpisodes,
          totalEpisodesOverride: totalEpisodes,
        );
        return;
      }
    }

    final updated = existing.copyWith(
      currentSeason: season < 1 ? 1 : season,
      currentEpisode: episode < 1 ? 1 : episode,
      totalEpisodes: totalEpisodes ?? existing.totalEpisodes,
      lastWatchedAt: DateTime.now(),
    );

    _replaceShow(_normalizeShow(updated));
    await _saveInBackground();
  }

  Future<void> markEpisodeWatched(int id) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    final next = snapshot.nextUnwatchedPastEpisode;
    if (next == null) {
      return;
    }

    await markEpisodeWatchedAt(
      id,
      next.seasonNumber,
      next.episodeNumber,
    );
  }

  Future<void> _setWatchedReleasedCount(
    TvProgressSnapshot snapshot,
    int requestedWatchedCount, {
    int? totalEpisodesOverride,
  }) async {
    final safeCount = requestedWatchedCount.clamp(
      0,
      snapshot.releasedEpisodes.length,
    );

    final existing = snapshot.progress;
    final lastWatched = safeCount == 0
        ? null
        : snapshot.releasedEpisodes[safeCount - 1];

    final totalKnownEpisodes = snapshot.allEpisodes.length > 0
        ? snapshot.allEpisodes.length
        : (totalEpisodesOverride ?? existing.totalEpisodes);

    final totalSeasons = _totalSeasonCount(
      snapshot.allEpisodes,
      fallback: existing.totalSeasons,
    );

    final updated = existing.copyWith(
      currentSeason: lastWatched?.seasonNumber ?? 1,
      currentEpisode: lastWatched?.episodeNumber ?? 1,
      watchedEpisodes: safeCount,
      totalEpisodes: totalKnownEpisodes,
      totalSeasons: totalSeasons,
      lastWatchedAt: safeCount == 0 ? null : DateTime.now(),
      clearLastWatchedAt: safeCount == 0,
    );

    _replaceShow(_normalizeShow(updated));
    await _saveInBackground();
  }

  int _watchedCountBeforeSeason(
    TvProgressSnapshot snapshot,
    int seasonNumber,
  ) {
    return snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber < seasonNumber)
        .length;
  }

  int _totalSeasonCount(
    List<TvEpisodePosition> episodes, {
    required int fallback,
  }) {
    if (episodes.isEmpty) {
      return fallback < 0 ? 0 : fallback;
    }

    var maxSeason = 0;
    for (final episode in episodes) {
      if (episode.seasonNumber > maxSeason) {
        maxSeason = episode.seasonNumber;
      }
    }

    return maxSeason > 0 ? maxSeason : fallback;
  }

  Future<List<TvEpisodePosition>> _getEpisodeCatalog(
    int tvId,
  ) async {
    final cached = _catalogCache[tvId];
    if (cached != null) {
      return cached;
    }

    final activeRequest = _catalogRequests[tvId];
    if (activeRequest != null) {
      return activeRequest;
    }

    final request = _loadEpisodeCatalog(tvId);
    _catalogRequests[tvId] = request;

    try {
      final catalog = await request;
      _catalogCache[tvId] = catalog;
      return catalog;
    } finally {
      _catalogRequests.remove(tvId);
    }
  }

  Future<List<TvEpisodePosition>> _loadEpisodeCatalog(
    int tvId,
  ) async {
    // Authoritative season count from raw TMDB metadata
    int totalSeasons = await _discoverSeasonCount(tvId);

    if (totalSeasons <= 0) {
      return const [];
    }

    final allEpisodes = <TvEpisodePosition>[];

    for (var season = 1; season <= totalSeasons; season++) {
      try {
        final episodes = await _tmdbService.getSeasonEpisodes(
          tvId,
          season,
        );

        for (final episode in episodes) {
          final seasonNumber = _readInt(
            episode['season_number'],
            fallback: season,
          );
          final episodeNumber = _readInt(
            episode['episode_number'],
            fallback: 0,
          );

          if (seasonNumber <= 0 || episodeNumber <= 0) {
            continue;
          }

          allEpisodes.add(
            TvEpisodePosition(
              seasonNumber: seasonNumber,
              episodeNumber: episodeNumber,
              airDate: _readDate(episode['air_date']),
            ),
          );
        }
      } catch (error) {
        debugPrint(
          'TV progress catalog error for S$season: $error',
        );
      }
    }

    _sortEpisodes(allEpisodes);
    return allEpisodes;
  }

  Future<int> _discoverSeasonCount(int tvId) async {
    try {
      final raw = await _tmdbService.getRawTvMetadata(tvId);
      final number_of_seasons = raw['number_of_seasons'];
      if (number_of_seasons is int && number_of_seasons > 0) {
        return number_of_seasons;
      }
    } catch (_) {
      // Fall through to heuristic below
    }

    // Heuristic fallback: probe seasons until one returns empty
    for (var season = 1; season <= 40; season++) {
      try {
        final episodes = await _tmdbService.getSeasonEpisodes(
          tvId,
          season,
        );

        if (episodes.isEmpty) {
          return season - 1;
        }
      } catch (_) {
        return season - 1;
      }
    }

    return 40;
  }

  DateTime? _readDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  int _readInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _replaceShow(TvProgress show) {
    final index = state.indexWhere((item) => item.id == show.id);

    if (index == -1) {
      state = [...state, show];
      return;
    }

    final updated = [...state];
    updated[index] = show;
    state = updated;
  }

  TvProgress _normalizeShow(TvProgress show) {
    final safeSeason = show.currentSeason < 1 ? 1 : show.currentSeason;
    final safeEpisode = show.currentEpisode < 1 ? 1 : show.currentEpisode;
    final safeTotalEpisodes = show.totalEpisodes < 0 ? 0 : show.totalEpisodes;
    final safeTotalSeasons = show.totalSeasons < 0 ? 0 : show.totalSeasons;
    final safeWatchedEpisodes = show.watchedEpisodes < 0
        ? 0
        : show.watchedEpisodes;

    return show.copyWith(
      currentSeason: safeSeason,
      currentEpisode: safeEpisode,
      watchedEpisodes: safeWatchedEpisodes,
      totalEpisodes: safeTotalEpisodes,
      totalSeasons: safeTotalSeasons,
    );
  }

  Future<void> _saveInBackground() async {
    try {
      await _service.save(state);
    } catch (error) {
      debugPrint('TV progress save error: $error');
    }
  }
}