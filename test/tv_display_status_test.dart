import 'package:flutter_test/flutter_test.dart';

import 'package:watchers/models/media_status.dart';
import 'package:watchers/models/tv_progress.dart';
import 'package:watchers/providers/tv_display_status.dart';
import 'package:watchers/providers/tv_progress_provider.dart';

void main() {
  final past = DateTime.now()
      .subtract(const Duration(days: 30))
      .toIso8601String()
      .substring(0, 10);

  final future = DateTime.now()
      .add(const Duration(days: 30))
      .toIso8601String()
      .substring(0, 10);

  TvEpisodePosition episode(
    int season,
    int number,
    String airDate,
  ) {
    return TvEpisodePosition(
      tvId: 10,
      seasonNumber: season,
      episodeNumber: number,
      airDate: DateTime.parse(airDate),
    );
  }

  TvProgressSnapshot snapshot({
    required Set<String> watched,
    required List<TvEpisodePosition> allEpisodes,
  }) {
    final released = allEpisodes
        .where((item) => item.airDate!.isBefore(DateTime.now()))
        .toList();

    final futureEpisodes = allEpisodes
        .where((item) => item.airDate!.isAfter(DateTime.now()))
        .toList();

    return TvProgressSnapshot(
      progress: TvProgress(
        id: 10,
        title: 'Example',
        posterPath: '',
        currentSeason: 1,
        currentEpisode: 1,
        watchedEpisodes: watched.length,
        totalEpisodes: allEpisodes.length,
        totalSeasons: 2,
        watchedEpisodeKeys: watched,
      ),
      releasedEpisodes: released,
      allEpisodes: allEpisodes,
      todayEpisodes: const [],
      futureEpisodes: futureEpisodes,
    );
  }

  test('planned with no progress is planned', () {
    final result = resolveTvDisplayStatus(
      manualStatus: MediaStatus.planning,
      snapshot: null,
    );

    expect(result, TvDisplayStatus.planned);
  });

  test(
      'planned with watched progress becomes watching when later episodes exist',
      () {
    final all = [
      episode(1, 1, past),
      episode(1, 2, future),
    ];

    final result = resolveTvDisplayStatus(
      manualStatus: MediaStatus.planning,
      snapshot: snapshot(
        watched: {'10:s1e1'},
        allEpisodes: all,
      ),
    );

    expect(result, TvDisplayStatus.watching);
  });

  test('watched through final catalog episode is watched', () {
    final all = [
      episode(1, 1, past),
      episode(1, 2, past),
    ];

    final result = resolveTvDisplayStatus(
      manualStatus: MediaStatus.watched,
      snapshot: snapshot(
        watched: {'10:s1e1', '10:s1e2'},
        allEpisodes: all,
      ),
    );

    expect(result, TvDisplayStatus.watched);
  });

  test('watched released episodes with a future episode is watching', () {
    final all = [
      episode(1, 1, past),
      episode(1, 2, future),
    ];

    final result = resolveTvDisplayStatus(
      manualStatus: MediaStatus.watched,
      snapshot: snapshot(
        watched: {'10:s1e1'},
        allEpisodes: all,
      ),
    );

    expect(result, TvDisplayStatus.watching);
  });

  test('dropped always remains dropped', () {
    final all = [
      episode(1, 1, past),
      episode(1, 2, future),
    ];

    final result = resolveTvDisplayStatus(
      manualStatus: MediaStatus.dropped,
      snapshot: snapshot(
        watched: {'10:s1e1'},
        allEpisodes: all,
      ),
    );

    expect(result, TvDisplayStatus.dropped);
  });

  test('dropped to planned preserves progress and derives watching', () {
    final all = [
      episode(1, 1, past),
      episode(1, 2, future),
    ];

    final result = resolveTvDisplayStatus(
      manualStatus: MediaStatus.planning,
      snapshot: snapshot(
        watched: {'10:s1e1'},
        allEpisodes: all,
      ),
    );

    expect(result, TvDisplayStatus.watching);
  });

  test('no released episodes remains planned', () {
    final all = [
      episode(1, 1, future),
    ];

    final result = resolveTvDisplayStatus(
      manualStatus: MediaStatus.planning,
      snapshot: snapshot(
        watched: const {},
        allEpisodes: all,
      ),
    );

    expect(result, TvDisplayStatus.planned);
  });
}
