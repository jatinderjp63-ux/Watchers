import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';

class TvMazeService {
  TvMazeService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.tvMazeBaseUrl,
            headers: {
              'accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  final Dio _dio;

  Future<Response<dynamic>> _request(
    String endpoint, {
    Map<String, dynamic>? query,
  }) async {
    int attempts = 0;

    while (attempts < 2) {
      try {
        return await _dio.get(
          endpoint,
          queryParameters: query,
        );
      } catch (error) {
        attempts++;

        if (attempts >= 2) {
          rethrow;
        }

        await Future.delayed(
          const Duration(milliseconds: 400),
        );
      }
    }

    throw Exception('TVMaze request failed.');
  }

  Future<List<Map<String, dynamic>>> getEpisodesForShow(
    String title,
  ) async {
    if (title.trim().isEmpty) {
      return [];
    }

    try {
      final searchResponse = await _request(
        '/search/shows',
        query: {
          'q': title,
        },
      );

      final results = searchResponse.data;

      if (results is! List || results.isEmpty) {
        return [];
      }

      final show = _selectBestShowMatch(
        results,
        title,
      );

      if (show == null) {
        return [];
      }

      final showData = show['show'];

      if (showData is! Map) {
        return [];
      }

      final showId = showData['id'];

      if (showId is! int) {
        return [];
      }

      final episodesResponse = await _request(
        '/shows/$showId/episodes',
      );

      final episodes = episodesResponse.data;

      if (episodes is! List) {
        return [];
      }

      return episodes
          .whereType<Map>()
          .map(
            (episode) => _normalizeEpisode(
              Map<String, dynamic>.from(episode),
            ),
          )
          .where(
            (episode) =>
                episode['air_date'] != null &&
                episode['air_date'].toString().isNotEmpty,
          )
          .toList();
    } catch (error) {
      debugPrint('TVMAZE EPISODES ERROR: $error');
      return [];
    }
  }

  Map<String, dynamic>? _selectBestShowMatch(
    List<dynamic> results,
    String requestedTitle,
  ) {
    final normalizedRequestedTitle =
        _normalizeTitle(requestedTitle);

    Map<String, dynamic>? firstValidMatch;

    for (final result in results) {
      if (result is! Map) {
        continue;
      }

      final show = result['show'];

      if (show is! Map) {
        continue;
      }

      final showName = show['name'];

      if (showName is! String) {
        continue;
      }

      final candidate = <String, dynamic>{
        'show': Map<String, dynamic>.from(show),
      };

      firstValidMatch ??= candidate;

      if (_normalizeTitle(showName) == normalizedRequestedTitle) {
        return candidate;
      }
    }

    return firstValidMatch;
  }

  Map<String, dynamic> _normalizeEpisode(
    Map<String, dynamic> episode,
  ) {
    final seasonNumber = _readInt(
      episode['season'],
      fallback: 0,
    );

    final episodeNumber = _readInt(
      episode['number'],
      fallback: 0,
    );

    final airDate = episode['airdate'];

    return {
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
      'air_date': airDate is String ? airDate : '',
      'name': episode['name'] is String ? episode['name'] : '',
    };
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

  String _normalizeTitle(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
  }
}