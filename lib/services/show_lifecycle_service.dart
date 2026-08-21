import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'tmdb_http_client.dart';
import 'tvmaze_service.dart';

class ShowLifecycle {
  final int tvId;
  final String statusText;
  final bool isEndedOrCanceled;
  final bool hasUpcomingEpisodes;
  final int latestKnownEpisodeCount;
  final DateTime? nextAirDate;
  final int? nextSeasonNumber;
  final int? nextEpisodeNumber;

  const ShowLifecycle({
    required this.tvId,
    required this.statusText,
    required this.isEndedOrCanceled,
    required this.hasUpcomingEpisodes,
    required this.latestKnownEpisodeCount,
    this.nextAirDate,
    this.nextSeasonNumber,
    this.nextEpisodeNumber,
  });

  bool get isFullyEnded {
    return isEndedOrCanceled && !hasUpcomingEpisodes;
  }
}

abstract class ShowLifecycleProvider {
  final Dio tmdbHttp;

  ShowLifecycleProvider(this.tmdbHttp);

  Future<ShowLifecycle?> fetch(int tvId);
}

class TmdbLifecycleProvider extends ShowLifecycleProvider {
  TmdbLifecycleProvider(super.tmdbHttp);

  @override
  Future<ShowLifecycle?> fetch(int tvId) async {
    try {
      final response = await tmdbHttp.get('/tv/$tvId');
      final data = response.data as Map<String, dynamic>;

      final statusRaw = data['status']?.toString() ?? '';
      final isEndedOrCanceled =
          statusRaw == 'Ended' || statusRaw == 'Canceled';

      DateTime? nextAirDate;
      int? nextSeasonNumber;
      int? nextEpisodeNumber;

      final nextEpisode = data['next_episode_to_air'];
      if (nextEpisode is Map<String, dynamic>) {
        final airDateStr = nextEpisode['air_date']?.toString();
        nextAirDate = airDateStr != null && airDateStr.isNotEmpty
            ? DateTime.tryParse(airDateStr)
            : null;

        nextSeasonNumber = nextEpisode['season_number'] is int
            ? nextEpisode['season_number'] as int
            : null;

        nextEpisodeNumber = nextEpisode['episode_number'] is int
            ? nextEpisode['episode_number'] as int
            : null;
      }

      final hasUpcomingEpisodes = nextAirDate != null ||
          (data['next_episode_to_air'] != null &&
              data['next_episode_to_air'] is Map<String, dynamic>);

      int latestKnownEpisodeCount = 0;
      final seasons = data['seasons'] as List? ?? [];
      for (final season in seasons) {
        if (season is! Map<String, dynamic>) continue;
        final seasonNumber = season['season_number'] as int? ?? 0;
        if (seasonNumber == 0) continue; // skip specials
        final episodeCount = season['episode_count'] as int? ?? 0;
        latestKnownEpisodeCount += episodeCount;
      }

      return ShowLifecycle(
        tvId: tvId,
        statusText: statusRaw,
        isEndedOrCanceled: isEndedOrCanceled,
        hasUpcomingEpisodes: hasUpcomingEpisodes,
        latestKnownEpisodeCount: latestKnownEpisodeCount,
        nextAirDate: nextAirDate,
        nextSeasonNumber: nextSeasonNumber,
        nextEpisodeNumber: nextEpisodeNumber,
      );
    } catch (error) {
      debugPrint('TMDB lifecycle error for TV $tvId: $error');
      return null;
    }
  }
}

class TvMazeLifecycleProvider extends ShowLifecycleProvider {
  final TvMazeService tvMaze;

  TvMazeLifecycleProvider(this.tvMaze) : super(null as Dio);

  @override
  Future<ShowLifecycle?> fetch(int tvId) async {
    // TvMazeService currently works with show names, not IDs.
    // For now, this provider is a placeholder for future integration
    // where we map TMDB ID -> TVmaze ID or search by title.
    return null;
  }
}

class ShowLifecycleService {
  final Dio tmdbHttp;
  final TvMazeService tvMaze;

  ShowLifecycleService({
    required this.tmdbHttp,
    required this.tvMaze,
  });

  Future<ShowLifecycle> getLifecycle(int tvId) async {
    final providers = [
      TmdbLifecycleProvider(tmdbHttp),
      TvMazeLifecycleProvider(tvMaze),
    ];

    ShowLifecycle? merged;

    for (final provider in providers) {
      final data = await provider.fetch(tvId);
      if (data == null) continue;

      if (merged == null) {
        merged = data;
        continue;
      }

      merged = _merge(merged, data);
    }

    if (merged != null) {
      return merged;
    }

    // Fallback minimal lifecycle if all providers fail
    return ShowLifecycle(
      tvId: tvId,
      statusText: '',
      isEndedOrCanceled: false,
      hasUpcomingEpisodes: false,
      latestKnownEpisodeCount: 0,
    );
  }

  ShowLifecycle _merge(ShowLifecycle a, ShowLifecycle b) {
    final hasUpcoming = a.hasUpcomingEpisodes || b.hasUpcomingEpisodes;
    final isEnded = a.isEndedOrCanceled && b.isEndedOrCanceled;
    final episodeCount = a.latestKnownEpisodeCount > b.latestKnownEpisodeCount
        ? a.latestKnownEpisodeCount
        : b.latestKnownEpisodeCount;

    DateTime? nextAirDate = a.nextAirDate;
    if (b.nextAirDate != null) {
      if (nextAirDate == null || b.nextAirDate!.isBefore(nextAirDate)) {
        nextAirDate = b.nextAirDate;
      }
    }

    return ShowLifecycle(
      tvId: a.tvId,
      statusText: a.statusText.isNotEmpty ? a.statusText : b.statusText,
      isEndedOrCanceled: isEnded,
      hasUpcomingEpisodes: hasUpcoming,
      latestKnownEpisodeCount: episodeCount,
      nextAirDate: nextAirDate,
      nextSeasonNumber: a.nextSeasonNumber ?? b.nextSeasonNumber,
      nextEpisodeNumber: a.nextEpisodeNumber ?? b.nextEpisodeNumber,
    );
  }
}