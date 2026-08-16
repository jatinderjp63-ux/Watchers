import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tv_progress.dart';
import '../services/metadata_refresh_service.dart';
import 'tmdb_service_provider.dart';
import 'tv_progress_provider.dart';
import 'tvmaze_service_provider.dart';

class NextAiringItem {
  final TvProgress show;
  final DateTime airDate;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeName;

  const NextAiringItem({
    required this.show,
    required this.airDate,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeName,
  });
}

final nextAiringProvider =
    FutureProvider<List<NextAiringItem>>((ref) async {
  final cache = MetadataRefreshService.instance;
  const cacheKey = 'next_airing';

  final cached =
      cache.read<List<NextAiringItem>>(cacheKey);

  if (cached != null &&
      cache.isFresh(cacheKey)) {
    return cached;
  }

  try {
    final tmdb = ref.watch(tmdbServiceProvider);
    final tvMaze = ref.watch(tvMazeServiceProvider);
    final trackedShows = ref.watch(tvProgressProvider);

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final activeShows = trackedShows
        .where(
          (show) =>
              show.hasStarted && !show.isFinished,
        )
        .toList();

    final List<NextAiringItem> items = [];

    for (final show in activeShows) {
      Map<String, dynamic>? nextEpisode;

      final tvMazeEpisodes =
          await tvMaze.getEpisodesForShow(
        show.title,
      );

      if (tvMazeEpisodes.isNotEmpty) {
        nextEpisode = _findUpcomingEpisode(
          tvMazeEpisodes,
          today,
          minimumSeason: show.currentSeason,
        );
      }

      if (nextEpisode == null) {
        final currentSeasonEpisodes =
            await tmdb.getSeasonEpisodes(
          show.id,
          show.currentSeason,
        );

        nextEpisode = _findUpcomingEpisode(
          currentSeasonEpisodes,
          today,
          minimumSeason: show.currentSeason,
        );
      }

      if (nextEpisode == null) {
        final nextSeasonEpisodes =
            await tmdb.getSeasonEpisodes(
          show.id,
          show.currentSeason + 1,
        );

        nextEpisode = _findUpcomingEpisode(
          nextSeasonEpisodes,
          today,
          minimumSeason: show.currentSeason + 1,
        );
      }

      if (nextEpisode == null) {
        continue;
      }

      final airDateValue =
          nextEpisode['air_date'];

      final airDate = airDateValue is String
          ? DateTime.tryParse(airDateValue)
          : null;

      if (airDate == null) {
        continue;
      }

      items.add(
        NextAiringItem(
          show: show,
          airDate: airDate,
          seasonNumber: _readInt(
            nextEpisode['season_number'],
            fallback: show.currentSeason,
          ),
          episodeNumber: _readInt(
            nextEpisode['episode_number'],
            fallback: show.currentEpisode,
          ),
          episodeName:
              nextEpisode['name'] is String
                  ? nextEpisode['name'] as String
                  : '',
        ),
      );
    }

    items.sort(
      (a, b) => a.airDate.compareTo(b.airDate),
    );

    cache.write<List<NextAiringItem>>(
      cacheKey,
      items,
    );

    return items;
  } catch (error) {
    if (cached != null) {
      return cached;
    }

    rethrow;
  }
});

Map<String, dynamic>? _findUpcomingEpisode(
  List<Map<String, dynamic>> episodes,
  DateTime today, {
  required int minimumSeason,
}) {
  final sortedEpisodes = [...episodes]
    ..sort(
      (a, b) {
        final aSeason = _readInt(
          a['season_number'],
          fallback: 0,
        );

        final bSeason = _readInt(
          b['season_number'],
          fallback: 0,
        );

        if (aSeason != bSeason) {
          return aSeason.compareTo(bSeason);
        }

        final aEpisode = _readInt(
          a['episode_number'],
          fallback: 0,
        );

        final bEpisode = _readInt(
          b['episode_number'],
          fallback: 0,
        );

        return aEpisode.compareTo(bEpisode);
      },
    );

  for (final episode in sortedEpisodes) {
    final seasonNumber = _readInt(
      episode['season_number'],
      fallback: 0,
    );

    if (seasonNumber < minimumSeason) {
      continue;
    }

    final airDateValue =
        episode['air_date'];

    if (airDateValue == null ||
        airDateValue.toString().isEmpty) {
      continue;
    }

    final airDate = DateTime.tryParse(
      airDateValue.toString(),
    );

    if (airDate == null) {
      continue;
    }

    final dateOnly = DateTime(
      airDate.year,
      airDate.month,
      airDate.day,
    );

    if (!dateOnly.isBefore(today)) {
      return episode;
    }
  }

  return null;
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

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      fallback;
}