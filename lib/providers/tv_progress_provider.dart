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

  /// The first unwatched dated episode released before today.
  /// This is the only kind of episode eligible for Resume.
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
}class TvProgressNotifier extends StateNotifier<List<TvProgress>> {
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
    await _save();
  }

  Future<void> updateShow(TvProgress updated) async {
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
      watchedEpisodeKeys: const <String>{},
    );

    _replaceShow(created);
    await _save();
    return created;
  }

  /// Returns a snapshot only for shows that already have a persisted
  /// TV-progress record.
  Future<TvProgressSnapshot?> getSnapshot(int id) async {
    final progress = getShowById(id);
    if (progress == null) {
      return null;
    }

    return _buildSnapshot(progress);
  }

  /// Creates a neutral empty-progress snapshot for a Library TV show.
  /// This lets Airing work before the user has visited Episodes.
  Future<TvProgressSnapshot> getSnapshotForShow({
    required int id,
    required String title,
    required String posterPath,
    int totalEpisodes = 0,
    int totalSeasons = 0,
  }) async {
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

  Future<TvProgressSnapshot> _buildSnapshot(TvProgress progress) async {
    final allEpisodes = await _getEpisodeCatalog(progress.id);
    final today = _todayOnly();

    final releasedEpisodes = <TvEpisodePosition>[];
    final todayEpisodes = <TvEpisodePosition>[];
    final futureEpisodes = <TvEpisodePosition>[];

    for (final episode in allEpisodes) {
      final airDate = episode.airDate;

      // Missing TMDB dates are deliberately treated as unreleased/unknown.
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

    final migratedProgress = _migrateLegacyProgress(
      progress,
      releasedEpisodes,
      allEpisodes,
    );

    if (!identical(migratedProgress, progress)) {
      _replaceShow(migratedProgress);
      await _save();
    }

    return TvProgressSnapshot(
      progress: migratedProgress,
      releasedEpisodes: releasedEpisodes,
      allEpisodes: allEpisodes,
      todayEpisodes: todayEpisodes,
      futureEpisodes: futureEpisodes,
    );
  }

  TvProgress _migrateLegacyProgress(
    TvProgress progress,
    List<TvEpisodePosition> releasedEpisodes,
    List<TvEpisodePosition> allEpisodes,
  ) {
    // If already using the new key format, or no legacy data, return as-is.
    if (progress.watchedEpisodeKeys.isNotEmpty) {
      final sampleKey = progress.watchedEpisodeKeys.first;
      if (sampleKey.contains(':s') && sampleKey.contains('e')) {
        // Already new format "$tvId:s${season}e${episode}"
        return progress;
      }
    }

    if (progress.watchedEpisodes <= 0 || releasedEpisodes.isEmpty) {
      return progress;
    }

    final count = progress.watchedEpisodes.clamp(
      0,
      releasedEpisodes.length,
    );

    // Migrate from old "${season}:${episode}" keys to new "$tvId:s${season}e${episode}"
    final keys = <String>{};
    for (var i = 0; i < count; i++) {
      final ep = releasedEpisodes[i];
      keys.add(ep.key); // new format
    }

    final last = count == 0 ? null : releasedEpisodes[count - 1];

    return progress.copyWith(
      watchedEpisodeKeys: keys,
      watchedEpisodes: keys.length,
      currentSeason: last?.seasonNumber ?? 1,
      currentEpisode: last?.episodeNumber ?? 1,
      totalEpisodes: allEpisodes.isNotEmpty
          ? allEpisodes.length
          : progress.totalEpisodes,
      totalSeasons: _totalSeasonCount(
        allEpisodes,
        fallback: progress.totalSeasons,
      ),
      clearLastWatchedAt: count == 0,
    );
  }  /// A direct one-key toggle for a single episode.
  /// - If the episode is watched, it becomes unwatched.
  /// - If the episode is unwatched and released, it becomes watched.
  /// This does NOT auto-mark earlier episodes; it is strict single-episode.
  Future<void> toggleEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final snapshot = await getSnapshot(id);

    if (snapshot == null ||
        !snapshot.isEpisodeReleased(seasonNumber, episodeNumber)) {
      return;
    }

    final keys = {...snapshot.watchedKeys};
    final key = '$id:s${seasonNumber}e$episodeNumber';

    if (keys.contains(key)) {
      keys.remove(key);
    } else {
      keys.add(key);
    }

    await _applyWatchedKeys(snapshot, keys);
  }

  /// Episode-tick interaction used by the TV details page:
  ///
  /// - Tapping an unwatched released episode marks it and every earlier
  ///   released episode as watched.
  /// - Tapping an already watched episode unmarks only that exact episode.
  /// - Future/no-date episodes are rejected.
  Future<void> toggleEpisodeProgressAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final snapshot = await getSnapshot(id);

    if (snapshot == null ||
        !snapshot.isEpisodeReleased(seasonNumber, episodeNumber)) {
      return;
    }

    final targetKey = '$id:s${seasonNumber}e$episodeNumber';
    final keys = {...snapshot.watchedKeys};

    if (keys.contains(targetKey)) {
      // Only the pressed episode is removed. Earlier and later keys stay.
      keys.remove(targetKey);
      await _applyWatchedKeys(snapshot, keys);
      return;
    }

    // Mark every earlier released episode, plus the selected episode.
    for (final episode in snapshot.releasedEpisodes) {
      keys.add(episode.key);

      if (episode.key == targetKey) {
        break;
      }
    }

    await _applyWatchedKeys(snapshot, keys);
  }

  Future<void> markEpisodeWatchedAt(
    int id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final snapshot = await getSnapshot(id);

    if (snapshot == null ||
        !snapshot.isEpisodeReleased(seasonNumber, episodeNumber)) {
      return;
    }

    final keys = {...snapshot.watchedKeys};
    keys.add('$id:s${seasonNumber}e$episodeNumber');

    await _applyWatchedKeys(snapshot, keys);
  }

  Future<void> toggleSeasonWatched(
    int id,
    int seasonNumber,
  ) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    final seasonReleased = snapshot.releasedEpisodes
        .where((episode) => episode.seasonNumber == seasonNumber)
        .toList();

    if (seasonReleased.isEmpty) {
      return;
    }

    final keys = {...snapshot.watchedKeys};
    final seasonIsFullyWatched = seasonReleased.every(
      (episode) => keys.contains(episode.key),
    );

    if (seasonIsFullyWatched) {
      // Only remove released episodes of the selected season.
      for (final episode in seasonReleased) {
        keys.remove(episode.key);
      }
    } else {
      // Only add dated episodes released up through today.
      for (final episode in seasonReleased) {
        keys.add(episode.key);
      }
    }

    await _applyWatchedKeys(snapshot, keys);
  }

  Future<void> markSeasonWatched(
    int id,
    int seasonNumber,
  ) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (final episode in snapshot.releasedEpisodes) {
      if (episode.seasonNumber == seasonNumber) {
        keys.add(episode.key);
      }
    }

    await _applyWatchedKeys(snapshot, keys);
  }

  Future<void> markAllReleasedEpisodesWatched(int id) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    final keys = {...snapshot.watchedKeys};

    for (final episode in snapshot.releasedEpisodes) {
      keys.add(episode.key);
    }

    await _applyWatchedKeys(snapshot, keys);
  }

  Future<void> clearEpisodeProgress(int id) async {
    final snapshot = await getSnapshot(id);
    if (snapshot == null) {
      return;
    }

    await _applyWatchedKeys(
      snapshot,
      const <String>{},
    );
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
      if (snapshot == null) {
        return;
      }

      final count = watchedEpisodes.clamp(
        0,
        snapshot.releasedEpisodes.length,
      );

      final keys = snapshot.releasedEpisodes
          .take(count)
          .map((item) => item.key)
          .toSet();

      await _applyWatchedKeys(
        snapshot,
        keys,
        totalEpisodesOverride: totalEpisodes,
      );
      return;
    }

    final updated = existing.copyWith(
      currentSeason: season < 1 ? 1 : season,
      currentEpisode: episode < 1 ? 1 : episode,
      totalEpisodes: totalEpisodes ?? existing.totalEpisodes,
      lastWatchedAt: DateTime.now(),
    );

    _replaceShow(_normalizeShow(updated));
    await _save();
  }

  Future<void> markEpisodeWatched(int id) async {
    final snapshot = await getSnapshot(id);
    final next = snapshot?.nextUnwatchedPastEpisode;

    if (next == null) {
      return;
    }

    await markEpisodeWatchedAt(
      id,
      next.seasonNumber,
      next.episodeNumber,
    );
  }  Future<void> _applyWatchedKeys(
    TvProgressSnapshot snapshot,
    Set<String> rawKeys, {
    int? totalEpisodesOverride,
  }) async {
    final allowedKeys = snapshot.allEpisodes
        .map((episode) => episode.key)
        .toSet();

    final keys = rawKeys.where(allowedKeys.contains).toSet();

    final watchedEpisodes = snapshot.releasedEpisodes
        .where((episode) => keys.contains(episode.key))
        .length;

    final watchedReleased = snapshot.releasedEpisodes
        .where((episode) => keys.contains(episode.key))
        .toList();

    final lastWatched = watchedReleased.isEmpty
        ? null
        : watchedReleased.last;

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
              tvId: tvId,
              seasonNumber: seasonNumber,
              episodeNumber: episodeNumber,
              airDate: _readDate(episode['air_date']),
            ),
          );
        }
      } catch (error) {
        debugPrint('TV catalog error for $tvId S$season: $error');
      }
    }

    _sortEpisodes(allEpisodes);
    return allEpisodes;
  }

  Future<int> _discoverSeasonCount(int tvId) async {
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
        final episodes = await _tmdbService.getSeasonEpisodes(tvId, season);

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

    return highest > 0 ? highest : fallback.clamp(0, 999);
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
    final safeKeys = show.watchedEpisodeKeys
        .where(_isEpisodeKey)
        .toSet();

    return show.copyWith(
      currentSeason: show.currentSeason < 1 ? 1 : show.currentSeason,
      currentEpisode: show.currentEpisode < 1 ? 1 : show.currentEpisode,
      watchedEpisodes: show.watchedEpisodes < 0
          ? 0
          : show.watchedEpisodes,
      totalEpisodes: show.totalEpisodes < 0
          ? 0
          : show.totalEpisodes,
      totalSeasons: show.totalSeasons < 0
          ? 0
          : show.totalSeasons,
      watchedEpisodeKeys: safeKeys,
    );
  }

  bool _isEpisodeKey(String value) {
    // Accept both old and new formats, but normalize to new:
    // Old: "${season}:${episode}"
    // New: "$tvId:s${season}e${episode}"
    if (value.contains(':s') && value.contains('e')) {
      final parts = value.split(':');
      if (parts.length != 3) {
        return false;
      }
      final tvId = int.tryParse(parts[0]);
      final seasonPart = parts[1]; // "s{season}"
      final episodePart = parts[2]; // "e{episode}"

      if (tvId == null ||
          !seasonPart.startsWith('s') ||
          !episodePart.startsWith('e')) {
        return false;
      }

      final season = int.tryParse(seasonPart.substring(1));
      final episode = int.tryParse(episodePart.substring(1));

      return season != null &&
          episode != null &&
          season > 0 &&
          episode > 0;
    }

    // Legacy format: "${season}:${episode}"
    final parts = value.split(':');
    if (parts.length != 2) {
      return false;
    }

    final season = int.tryParse(parts[0]);
    final episode = int.tryParse(parts[1]);

    return season != null &&
        episode != null &&
        season > 0 &&
        episode > 0;
  }

  Future<void> _save() async {
    try {
      await _service.save(state);
    } catch (error) {
      debugPrint('TV progress save error: $error');
    }
  }
}