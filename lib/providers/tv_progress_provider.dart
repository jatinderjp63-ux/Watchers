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
  TvProgressNotifier(this._service, this._tmdbService)
      : super([]) {
    load();
  }

  final TvProgressService _service;
  final TmdbService _tmdbService;

  Future<void> load() async {
    state = await _service.load();
  }

  Future<void> addShow(TvProgress show) async {
    final normalized = _normalizeShow(show);
    final index =
        state.indexWhere((item) => item.id == show.id);

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
    state =
        state.where((show) => show.id != id).toList();
    await _service.save(state);
  }

  Future<void> markEpisodeWatched(int id) async {
    final existing = getShowById(id);
    if (existing == null || existing.isFinished) {
      return;
    }

    final currentSeason = existing.currentSeason;
    var currentEpisode = existing.currentEpisode;

    try {
      final currentSeasonEpisodes =
          await _tmdbService.getSeasonEpisodes(
        existing.id,
        currentSeason,
      );

      final episodesInCurrentSeason =
          currentSeasonEpisodes.length;

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

      final nextSeasonNumber =
          currentSeason + 1;
      final nextSeasonEpisodes =
          await _tmdbService.getSeasonEpisodes(
        existing.id,
        nextSeasonNumber,
      );

      if (nextSeasonEpisodes.isNotEmpty) {
        await markEpisodeWatchedAt(
          id,
          nextSeasonNumber,
          1,
        );
        return;
      }

      final nextWatchedEpisodes =
          existing.watchedEpisodes + 1;

      await updateShow(
        existing.copyWith(
          watchedEpisodes: nextWatchedEpisodes,
        ),
      );
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
        watchedEpisodes:
            watchedEpisodes ?? existing.watchedEpisodes,
        totalEpisodes:
            totalEpisodes ?? existing.totalEpisodes,
      ),
    );
  }

  Future<void> markSeasonWatched(
    int id,
    int seasonNumber,
  ) async {
    debugPrint('markSeasonWatched: id=$id, season=$seasonNumber');

    final existing = getShowById(id);
    if (existing == null) {
      debugPrint('markSeasonWatched: show not found');
      return;
    }

    final targetSeason =
        seasonNumber < 1 ? 1 : seasonNumber;

    try {
      int totalWatched;

      try {
        totalWatched = await _episodesUpToSeason(
          existing.id,
          targetSeason,
        );
      } catch (_) {
        if (existing.totalEpisodes > 0 && existing.totalSeasons > 0) {
          final perSeason = existing.totalEpisodes / existing.totalSeasons;
          totalWatched = (perSeason * targetSeason).round();
          totalWatched = totalWatched.clamp(0, existing.totalEpisodes);
        } else {
          totalWatched = existing.watchedEpisodes;
        }
      }

      final newWatchedEpisodes = existing.totalEpisodes > 0
          ? totalWatched.clamp(
              existing.watchedEpisodes,
              existing.totalEpisodes,
            )
          : totalWatched > existing.watchedEpisodes
              ? totalWatched
              : existing.watchedEpisodes;

      await updateShow(
        existing.copyWith(
          currentSeason: targetSeason,
          currentEpisode: 1,
          watchedEpisodes: newWatchedEpisodes,
        ),
      );

      debugPrint(
        'markSeasonWatched: updated watchedEpisodes=$newWatchedEpisodes, '
        'currentSeason=$targetSeason, currentEpisode=1',
      );
    } catch (e) {
      debugPrint('markSeasonWatched: error=$e');
      await updateShow(
        existing.copyWith(
          currentSeason: targetSeason,
          currentEpisode: 1,
        ),
      );
    }
  }

  Future<void> toggleSeasonWatched(
    int id,
    int seasonNumber,
  ) async {
    debugPrint('toggleSeasonWatched: id=$id, season=$seasonNumber');

    final existing = getShowById(id);
    if (existing == null) {
      debugPrint('toggleSeasonWatched: show not found');
      return;
    }

    final targetSeason =
        seasonNumber < 1 ? 1 : seasonNumber;

    final episodesUpToTarget = await _episodesUpToSeason(existing.id, targetSeason);
    final isAlreadyWatched =
        existing.watchedEpisodes >= episodesUpToTarget;

    if (isAlreadyWatched) {
      await _moveBackToPreviousSeason(existing, targetSeason);
    } else {
      await markSeasonWatched(id, targetSeason);
    }
  }

  Future<void> _moveBackToPreviousSeason(
    TvProgress existing,
    int currentTargetSeason,
  ) async {
    int newSeason = currentTargetSeason - 1;
    int newEpisode = 1;
    int newWatched = existing.watchedEpisodes;

    if (newSeason < 1) {
      newSeason = 1;
      newEpisode = 1;
      newWatched = 0;
    } else {
      try {
        final prevEpisodes = await _tmdbService.getSeasonEpisodes(
          existing.id,
          newSeason,
        );
        newEpisode = prevEpisodes.isNotEmpty ? prevEpisodes.length : 1;
      } catch (_) {
        newEpisode = 1;
      }

      try {
        final watchedUpToPrev = await _episodesUpToSeason(
          existing.id,
          newSeason,
        );
        newWatched = watchedUpToPrev.clamp(0, existing.totalEpisodes);
      } catch (_) {
        newWatched = (existing.watchedEpisodes - 1).clamp(0, existing.totalEpisodes);
      }
    }

    await updateShow(
      existing.copyWith(
        currentSeason: newSeason,
        currentEpisode: newEpisode,
        watchedEpisodes: newWatched,
      ),
    );

    debugPrint(
      '_moveBackToPreviousSeason: moved to S$newSeason E$newEpisode, watched=$newWatched',
    );
  }

  Future<void> markEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    debugPrint(
      'markEpisodeWatchedAt: id=$id, season=$seasonNumber, episode=$episodeNumber',
    );

    final existing = getShowById(id);
    if (existing == null) {
      debugPrint('markEpisodeWatchedAt: show not found');
      return;
    }

    final safeSeason =
        seasonNumber < 1 ? 1 : seasonNumber;
    final safeEpisode =
        episodeNumber < 1 ? 1 : episodeNumber;

    try {
      final totalWatched =
          await _episodesUpToEpisode(
        existing.id,
        safeSeason,
        safeEpisode,
      );

      final newWatchedEpisodes = existing.totalEpisodes > 0
          ? totalWatched.clamp(
              existing.watchedEpisodes,
              existing.totalEpisodes,
            )
          : totalWatched > existing.watchedEpisodes
              ? totalWatched
              : existing.watchedEpisodes;

      await updateShow(
        existing.copyWith(
          currentSeason: safeSeason,
          currentEpisode: safeEpisode,
          watchedEpisodes: newWatchedEpisodes,
        ),
      );

      debugPrint(
        'markEpisodeWatchedAt: updated watchedEpisodes=$newWatchedEpisodes, '
        'currentSeason=$safeSeason, currentEpisode=$safeEpisode',
      );
    } catch (e) {
      debugPrint('markEpisodeWatchedAt: error=$e');
      await updateShow(
        existing.copyWith(
          currentSeason: safeSeason,
          currentEpisode: safeEpisode,
        ),
      );
    }
  }

  Future<void> toggleEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    debugPrint(
      'toggleEpisodeWatchedAt: id=$id, season=$seasonNumber, episode=$episodeNumber',
    );

    final existing = getShowById(id);
    if (existing == null) {
      debugPrint('toggleEpisodeWatchedAt: show not found');
      return;
    }

    final safeSeason =
        seasonNumber < 1 ? 1 : seasonNumber;
    final safeEpisode =
        episodeNumber < 1 ? 1 : episodeNumber;

    final isCurrentEpisode =
        existing.currentSeason == safeSeason &&
        existing.currentEpisode == safeEpisode;

    if (isCurrentEpisode) {
      await _moveBackOneEpisode(existing);
    } else {
      await markEpisodeWatchedAt(id, safeSeason, safeEpisode);
    }
  }

  Future<void> _moveBackOneEpisode(TvProgress existing) async {
    int newSeason = existing.currentSeason;
    int newEpisode = existing.currentEpisode - 1;

    if (newEpisode < 1) {
      newSeason = existing.currentSeason - 1;
      if (newSeason < 1) {
        return;
      }

      try {
        final prevSeasonEpisodes =
            await _tmdbService.getSeasonEpisodes(
          existing.id,
          newSeason,
        );

        newEpisode = prevSeasonEpisodes.isNotEmpty
            ? prevSeasonEpisodes.length
            : 1;
      } catch (_) {
        newEpisode = 1;
      }
    }

    final newWatched =
        (existing.watchedEpisodes - 1).clamp(0, existing.totalEpisodes);

    await updateShow(
      existing.copyWith(
        currentSeason: newSeason,
        currentEpisode: newEpisode,
        watchedEpisodes: newWatched,
      ),
    );

    debugPrint(
      '_moveBackOneEpisode: moved to S$newSeason E$newEpisode, watched=$newWatched',
    );
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
    final safeSeason =
        show.currentSeason < 1 ? 1 : show.currentSeason;
    final safeEpisode =
        show.currentEpisode < 1 ? 1 : show.currentEpisode;
    final safeTotalEpisodes =
        show.totalEpisodes < 0 ? 0 : show.totalEpisodes;
    final safeTotalSeasons =
        show.totalSeasons < 0 ? 0 : show.totalSeasons;

    final safeWatchedEpisodes =
        safeTotalEpisodes > 0
            ? show.watchedEpisodes.clamp(
                0,
                safeTotalEpisodes,
              )
            : (show.watchedEpisodes < 0
                ? 0
                : show.watchedEpisodes);

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
      final episodes =
          await _tmdbService.getSeasonEpisodes(
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
      final episodes =
          await _tmdbService.getSeasonEpisodes(
        tvId,
        season,
      );

      total += episodes.length;
    }

    final targetSeasonEpisodes =
        await _tmdbService.getSeasonEpisodes(
      tvId,
      seasonNumber,
    );

    if (targetSeasonEpisodes.isEmpty) {
      return total;
    }

    final countInSeason =
        targetSeasonEpisodes.length;

    final safeEpisode =
        episodeNumber.clamp(1, countInSeason);

    total += safeEpisode;

    return total;
  }
}