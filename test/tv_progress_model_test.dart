import 'package:flutter_test/flutter_test.dart';

import 'package:watchers/models/tv_progress.dart';

void main() {
  group('TvProgress', () {
    test('calculates progress from watched episode keys', () {
      final progress = TvProgress(
        id: 10,
        title: 'Example',
        posterPath: '',
        currentSeason: 1,
        currentEpisode: 3,
        watchedEpisodes: 99,
        totalEpisodes: 10,
        totalSeasons: 1,
        watchedEpisodeKeys: {
          '10:s1e1',
          '10:s1e2',
        },
      );

      expect(progress.progress, 0.2);
      expect(progress.isFinished, isFalse);
      expect(progress.hasStarted, isTrue);
      expect(progress.nextEpisodeLabel, 'S01 E03');
    });

    test('reports completed when watched keys reach total episodes', () {
      final progress = TvProgress(
        id: 10,
        title: 'Example',
        posterPath: '',
        currentSeason: 1,
        currentEpisode: 2,
        watchedEpisodes: 0,
        totalEpisodes: 2,
        totalSeasons: 1,
        watchedEpisodeKeys: {
          '10:s1e1',
          '10:s1e2',
        },
      );

      expect(progress.progress, 1.0);
      expect(progress.isFinished, isTrue);
      expect(progress.nextEpisodeLabel, 'Completed');
    });

    test('clamps progress to one', () {
      final progress = TvProgress(
        id: 10,
        title: 'Example',
        posterPath: '',
        currentSeason: 1,
        currentEpisode: 1,
        watchedEpisodes: 10,
        totalEpisodes: 2,
        totalSeasons: 1,
      );

      expect(progress.progress, 1.0);
    });

    test('serializes and restores watched episode keys', () {
      final original = TvProgress(
        id: 10,
        title: 'Example',
        posterPath: '/poster.jpg',
        currentSeason: 1,
        currentEpisode: 2,
        watchedEpisodes: 1,
        totalEpisodes: 4,
        totalSeasons: 1,
        watchedEpisodeKeys: {'10:s1e1'},
      );

      final restored = TvProgress.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.posterPath, original.posterPath);
      expect(restored.watchedEpisodeKeys, {'10:s1e1'});
      expect(restored.watchedEpisodes, 1);
    });

    test('filters invalid watched keys when reading JSON', () {
      final progress = TvProgress.fromJson({
        'id': 10,
        'title': 'Example',
        'posterPath': '',
        'currentSeason': 1,
        'currentEpisode': 1,
        'watchedEpisodes': 2,
        'totalEpisodes': 4,
        'totalSeasons': 1,
        'watchedEpisodeKeys': [
          '10:s1e1',
          'not-valid',
          '10:s0e1',
          '10:s1e0',
        ],
      });

      expect(progress.watchedEpisodeKeys, {'10:s1e1'});
    });
  });
}
