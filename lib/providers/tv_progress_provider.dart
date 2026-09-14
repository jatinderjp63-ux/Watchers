import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tv_progress.dart';
import '../services/tmdb_service.dart';
import '../services/tv_progress_service.dart';
import 'tmdb_service_provider.dart';

typedef TvProgressLoad = Future<List<TvProgress>> Function();
typedef TvProgressSave = Future<void> Function(List<TvProgress> shows);
typedef TvSeasonCountLoader = Future<int> Function(int tvId);
typedef TvSeasonEpisodesLoader = Future<List<Map<String, dynamic>>> Function(
  int tvId,
  int seasonNumber,
);

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
  final int tvId;
  final int seasonNumber;
  final int episodeNumber;
  final DateTime? airDate;

  const TvEpisodePosition({
    required this.tvId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.airDate,
  });

  String get key => '$tvId:s${seasonNumber}e$episodeNumber';
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

  Set<String> get watchedKeys => progress.watchedEpisodeKeys;

  int get watchedReleasedEpisodes {
    return releasedEpisodes
        .where((episode) => watchedKeys.contains(episode.key))
        .length;
  }

  bool get hasStarted => watchedKeys.isNotEmpty;

  bool get hasFinishedReleasedEpisodes {
    return releasedEpisodes.isNotEmpty &&
        releasedEpisodes.every(
          (episode) => watchedKeys.contains(episode.key),
        );
  }

  bool get hasFutureEpisodes => futureEpisodes.isNotEmpty;

  TvEpisodePosition? get lastWatched {
    final watchedReleased = releasedEpisodes
        .where((episode) => watchedKeys.contains(episode.key))
        .toList();

    if (watchedReleased.isEmpty) {
      return null;
    }

    return watchedReleased.last;
  }

  TvEpisodePosition? get lastWatchedAnyEpisode {
    final watched = allEpisodes
        .where((episode) => watchedKeys.contains(episode.key))
        .toList();

    if (watched.isEmpty) {
      return null;
    }

    watched.sort((a, b) {
      if (a.seasonNumber != b.seasonNumber) {
        return a.seasonNumber.compareTo(b.seasonNumber);
      }

      return a.episodeNumber.compareTo(b.episodeNumber);
    });

    return watched.last;
  }

  /// The first unwatched dated episode released before today.
  TvEpisodePosition? get nextUnwatchedPastEpisode {
    final today = _todayOnly();

    for (final episode in releasedEpisodes) {
      final airDate = episode.airDate;
      if (airDate == null || watchedKeys.contains(episode.key)) {
        continue;
      }

      final dateOnly = DateTime(
        airDate.year,
        airDate.month,
        airDate.day,
      );

      if (dateOnly.isBefore(today)) {
        return episode;
      }
    }

    return null;
  }

  /// Episodes that belong in Airing:
  /// - Every dated episode airing today, watched or unwatched.
  /// - Every dated episode in the future.
  List<TvEpisodePosition> get airingEpisodes {
    return [...todayEpisodes, ...futureEpisodes];
  }

  int watchedInSeason(int seasonNumber) {
    return releasedEpisodes
        .where(
          (episode) =>
              episode.seasonNumber == seasonNumber &&
              watchedKeys.contains(episode.key),
        )
        .length;
  }

  int releasedInSeason(int seasonNumber) {
    return releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .length;
  }

  bool isEpisodeWatched(String episodeKey) {
    return watchedKeys.contains(episodeKey);
  }

  bool isEpisodeReleased(
    int seasonNumber,
    int episodeNumber,
  ) {
    return releasedEpisodes.any(
      (episode) =>
          episode.seasonNumber == seasonNumber &&
          episode.episodeNumber == episodeNumber,
    );
  }

  bool isSeasonWatched(int seasonNumber) {
    final seasonEpisodes = releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    return seasonEpisodes.isNotEmpty &&
        seasonEpisodes.every(
          (episode) => watchedKeys.contains(episode.key),
        );
  }

  static DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class TvProgressNotifier extends StateNotifier<List<TvProgress>> {
  TvProgressNotifier(
    this._service,
    this._tmdbService, {
    TvProgressLoad? loadProgress,
    TvProgressSave? saveProgress,
    TvSeasonCountLoader? loadSeasonCount,
    TvSeasonEpisodesLoader? loadSeasonEpisodes,
  })  : _loadProgress = loadProgress,
        _saveProgress = saveProgress,
        _loadSeasonCount = loadSeasonCount,
        _loadSeasonEpisodes = loadSeasonEpisodes,
        super([]) {
    load();
  }

  final TvProgressService _service;
  final TmdbService _tmdbService;

  final TvProgressLoad? _loadProgress;
  final TvProgressSave? _saveProgress;
  final TvSeasonCountLoader? _loadSeasonCount;
  final TvSeasonEpisodesLoader? _loadSeasonEpisodes;

  final Map<int, Future<List<TvEpisodePosition>>> _catalogRequests = {};
  final Map<int, List<TvEpisodePosition>> _catalogCache = {};

  Future<void> load() async {
    state = await (_loadProgress ?? _service.load)();
  }

  Future<void> addShow(TvProgress show) async {
    _replaceShow(_normalizeShow(show));
    await _save();
  }

  Future<void> updateShow(TvProgress updated) async {
    debugPrint(
      'TvProgressNotifier.updateShow: '
      'id=${updated.id}, watchedKeys=${updated.watchedEpisodeKeys}',
    );
    _replaceShow(_normalizeShow(updated));
    await _save();
  }

  Future<void> removeShow(int id) async {
    state = state.where((show) => show.id != id).toList();
    await _save();
  }

  TvProgress? getShowById(int id) {
    try {
      return state.firstWhere((show) => show.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Ensures a TvProgress record exists for the given show.
  Future<TvProgress> ensureShow({
    required int id,
    required String title,
    required String posterPath,
    int totalEpisodes = 0,
    int totalSeasons = 0,
  }) async {
    debugPrint(
      'TvProgressNotifier: ensureShow called: id=$id, title=$title',
    );

    final existing = getShowById(id);
    if (existing != null) {
      debugPrint(
        'TvProgressNotifier: ensureShow: '
        'found existing progress for id=$id',
      );
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
      watchedEpisodeKeys: const <String>{},
    );

    _replaceShow(created);
    await _save();

    debugPrint(
      'TvProgressNotifier: ensureShow: '
      'created new progress for id=$id',
    );

    return created;
  }

  /// Returns a snapshot for a show, creating a progress record if needed.
  Future<TvProgressSnapshot> getSnapshotForShow({
    required int id,
    required String title,
    required String posterPath,
    int totalEpisodes = 0,
    int totalSeasons = 0,
  }) async {
    debugPrint('TvProgressNotifier: getSnapshotForShow called: id=$id');

    final existing = getShowById(id);

    final progress = existing ??
        TvProgress(
          id: id,
          title: title,
          posterPath: posterPath,
          currentSeason: 1,
          currentEpisode: 1,
          watchedEpisodes: 0,
          totalEpisodes: totalEpisodes < 0 ? 0 : totalEpisodes,
          totalSeasons: totalSeasons < 0 ? 0 : totalSeasons,
          watchedEpisodeKeys: const <String>{},
        );

    return _buildSnapshot(progress);
  }

  /// Internal snapshot builder used by both public methods.
  Future<TvProgressSnapshot> _buildSnapshot(
    TvProgress progress,
  ) async {
    debugPrint(
      'TvProgressNotifier: _buildSnapshot called: id=${progress.id}',
    );

    final allEpisodes = await _getEpisodeCatalog(progress.id);
    final today = _todayOnly();

    final releasedEpisodes = <TvEpisodePosition>[];
    final todayEpisodes = <TvEpisodePosition>[];
    final futureEpisodes = <TvEpisodePosition>[];

    for (final episode in allEpisodes) {
      final airDate = episode.airDate;

      if (airDate == null) {
        continue;
      }

      final dateOnly = DateTime(
        airDate.year,
        airDate.month,
        airDate.day,
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

  /// Mark an episode and all earlier released episodes across all seasons
  /// as watched.
  Future<void> markWatchedUpToEpisode({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markWatchedUpToEpisode called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: markWatchedUpToEpisode: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);
    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markWatchedUpToEpisode: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

    int targetIndex = -1;
    for (var i = 0; i < snapshot.releasedEpisodes.length; i++) {
      final episode = snapshot.releasedEpisodes[i];

      if (episode.key == targetKey) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex < 0) {
      debugPrint(
        'TvProgressNotifier: markWatchedUpToEpisode: '
        'target episode not found in released list',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (var i = 0; i <= targetIndex; i++) {
      keys.add(snapshot.releasedEpisodes[i].key);
    }

    debugPrint(
      'TvProgressNotifier: markWatchedUpToEpisode: '
      'marking ${keys.length} episodes as watched',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Mark an episode and all earlier released episodes in the same season
  /// as watched. This is Step 1 of the mark-previous-episodes feature.
  Future<void> markWatchedUpToEpisodeInSeason({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markWatchedUpToEpisodeInSeason called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: markWatchedUpToEpisodeInSeason: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);
    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markWatchedUpToEpisodeInSeason: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markWatchedUpToEpisodeInSeason: '
        'no released episodes in season $seasonNumber',
      );
      return;
    }

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

    int targetIndex = -1;
    for (var i = 0; i < seasonReleased.length; i++) {
      final episode = seasonReleased[i];

      if (episode.key == targetKey) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex < 0) {
      debugPrint(
        'TvProgressNotifier: markWatchedUpToEpisodeInSeason: '
        'target episode not found in season released list',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (var i = 0; i <= targetIndex; i++) {
      keys.add(seasonReleased[i].key);
    }

    debugPrint(
      'TvProgressNotifier: markWatchedUpToEpisodeInSeason: '
      'marking ${keys.length} episodes as watched (season-only)',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Mark an episode and all earlier released episodes in the same season
  /// plus all released episodes in all previous seasons.
  /// This is Step 2 of the mark-previous-episodes feature.
  Future<void> markWatchedUpToEpisodeIncludingPreviousSeasons({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: '
      'markWatchedUpToEpisodeIncludingPreviousSeasons called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      debugPrint(
        'TvProgressUpToEpisodeIncludingPreviousSeasons: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);
    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: '
        'markWatchedUpToEpisodeIncludingPreviousSeasons: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (final episode in snapshot.releasedEpisodes) {
      if (episode.seasonNumber < seasonNumber) {
        keys.add(episode.key);
      }
    }

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isNotEmpty) {
      final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

      int targetIndex = -1;
      for (var i = 0; i < seasonReleased.length; i++) {
        final episode = seasonReleased[i];

        if (episode.key == targetKey) {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex >= 0) {
        for (var i = 0; i <= targetIndex; i++) {
          keys.add(seasonReleased[i].key);
        }
      }
    }

    debugPrint(
      'TvProgressNotifier: '
      'markWatchedUpToEpisodeIncludingPreviousSeasons: '
      'marking ${keys.length} episodes as watched '
      '(including previous seasons)',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Toggle a single episode's watched state in a season:
  /// - If episode is unwatched: mark it and all earlier released episodes in
  ///   that season.
  /// - If episode is watched: unmark only that episode.
  Future<void> toggleEpisodeWatchedInSeason({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: toggleEpisodeWatchedInSeason called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: toggleEpisodeWatchedInSeason: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: toggleEpisodeWatchedInSeason: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';
    final isCurrentlyWatched = progress.watchedEpisodeKeys.contains(targetKey);

    if (isCurrentlyWatched) {
      final newKeys = {...progress.watchedEpisodeKeys};
      newKeys.remove(targetKey);

      final updated = progress.copyWith(
        watchedEpisodeKeys: newKeys,
        watchedEpisodes: newKeys.length,
      );

      _replaceShow(_normalizeShow(updated));
      await _save();

      debugPrint(
        'TvProgressNotifier: toggleEpisodeWatchedInSeason: '
        'unmarked episode $targetKey',
      );
    } else {
      await markWatchedUpToEpisodeInSeason(
        tvId: tvId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    }
  }

  /// Toggle a single episode's watched state with previous-season marking:
  /// - If episode is unwatched: mark it, all earlier episodes in the season,
  ///   and all released episodes in previous seasons.
  /// - If episode is watched: unmark only that episode.
  Future<void> toggleEpisodeWatchedIncludingPreviousSeasons({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: '
      'toggleEpisodeWatchedIncludingPreviousSeasons called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: '
        'toggleEpisodeWatchedIncludingPreviousSeasons: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: '
        'toggleEpisodeWatchedIncludingPreviousSeasons: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';
    final isCurrentlyWatched = progress.watchedEpisodeKeys.contains(targetKey);

    if (isCurrentlyWatched) {
      final newKeys = {...progress.watchedEpisodeKeys};
      newKeys.remove(targetKey);

      final updated = progress.copyWith(
        watchedEpisodeKeys: newKeys,
        watchedEpisodes: newKeys.length,
      );

      _replaceShow(_normalizeShow(updated));
      await _save();

      debugPrint(
        'TvProgressNotifier: '
        'toggleEpisodeWatchedIncludingPreviousSeasons: '
        'unmarked episode $targetKey',
      );
    } else {
      await markWatchedUpToEpisodeIncludingPreviousSeasons(
        tvId: tvId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    }
  }

  /// Unmark the tapped episode and all later released episodes in the same
  /// season. Future seasons remain unchanged during Step 1.
  Future<void> markUnwatchedFromEpisodeInSeason({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markUnwatchedFromEpisodeInSeason called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: markUnwatchedFromEpisodeInSeason: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markUnwatchedFromEpisodeInSeason: '
        'no released episodes in season $seasonNumber',
      );
      return;
    }

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

    final targetIndex = seasonReleased.indexWhere(
      (episode) => episode.key == targetKey,
    );

    if (targetIndex < 0) {
      debugPrint(
        'TvProgressNotifier: markUnwatchedFromEpisodeInSeason: '
        'target episode not found in season released list',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (var index = targetIndex; index < seasonReleased.length; index++) {
      keys.remove(seasonReleased[index].key);
    }

    debugPrint(
      'TvProgressNotifier: markUnwatchedFromEpisodeInSeason: '
      'resulting watched count=${keys.length}',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Unmark the tapped episode and all later released episodes in the current
  /// season, plus all released episodes in future seasons.
  ///
  /// Previous seasons remain unchanged. Unreleased episodes remain unchanged.
  Future<void> markUnwatchedFromEpisodeIncludingFutureSeasons({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: '
      'markUnwatchedFromEpisodeIncludingFutureSeasons called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: '
        'markUnwatchedFromEpisodeIncludingFutureSeasons: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: '
        'markUnwatchedFromEpisodeIncludingFutureSeasons: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

    final targetIndex = snapshot.releasedEpisodes.indexWhere(
      (episode) => episode.key == targetKey,
    );

    if (targetIndex < 0) {
      debugPrint(
        'TvProgressNotifier: '
        'markUnwatchedFromEpisodeIncludingFutureSeasons: '
        'target episode not found in released list',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (final episode in snapshot.releasedEpisodes) {
      final isCurrentSeason = episode.seasonNumber == seasonNumber;
      final isLaterSeason = episode.seasonNumber > seasonNumber;

      if (isLaterSeason) {
        keys.remove(episode.key);
      } else if (isCurrentSeason && episode.episodeNumber >= episodeNumber) {
        keys.remove(episode.key);
      }
    }

    debugPrint(
      'TvProgressNotifier: '
      'markUnwatchedFromEpisodeIncludingFutureSeasons: '
      'resulting watched count=${keys.length}',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Unmark an episode and all later released episodes across all seasons.
  /// Kept for compatibility and reserved for the original cross-season path.
  Future<void> markUnwatchedFromEpisode({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markUnwatchedFromEpisode called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: markUnwatchedFromEpisode: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markUnwatchedFromEpisode: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

    int targetIndex = -1;
    for (var i = 0; i < snapshot.releasedEpisodes.length; i++) {
      final episode = snapshot.releasedEpisodes[i];

      if (episode.key == targetKey) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex < 0) {
      debugPrint(
        'TvProgressNotifier: markUnwatchedFromEpisode: '
        'target episode not found in released list',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (var i = targetIndex; i < snapshot.releasedEpisodes.length; i++) {
      keys.remove(snapshot.releasedEpisodes[i].key);
    }

    debugPrint(
      'TvProgressNotifier: markUnwatchedFromEpisode: '
      'resulting watched count=${keys.length}',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Episode tick interaction:
  /// - If episode is unwatched and released: markWatchedUpToEpisode.
  /// - If episode is watched and released: unmark the current season and
  ///   all future seasons during Step 2.
  /// - If episode is not released: do nothing.
  Future<void> toggleEpisodeProgressAt(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    debugPrint(
      'TvProgressNotifier: toggleEpisodeProgressAt called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);

    debugPrint(
      'TvProgressNotifier: progress found: '
      '${progress != null}, id=${progress?.id}',
    );

    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: toggleEpisodeProgressAt: '
        'no progress found, returning',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

    final isReleased = snapshot.releasedEpisodes.any(
      (episode) =>
          episode.seasonNumber == seasonNumber &&
          episode.episodeNumber == episodeNumber,
    );

    if (!isReleased) {
      debugPrint(
        'TvProgressNotifier: toggleEpisodeProgressAt: '
        'episode not released, ignoring',
      );
      return;
    }

    final isWatched = progress.watchedEpisodeKeys.contains(targetKey);

    debugPrint(
      'TvProgressNotifier: toggleEpisodeProgressAt: '
      'isWatched=$isWatched, targetKey=$targetKey',
    );

    if (isWatched) {
      await markUnwatchedFromEpisodeIncludingFutureSeasons(
        tvId: tvId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    } else {
      await markWatchedUpToEpisode(
        tvId: tvId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    }
  }

  /// Mark all released episodes in the selected season and every previous
  /// season as watched.
  ///
  /// Future seasons remain unchanged. Unreleased episodes remain unchanged.
  Future<void> markSeasonWatchedIncludingPreviousSeasons({
    required int tvId,
    required int seasonNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markSeasonWatchedIncludingPreviousSeasons called: '
      'tvId=$tvId, season=$seasonNumber',
    );

    final progress = getShowById(tvId);

    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: markSeasonWatchedIncludingPreviousSeasons: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markSeasonWatchedIncludingPreviousSeasons: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markSeasonWatchedIncludingPreviousSeasons: '
        'no released episodes in season $seasonNumber',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (final episode in snapshot.releasedEpisodes) {
      if (episode.seasonNumber <= seasonNumber) {
        keys.add(episode.key);
      }
    }

    debugPrint(
      'TvProgressNotifier: markSeasonWatchedIncludingPreviousSeasons: '
      'marking released episodes through season $seasonNumber; '
      'resulting watched count=${keys.length}',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Unmark all released episodes in the selected season and every future
  /// season. Previous seasons remain unchanged.
  ///
  /// Unreleased episodes remain unchanged because only released episodes are
  /// removed from the watched-key set.
  Future<void> markSeasonUnwatchedIncludingFutureSeasons({
    required int tvId,
    required int seasonNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markSeasonUnwatchedIncludingFutureSeasons called: '
      'tvId=$tvId, season=$seasonNumber',
    );

    final progress = getShowById(tvId);

    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: markSeasonUnwatchedIncludingFutureSeasons: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    if (snapshot.releasedEpisodes.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markSeasonUnwatchedIncludingFutureSeasons: '
        'no released episodes for tvId=$tvId',
      );
      return;
    }

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isEmpty) {
      debugPrint(
        'TvProgressNotifier: markSeasonUnwatchedIncludingFutureSeasons: '
        'no released episodes in season $seasonNumber',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (final episode in snapshot.releasedEpisodes) {
      if (episode.seasonNumber >= seasonNumber) {
        keys.remove(episode.key);
      }
    }

    debugPrint(
      'TvProgressNotifier: markSeasonUnwatchedIncludingFutureSeasons: '
      'unmarked released episodes from season $seasonNumber onward; '
      'resulting watched count=${keys.length}',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Season button interaction:
  /// - If all released episodes in the season are watched:
  ///   unmark all released episodes in that season.
  /// - Otherwise:
  ///   mark all released episodes in that season as watched.
  Future<void> toggleSeasonWatched(
    int tvId,
    int seasonNumber,
  ) async {
    debugPrint(
      'TvProgressNotifier: toggleSeasonWatched called: '
      'tvId=$tvId, season=$seasonNumber',
    );

    final progress = getShowById(tvId);

    debugPrint(
      'TvProgressNotifier: progress found: '
      '${progress != null}, id=${progress?.id}',
    );

    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: toggleSeasonWatched: '
        'no progress found, returning',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isEmpty) {
      debugPrint(
        'TvProgressNotifier: toggleSeasonWatched: '
        'no released episodes in season $seasonNumber',
      );
      return;
    }

    final allWatched = seasonReleased.every(
      (episode) => progress.watchedEpisodeKeys.contains(episode.key),
    );

    debugPrint(
      'TvProgressNotifier: toggleSeasonWatched: '
      'allWatched=$allWatched, '
      'seasonReleased count=${seasonReleased.length}',
    );

    final keys = {...progress.watchedEpisodeKeys};

    if (allWatched) {
      for (final episode in seasonReleased) {
        keys.remove(episode.key);
      }
    } else {
      for (final episode in seasonReleased) {
        keys.add(episode.key);
      }
    }

    debugPrint(
      'TvProgressNotifier: toggleSeasonWatched: '
      'resulting watched count=${keys.length}',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Mark only one released episode as watched.
  ///
  /// Previous and future episodes remain unchanged.
  Future<void> markSingleEpisodeWatched({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markSingleEpisodeWatched called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      return;
    }

    final snapshot = await _buildSnapshot(progress);
    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

    final isReleased = snapshot.releasedEpisodes.any(
      (episode) => episode.key == targetKey,
    );

    if (!isReleased) {
      debugPrint(
        'TvProgressNotifier: markSingleEpisodeWatched: '
        'episode is not released',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};
    keys.add(targetKey);

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Unmark only one released episode.
  ///
  /// Previous and future episodes remain unchanged.
  Future<void> markSingleEpisodeUnwatched({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markSingleEpisodeUnwatched called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      return;
    }

    final snapshot = await _buildSnapshot(progress);
    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';

    final isReleased = snapshot.releasedEpisodes.any(
      (episode) => episode.key == targetKey,
    );

    if (!isReleased) {
      debugPrint(
        'TvProgressNotifier: markSingleEpisodeUnwatched: '
        'episode is not released',
      );
      return;
    }

    final keys = {...snapshot.watchedKeys};
    keys.remove(targetKey);

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Mark every released episode in only the selected season.
  Future<void> markSingleSeasonWatched({
    required int tvId,
    required int seasonNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markSingleSeasonWatched called: '
      'tvId=$tvId, season=$seasonNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isEmpty) {
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (final episode in seasonReleased) {
      keys.add(episode.key);
    }

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Unmark every released episode in only the selected season.
  Future<void> markSingleSeasonUnwatched({
    required int tvId,
    required int seasonNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: markSingleSeasonUnwatched called: '
      'tvId=$tvId, season=$seasonNumber',
    );

    final progress = getShowById(tvId);
    if (progress == null) {
      return;
    }

    final snapshot = await _buildSnapshot(progress);

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isEmpty) {
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (final episode in seasonReleased) {
      keys.remove(episode.key);
    }

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Toggle a single episode's watched state without affecting other episodes.
  /// This is for individual episode tracking in the episode details screen.
  Future<void> toggleSingleEpisodeWatched({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    debugPrint(
      'TvProgressNotifier: toggleSingleEpisodeWatched called: '
      'tvId=$tvId, S$seasonNumber E$episodeNumber',
    );

    final progress = getShowById(tvId);

    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: toggleSingleEpisodeWatched: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final targetKey = '$tvId:s${seasonNumber}e$episodeNumber';
    final currentKeys = {...progress.watchedEpisodeKeys};

    if (currentKeys.contains(targetKey)) {
      currentKeys.remove(targetKey);

      debugPrint(
        'TvProgressNotifier: toggleSingleEpisodeWatched: '
        'unmarked episode $targetKey',
      );
    } else {
      currentKeys.add(targetKey);

      debugPrint(
        'TvProgressNotifier: toggleSingleEpisodeWatched: '
        'marked episode $targetKey',
      );
    }

    final updated = progress.copyWith(
      watchedEpisodeKeys: currentKeys,
      watchedEpisodes: currentKeys.length,
    );

    _replaceShow(_normalizeShow(updated));
    await _save();

    debugPrint(
      'TvProgressNotifier: toggleSingleEpisodeWatched: '
      'saved progress for id=$tvId, '
      'watched count=${currentKeys.length}',
    );
  }

  /// Mark all released episodes across all seasons as watched.
  Future<void> markAllReleasedEpisodesWatched(int tvId) async {
    debugPrint(
      'TvProgressNotifier: markAllReleasedEpisodesWatched called: '
      'tvId=$tvId',
    );

    final progress = getShowById(tvId);

    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: markAllReleasedEpisodesWatched: '
        'no progress found for tvId=$tvId',
      );
      return;
    }

    final snapshot = await _buildSnapshot(progress);
    final keys = {...progress.watchedEpisodeKeys};

    for (final episode in snapshot.releasedEpisodes) {
      keys.add(episode.key);
    }

    debugPrint(
      'TvProgressNotifier: markAllReleasedEpisodesWatched: '
      'marking ${keys.length} episodes as watched',
    );

    await _applyWatchedKeys(snapshot, keys);
  }

  Future<void> _applyWatchedKeys(
    TvProgressSnapshot snapshot,
    Set<String> rawKeys, {
    int? totalEpisodesOverride,
  }) async {
    debugPrint(
      'TvProgressNotifier: _applyWatchedKeys called: '
      'rawKeys count=${rawKeys.length}',
    );

    final allowedKeys =
        snapshot.allEpisodes.map((episode) => episode.key).toSet();

    final keys = rawKeys.where(allowedKeys.contains).toSet();

    final watchedEpisodes = snapshot.releasedEpisodes
        .where((episode) => keys.contains(episode.key))
        .length;

    debugPrint(
      'TvProgressNotifier: _applyWatchedKeys: '
      'filtered keys count=${keys.length}, '
      'watchedEpisodes=$watchedEpisodes',
    );

    final watchedReleased = snapshot.releasedEpisodes
        .where((episode) => keys.contains(episode.key))
        .toList();

    final lastWatched = watchedReleased.isEmpty ? null : watchedReleased.last;

    final existing = snapshot.progress;

    final updated = existing.copyWith(
      currentSeason: lastWatched?.seasonNumber ?? 1,
      currentEpisode: lastWatched?.episodeNumber ?? 1,
      watchedEpisodes: watchedEpisodes,
      totalEpisodes: snapshot.allEpisodes.isNotEmpty
          ? snapshot.allEpisodes.length
          : (totalEpisodesOverride ?? existing.totalEpisodes),
      totalSeasons: _totalSeasonCount(
        snapshot.allEpisodes,
        fallback: existing.totalSeasons,
      ),
      watchedEpisodeKeys: keys,
      clearLastWatchedAt: keys.isEmpty,
      lastWatchedAt: keys.isEmpty ? null : DateTime.now(),
    );

    _replaceShow(_normalizeShow(updated));

    debugPrint(
      'TvProgressNotifier: _applyWatchedKeys: '
      'saved progress for id=${updated.id}',
    );

    await _save();
  }

  Future<List<TvEpisodePosition>> _getEpisodeCatalog(int tvId) async {
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

  Future<List<TvEpisodePosition>> _loadEpisodeCatalog(int tvId) async {
    final totalSeasons = await _discoverSeasonCount(tvId);

    if (totalSeasons <= 0) {
      return const <TvEpisodePosition>[];
    }

    final allEpisodes = <TvEpisodePosition>[];

    for (var season = 1; season <= totalSeasons; season++) {
      try {
        final episodes = await (_loadSeasonEpisodes ??
            (int id, int seasonNumber) =>
                _tmdbService.getSeasonEpisodes(id, seasonNumber))(
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
              tvId: tvId,
              seasonNumber: seasonNumber,
              episodeNumber: episodeNumber,
              airDate: _readDate(episode['air_date']),
            ),
          );
        }
      } catch (error) {
        debugPrint(
          'TvProgressNotifier: TV catalog error for '
          '$tvId S$season: $error',
        );
      }
    }

    _sortEpisodes(allEpisodes);
    return allEpisodes;
  }

  Future<int> _discoverSeasonCount(int tvId) async {
    if (_loadSeasonCount != null) {
      return _loadSeasonCount!(tvId);
    }

    try {
      final raw = await _tmdbService.getRawTvMetadata(tvId);
      final value = raw['number_of_seasons'];

      if (value is int && value > 0) {
        return value;
      }

      if (value is num && value.toInt() > 0) {
        return value.toInt();
      }
    } catch (_) {
      // Fall back to probing below.
    }

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

  void _sortEpisodes(List<TvEpisodePosition> episodes) {
    episodes.sort((a, b) {
      if (a.seasonNumber != b.seasonNumber) {
        return a.seasonNumber.compareTo(b.seasonNumber);
      }

      return a.episodeNumber.compareTo(b.episodeNumber);
    });
  }

  int _totalSeasonCount(
    List<TvEpisodePosition> episodes, {
    required int fallback,
  }) {
    var highest = 0;

    for (final episode in episodes) {
      if (episode.seasonNumber > highest) {
        highest = episode.seasonNumber;
      }
    }

    return highest > 0 ? highest : fallback;
  }

  DateTime? _readDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    return raw.isEmpty ? null : DateTime.tryParse(raw);
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

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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
    // Accept both old format (108978:1:2) and new format (108978:s1e2).
    final safeKeys = show.watchedEpisodeKeys.where(_isEpisodeKey).toSet();

    return show.copyWith(
      currentSeason: show.currentSeason < 1 ? 1 : show.currentSeason,
      currentEpisode: show.currentEpisode < 1 ? 1 : show.currentEpisode,
      watchedEpisodes: show.watchedEpisodes < 0 ? 0 : show.watchedEpisodes,
      totalEpisodes: show.totalEpisodes < 0 ? 0 : show.totalEpisodes,
      totalSeasons: show.totalSeasons < 0 ? 0 : show.totalSeasons,
      watchedEpisodeKeys: safeKeys,
    );
  }

  bool _isEpisodeKey(String value) {
    // Accept new format: 108978:s1e2.
    if (value.contains(':s') && value.contains('e')) {
      final parts = value.split(':');

      if (parts.length != 2) {
        return false;
      }

      final tvId = int.tryParse(parts[0]);
      final seasonEpisodePart = parts[1];

      if (tvId == null || !seasonEpisodePart.startsWith('s')) {
        return false;
      }

      final eParts = seasonEpisodePart.split('e');

      if (eParts.length != 2) {
        return false;
      }

      final season = int.tryParse(eParts[0].substring(1));
      final episode = int.tryParse(eParts[1]);

      return season != null && episode != null && season > 0 && episode > 0;
    }

    // Accept old format: 108978:1:2.
    final parts = value.split(':');

    if (parts.length != 3) {
      return false;
    }

    final tvId = int.tryParse(parts[0]);
    final season = int.tryParse(parts[1]);
    final episode = int.tryParse(parts[2]);

    return tvId != null &&
        season != null &&
        episode != null &&
        season > 0 &&
        episode > 0;
  }

  Future<void> _save() async {
    try {
      await (_saveProgress ?? _service.save)(state);
    } catch (error) {
      debugPrint('TvProgressNotifier: TV progress save error: $error');
    }
  }

  // Compatibility methods for existing callers.

  Future<TvProgressSnapshot?> getSnapshot(int id) async {
    debugPrint('TvProgressNotifier: getSnapshot called: id=$id');

    final progress = getShowById(id);

    if (progress == null) {
      debugPrint(
        'TvProgressNotifier: getSnapshot: '
        'no progress found for id=$id',
      );
      return null;
    }

    return _buildSnapshot(progress);
  }

  /// Kept for compatibility; uses the current episode toggle behavior.
  Future<void> toggleEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    debugPrint(
      'TvProgressNotifier: toggleEpisodeWatchedAt called (compat): '
      'id=$id, S$seasonNumber E$episodeNumber',
    );

    await toggleEpisodeProgressAt(
      id,
      seasonNumber,
      episodeNumber,
    );
  }
}
