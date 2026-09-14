import 'package:flutter_test/flutter_test.dart';

import 'package:watchers/models/tv_progress.dart';
import 'package:watchers/providers/tv_progress_provider.dart';
import 'package:watchers/services/tmdb_service.dart';
import 'package:watchers/services/tv_progress_service.dart';

void main() {
  const tvId = 10;

  late List<TvProgress> stored;
  late List<Map<String, dynamic>> episodes;

  TvProgress makeProgress({
    Set<String> watched = const {},
  }) {
    return TvProgress(
      id: tvId,
      title: 'Example Show',
      posterPath: '',
      currentSeason: 1,
      currentEpisode: 1,
      watchedEpisodes: watched.length,
      totalEpisodes: episodes.length,
      totalSeasons: 2,
      watchedEpisodeKeys: watched,
    );
  }

  Future<TvProgressNotifier> createNotifier({
    Set<String> watched = const {},
  }) async {
    stored = [makeProgress(watched: watched)];

    final notifier = TvProgressNotifier(
      TvProgressService(),
      TmdbService(),
      loadProgress: () async => stored,
      saveProgress: (shows) async {
        stored = List<TvProgress>.from(shows);
      },
      loadSeasonCount: (_) async => 2,
      loadSeasonEpisodes: (_, season) async {
        return episodes
            .where((episode) => episode['season_number'] == season)
            .toList();
      },
    );

    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  setUp(() {
    final past = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10);

    final future = DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10);

    episodes = [
      {
        'season_number': 1,
        'episode_number': 1,
        'air_date': past,
      },
      {
        'season_number': 1,
        'episode_number': 2,
        'air_date': past,
      },
      {
        'season_number': 2,
        'episode_number': 1,
        'air_date': past,
      },
      {
        'season_number': 2,
        'episode_number': 2,
        'air_date': future,
      },
    ];
  });

  group('TvProgressNotifier episode cascades', () {
    test('marks only the selected released episode', () async {
      final notifier = await createNotifier();

      await notifier.markSingleEpisodeWatched(
        tvId: tvId,
        seasonNumber: 1,
        episodeNumber: 2,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        {'10:s1e2'},
      );
    });

    test('marks selected episode and earlier episodes across seasons',
        () async {
      final notifier = await createNotifier();

      await notifier.markWatchedUpToEpisode(
        tvId: tvId,
        seasonNumber: 2,
        episodeNumber: 1,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        {
          '10:s1e1',
          '10:s1e2',
          '10:s2e1',
        },
      );
    });

    test('marks previous seasons and selected episode', () async {
      final notifier = await createNotifier();

      await notifier.markWatchedUpToEpisodeIncludingPreviousSeasons(
        tvId: tvId,
        seasonNumber: 2,
        episodeNumber: 1,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        {
          '10:s1e1',
          '10:s1e2',
          '10:s2e1',
        },
      );
    });

    test('unmarks only the selected episode', () async {
      final notifier = await createNotifier(
        watched: {
          '10:s1e1',
          '10:s1e2',
          '10:s2e1',
        },
      );

      await notifier.markSingleEpisodeUnwatched(
        tvId: tvId,
        seasonNumber: 1,
        episodeNumber: 2,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        {
          '10:s1e1',
          '10:s2e1',
        },
      );
    });

    test('unmarks the current and later released episodes', () async {
      final notifier = await createNotifier(
        watched: {
          '10:s1e1',
          '10:s1e2',
          '10:s2e1',
        },
      );

      await notifier.markUnwatchedFromEpisodeIncludingFutureSeasons(
        tvId: tvId,
        seasonNumber: 1,
        episodeNumber: 2,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        {'10:s1e1'},
      );
    });

    test('does not mark an unreleased episode', () async {
      final notifier = await createNotifier();

      await notifier.markSingleEpisodeWatched(
        tvId: tvId,
        seasonNumber: 2,
        episodeNumber: 2,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        isEmpty,
      );
    });
  });

  group('TvProgressNotifier season cascades', () {
    test('marks only the selected season', () async {
      final notifier = await createNotifier();

      await notifier.markSingleSeasonWatched(
        tvId: tvId,
        seasonNumber: 1,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        {
          '10:s1e1',
          '10:s1e2',
        },
      );
    });

    test('marks selected and previous seasons', () async {
      final notifier = await createNotifier();

      await notifier.markSeasonWatchedIncludingPreviousSeasons(
        tvId: tvId,
        seasonNumber: 2,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        {
          '10:s1e1',
          '10:s1e2',
          '10:s2e1',
        },
      );
    });

    test('unmarks only the selected season', () async {
      final notifier = await createNotifier(
        watched: {
          '10:s1e1',
          '10:s1e2',
          '10:s2e1',
        },
      );

      await notifier.markSingleSeasonUnwatched(
        tvId: tvId,
        seasonNumber: 1,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        {'10:s2e1'},
      );
    });

    test('unmarks selected and later seasons', () async {
      final notifier = await createNotifier(
        watched: {
          '10:s1e1',
          '10:s1e2',
          '10:s2e1',
        },
      );

      await notifier.markSeasonUnwatchedIncludingFutureSeasons(
        tvId: tvId,
        seasonNumber: 1,
      );

      expect(
        notifier.getShowById(tvId)!.watchedEpisodeKeys,
        isEmpty,
      );
    });
  });
}
