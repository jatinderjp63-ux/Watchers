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

  Future<void> load() async {
    state = await _service.load();
  }

  Future<void> addShow(TvProgress show) async {
    final normalized = _normalizeShow(show);
    final index = state.indexWhere((item) => item.id == show.id);

    if (index != -1) {
      final updated = [...state];
      updated[index] = normalized;
      state = updated;
    } else {
      state = [...state, normalized];
    }

    await _service.save(state);
  }

  Future<void> updateShow(TvProgress updated) async {
    final normalized = _normalizeShow(updated);

    state = state.map((show) {
      if (show.id == updated.id) {
        return normalized;
      }
      return show;
    }).toList();

    await _service.save(state);
  }

  Future<void> removeShow(int id) async {
    state = state.where((show) => show.id != id).toList();
    await _service.save(state);
  }

  Future<void> markEpisodeWatched(int id) async {
    final existing = getShowById(id);
    if (existing == null || existing.isFinished) {
      return;
    }

    final currentSeason = existing.currentSeason;
    final currentEpisode = existing.currentEpisode;

    try {
      final currentSeasonEpisodes = await _tmdbService.getSeasonEpisodes(
        existing.id,
        currentSeason,
      );

      final episodesInCurrentSeason = currentSeasonEpisodes.length;

      if (episodesInCurrentSeason <= 0) {
        await markEpisodeWatchedAt(
          id,
          currentSeason,
          currentEpisode + 1,
        );
        return;
      }

      if (currentEpisode < episodesInCurrentSeason) {
        await markEpisodeWatchedAt(
          id,
          currentSeason,
          currentEpisode + 1,
        );
        return;
      }

      final nextSeasonNumber = currentSeason + 1;
      final nextSeasonEpisodes = await _tmdbService.getSeasonEpisodes(
        existing.id,
        nextSeasonNumber,
      );

      if (nextSeasonEpisodes.isNotEmpty) {
        await markEpisodeWatchedAt(
          id,
          nextSeasonNumber,
          1,
        );
      }
    } catch (_) {
      await markEpisodeWatchedAt(
        id,
        currentSeason,
        currentEpisode + 1,
      );
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

    await updateShow(
      existing.copyWith(
        currentSeason: season,
        currentEpisode: episode,
        watchedEpisodes: watchedEpisodes ?? existing.watchedEpisodes,
        totalEpisodes: totalEpisodes ?? existing.totalEpisodes,
      ),
    );
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

    try {
      final watchedThroughSeason = await _episodesUpToSeason(
        existing.id,
        safeSeason,
      );

      final isWatched = existing.watchedEpisodes >= watchedThroughSeason;

      if (isWatched) {
        await _setProgressBeforeSeason(existing, safeSeason);
      } else {
        await _setProgressThroughSeason(existing, safeSeason);
      }
    } catch (error) {
      debugPrint('toggleSeasonWatched: $error');
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

    try {
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
    } catch (error) {
      debugPrint('toggleEpisodeWatchedAt: $error');
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
    final targetEpisodes = await _tmdbService.getSeasonEpisodes(
      existing.id,
      seasonNumber,
    );

    final watchedThroughSeason = await _episodesUpToSeason(
      existing.id,
      seasonNumber,
    );

    final episode = targetEpisodes.isEmpty ? 1 : targetEpisodes.length;

    await updateShow(
      existing.copyWith(
        currentSeason: seasonNumber,
        currentEpisode: episode,
        watchedEpisodes: _clampWatchedEpisodes(
          watchedThroughSeason,
          existing.totalEpisodes,
        ),
      ),
    );
  }

  Future<void> _setProgressBeforeSeason(
    TvProgress existing,
    int seasonNumber,
  ) async {
    if (seasonNumber <= 1) {
      await updateShow(
        existing.copyWith(
          currentSeason: 1,
          currentEpisode: 1,
          watchedEpisodes: 0,
        ),
      );
      return;
    }

    final previousSeason = seasonNumber - 1;
    final previousEpisodes = await _tmdbService.getSeasonEpisodes(
      existing.id,
      previousSeason,
    );

    final watchedThroughPreviousSeason = await _episodesUpToSeason(
      existing.id,
      previousSeason,
    );

    await updateShow(
      existing.copyWith(
        currentSeason: previousSeason,
        currentEpisode:
            previousEpisodes.isEmpty ? 1 : previousEpisodes.length,
        watchedEpisodes: _clampWatchedEpisodes(
          watchedThroughPreviousSeason,
          existing.totalEpisodes,
        ),
      ),
    );
  }

  Future<void> _setProgressThroughEpisode(
    TvProgress existing,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final targetEpisodes = await _tmdbService.getSeasonEpisodes(
      existing.id,
      seasonNumber,
    );

    final safeEpisode = targetEpisodes.isEmpty
        ? 1
        : episodeNumber.clamp(1, targetEpisodes.length);

    final watchedThroughEpisode = await _episodesUpToEpisode(
      existing.id,
      seasonNumber,
      safeEpisode,
    );

    await updateShow(
      existing.copyWith(
        currentSeason: seasonNumber,
        currentEpisode: safeEpisode,
        watchedEpisodes: _clampWatchedEpisodes(
          watchedThroughEpisode,
          existing.totalEpisodes,
        ),
      ),
    );
  }

  Future<void> _setProgressBeforeEpisode(
    TvProgress existing,
    int seasonNumber,
    int episodeNumber,
  ) async {
    if (episodeNumber > 1) {
      final previousEpisode = episodeNumber - 1;
      final watchedThroughPreviousEpisode = await _episodesUpToEpisode(
        existing.id,
        seasonNumber,
        previousEpisode,
      );

      await updateShow(
        existing.copyWith(
          currentSeason: seasonNumber,
          currentEpisode: previousEpisode,
          watchedEpisodes: _clampWatchedEpisodes(
            watchedThroughPreviousEpisode,
            existing.totalEpisodes,
          ),
        ),
      );
      return;
    }

    await _setProgressBeforeSeason(existing, seasonNumber);
  }

  int _clampWatchedEpisodes(int value, int totalEpisodes) {
    if (totalEpisodes > 0) {
      return value.clamp(0, totalEpisodes);
    }

    return value < 0 ? 0 : value;
  }

  TvProgress? getShowById(int id) {
    try {
      return state.firstWhere(
        (show) => show.id == id,
      );
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
      final episodes = await _tmdbService.getSeasonEpisodes(
        tvId,
        season,
      );

      total += episodes.length;
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
      final episodes = await _tmdbService.getSeasonEpisodes(
        tvId,
        season,
      );

      total += episodes.length;
    }

    final targetSeasonEpisodes = await _tmdbService.getSeasonEpisodes(
      tvId,
      seasonNumber,
    );

    if (targetSeasonEpisodes.isEmpty) {
      return total;
    }

    final safeEpisode = episodeNumber.clamp(
      1,
      targetSeasonEpisodes.length,
    );

    return total + safeEpisode;
  }
}