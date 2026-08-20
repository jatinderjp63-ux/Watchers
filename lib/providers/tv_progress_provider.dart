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

class TvProgressNotifier extends StateNotifier<List<TvProgress>> {
  TvProgressNotifier(this._service, this._tmdbService) : super([]) {
    load();
  }

  final TvProgressService _service;
  final TmdbService _tmdbService;

  final Map<String, int> _seasonEpisodeCounts = {};
  final Map<String, Future<int>> _seasonCountRequests = {};

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

  Future<void> markEpisodeWatched(int id) async {
    final existing = getShowById(id);
    if (existing == null || existing.isFinished) {
      return;
    }

    final currentSeason = existing.currentSeason;
    final currentEpisode = existing.currentEpisode;

    final currentSeasonCount = await _episodeCountForSeason(
      existing.id,
      currentSeason,
    );

    if (currentSeasonCount <= 0) {
      await markEpisodeWatchedAt(
        id,
        currentSeason,
        currentEpisode + 1,
      );
      return;
    }

    if (currentEpisode < currentSeasonCount) {
      await markEpisodeWatchedAt(
        id,
        currentSeason,
        currentEpisode + 1,
      );
      return;
    }

    final nextSeason = currentSeason + 1;
    final nextSeasonCount = await _episodeCountForSeason(
      existing.id,
      nextSeason,
    );

    if (nextSeasonCount > 0) {
      await markEpisodeWatchedAt(id, nextSeason, 1);
    }
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

    _replaceShow(
      _normalizeShow(
        existing.copyWith(
          currentSeason: season,
          currentEpisode: episode,
          watchedEpisodes: watchedEpisodes ?? existing.watchedEpisodes,
          totalEpisodes: totalEpisodes ?? existing.totalEpisodes,
        ),
      ),
    );

    await _saveInBackground();
  }

  Future<void> toggleSeasonWatched(
    int id,
    int seasonNumber,
  ) async {
    final existing = getShowById(id);
    if (existing == null) {
      return;
    }

    final safeSeason = seasonNumber < 1 ? 1 : seasonNumber;
    final watchedThroughSeason = await _episodesUpToSeason(
      existing.id,
      safeSeason,
    );

    final isWatched = existing.watchedEpisodes >= watchedThroughSeason;

    if (isWatched) {
      // Unwatch this season: set progress to the state just before this season
      await _setProgressBeforeSeason(existing, safeSeason);
    } else {
      // Watch this season
      await _setProgressThroughSeason(existing, safeSeason);
    }
  }

  Future<void> toggleEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final existing = getShowById(id);
    if (existing == null) {
      return;
    }

    final safeSeason = seasonNumber < 1 ? 1 : seasonNumber;
    final safeEpisode = episodeNumber < 1 ? 1 : episodeNumber;

    final watchedThroughEpisode = await _episodesUpToEpisode(
      existing.id,
      safeSeason,
      safeEpisode,
    );

    final isWatched = existing.watchedEpisodes >= watchedThroughEpisode;

    if (isWatched) {
      await _setProgressBeforeEpisode(
        existing,
        safeSeason,
        safeEpisode,
      );
    } else {
      await _setProgressThroughEpisode(
        existing,
        safeSeason,
        safeEpisode,
      );
    }
  }

  Future<void> markSeasonWatched(
    int id,
    int seasonNumber,
  ) async {
    final existing = getShowById(id);
    if (existing == null) {
      return;
    }

    await _setProgressThroughSeason(
      existing,
      seasonNumber < 1 ? 1 : seasonNumber,
    );
  }

  Future<void> markEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final existing = getShowById(id);
    if (existing == null) {
      return;
    }

    await _setProgressThroughEpisode(
      existing,
      seasonNumber < 1 ? 1 : seasonNumber,
      episodeNumber < 1 ? 1 : episodeNumber,
    );
  }

  Future<void> _setProgressThroughSeason(
    TvProgress existing,
    int seasonNumber,
  ) async {
    final targetEpisodeCount = await _episodeCountForSeason(
      existing.id,
      seasonNumber,
    );

    final watchedThroughSeason = await _episodesUpToSeason(
      existing.id,
      seasonNumber,
    );

    final updated = existing.copyWith(
      currentSeason: seasonNumber,
      currentEpisode: targetEpisodeCount > 0 ? targetEpisodeCount : 1,
      watchedEpisodes: _clampWatchedEpisodes(
        watchedThroughSeason,
        existing.totalEpisodes,
      ),
    );

    _replaceShow(_normalizeShow(updated));
    await _saveInBackground();
  }

  Future<void> _setProgressBeforeSeason(
    TvProgress existing,
    int seasonNumber,
  ) async {
    // If unwatching season 1, reset to the very beginning
    if (seasonNumber <= 1) {
      _replaceShow(
        _normalizeShow(
          existing.copyWith(
            currentSeason: 1,
            currentEpisode: 1,
            watchedEpisodes: 0,
          ),
        ),
      );

      await _saveInBackground();
      return;
    }

    // For seasons > 1, set progress to the end of the previous season
    final previousSeason = seasonNumber - 1;
    final previousEpisodeCount = await _episodeCountForSeason(
      existing.id,
      previousSeason,
    );

    final watchedThroughPreviousSeason = await _episodesUpToSeason(
      existing.id,
      previousSeason,
    );

    final updated = existing.copyWith(
      currentSeason: previousSeason,
      currentEpisode: previousEpisodeCount > 0 ? previousEpisodeCount : 1,
      watchedEpisodes: _clampWatchedEpisodes(
        watchedThroughPreviousSeason,
        existing.totalEpisodes,
      ),
    );

    _replaceShow(_normalizeShow(updated));
    await _saveInBackground();
  }

  Future<void> _setProgressThroughEpisode(
    TvProgress existing,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final targetEpisodeCount = await _episodeCountForSeason(
      existing.id,
      seasonNumber,
    );

    final safeEpisode = targetEpisodeCount <= 0
        ? 1
        : episodeNumber.clamp(1, targetEpisodeCount);

    final watchedThroughEpisode = await _episodesUpToEpisode(
      existing.id,
      seasonNumber,
      safeEpisode,
    );

    final updated = existing.copyWith(
      currentSeason: seasonNumber,
      currentEpisode: safeEpisode,
      watchedEpisodes: _clampWatchedEpisodes(
        watchedThroughEpisode,
        existing.totalEpisodes,
      ),
    );

    _replaceShow(_normalizeShow(updated));
    await _saveInBackground();
  }

  Future<void> _setProgressBeforeEpisode(
    TvProgress existing,
    int seasonNumber,
    int episodeNumber,
  ) async {
    if (episodeNumber <= 1) {
      // Unwatching episode 1 of a season → go to state before this season
      await _setProgressBeforeSeason(existing, seasonNumber);
      return;
    }

    final previousEpisode = episodeNumber - 1;

    final watchedThroughPreviousEpisode = await _episodesUpToEpisode(
      existing.id,
      seasonNumber,
      previousEpisode,
    );

    final updated = existing.copyWith(
      currentSeason: seasonNumber,
      currentEpisode: previousEpisode,
      watchedEpisodes: _clampWatchedEpisodes(
        watchedThroughPreviousEpisode,
        existing.totalEpisodes,
      ),
    );

    _replaceShow(_normalizeShow(updated));
    await _saveInBackground();
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

  Future<void> _saveInBackground() async {
    try {
      await _service.save(state);
    } catch (error) {
      debugPrint('TV progress save error: $error');
    }
  }

  String _seasonCacheKey(int showId, int seasonNumber) {
    return '$showId:$seasonNumber';
  }

  Future<int> _episodeCountForSeason(
    int showId,
    int seasonNumber,
  ) async {
    final safeSeason = seasonNumber < 1 ? 1 : seasonNumber;
    final key = _seasonCacheKey(showId, safeSeason);

    final cachedCount = _seasonEpisodeCounts[key];
    if (cachedCount != null) {
      return cachedCount;
    }

    final activeRequest = _seasonCountRequests[key];
    if (activeRequest != null) {
      return activeRequest;
    }

    final request = _loadEpisodeCount(showId, safeSeason, key);
    _seasonCountRequests[key] = request;

    try {
      return await request;
    } finally {
      _seasonCountRequests.remove(key);
    }
  }

  Future<int> _loadEpisodeCount(
    int showId,
    int seasonNumber,
    String cacheKey,
  ) async {
    try {
      final episodes = await _tmdbService.getSeasonEpisodes(
        showId,
        seasonNumber,
      );

      final count = episodes.length;
      _seasonEpisodeCounts[cacheKey] = count;
      return count;
    } catch (error) {
      debugPrint(
        'TV progress episode count error for S$seasonNumber: $error',
      );
      return 0;
    }
  }

  int _clampWatchedEpisodes(
    int value,
    int totalEpisodes,
  ) {
    if (totalEpisodes > 0) {
      return value.clamp(0, totalEpisodes);
    }

    return value < 0 ? 0 : value;
  }

  TvProgress? getShowById(int id) {
    try {
      return state.firstWhere((show) => show.id == id);
    } catch (_) {
      return null;
    }
  }

  TvProgress _normalizeShow(TvProgress show) {
    final safeSeason = show.currentSeason < 1 ? 1 : show.currentSeason;
    final safeEpisode = show.currentEpisode < 1 ? 1 : show.currentEpisode;
    final safeTotalEpisodes = show.totalEpisodes < 0 ? 0 : show.totalEpisodes;
    final safeTotalSeasons = show.totalSeasons < 0 ? 0 : show.totalSeasons;

    final safeWatchedEpisodes = safeTotalEpisodes > 0
        ? show.watchedEpisodes.clamp(0, safeTotalEpisodes)
        : (show.watchedEpisodes < 0 ? 0 : show.watchedEpisodes);

    return show.copyWith(
      currentSeason: safeSeason,
      currentEpisode: safeEpisode,
      watchedEpisodes: safeWatchedEpisodes,
      totalEpisodes: safeTotalEpisodes,
      totalSeasons: safeTotalSeasons,
    );
  }

  Future<int> _episodesUpToSeason(
    int tvId,
    int seasonNumber,
  ) async {
    int total = 0;

    for (var season = 1; season <= seasonNumber; season++) {
      total += await _episodeCountForSeason(tvId, season);
    }

    return total;
  }

  Future<int> _episodesUpToEpisode(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    int total = 0;

    for (var season = 1; season < seasonNumber; season++) {
      total += await _episodeCountForSeason(tvId, season);
    }

    final targetSeasonCount = await _episodeCountForSeason(
      tvId,
      seasonNumber,
    );

    if (targetSeasonCount <= 0) {
      return total;
    }

    final safeEpisode = episodeNumber.clamp(1, targetSeasonCount);
    return total + safeEpisode;
  }
}