import 'package:dio/dio.dart';

import '../models/cast_member.dart';
import '../models/movie.dart';
import '../models/movie_details.dart';
import '../models/person.dart';
import 'tmdb_http_client.dart';

class TmdbService {
  final Dio _client = TmdbHttpClient.instance;

  Future<List<Movie>> getPopularMovies() async {
    final response = await _client.get('/movie/popular');
    final data = response.data as Map<String, dynamic>;

    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map>()
        .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Movie>> getTopRatedMovies() async {
    final response = await _client.get('/movie/top_rated');
    final data = response.data as Map<String, dynamic>;

    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map>()
        .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Movie>> getTrendingMovies() async {
    final response = await _client.get('/trending/movie/week');
    final data = response.data as Map<String, dynamic>;

    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map>()
        .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Movie>> getPopularTvShows() async {
    final response = await _client.get('/tv/popular');
    final data = response.data as Map<String, dynamic>;

    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map>()
        .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Movie>> getTopRatedTvShows() async {
    final response = await _client.get('/tv/top_rated');
    final data = response.data as Map<String, dynamic>;

    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map>()
        .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Movie>> searchMovies(String query) async {
    final response = await _client.get(
      '/search/multi',
      queryParameters: {
        'query': query,
        'include_adult': 'false',
      },
    );

    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map>()
        .where((item) {
          final mediaType = item['media_type']?.toString() ?? '';
          return mediaType == 'movie' || mediaType == 'tv';
        })
        .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Person>> searchPeople(String query) async {
    final response = await _client.get(
      '/search/person',
      queryParameters: {
        'query': query,
        'include_adult': 'false',
      },
    );

    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map>()
        .map((item) => Person.fromJson(Map<String, dynamic>.from(item)))
        .where(
          (person) =>
              person.id > 0 && person.name.trim().isNotEmpty,
        )
        .toList();
  }

  Future<MovieDetails> getMovieDetails(
    int id,
    String mediaType,
  ) async {
    final response = await _client.get('/$mediaType/$id');
    final data = response.data as Map<String, dynamic>;

    return MovieDetails.fromJson(data, mediaType);
  }

  Future<List<CastMember>> getCast(
    int id,
    String mediaType,
  ) async {
    final response = await _client.get('/$mediaType/$id/credits');
    final data = response.data as Map<String, dynamic>;

    final cast = data['cast'] as List<dynamic>? ?? [];

    return cast
        .whereType<Map>()
        .map((item) => CastMember.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getVideos(
    int id,
    String mediaType,
  ) async {
    final response = await _client.get('/$mediaType/$id/videos');
    final data = response.data as Map<String, dynamic>;

    final videos = data['results'] as List<dynamic>? ?? [];

    return videos
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSeasonEpisodes(
    int tvId,
    int seasonNumber,
  ) async {
    final response = await _client.get(
      '/tv/$tvId/season/$seasonNumber',
    );
    final data = response.data as Map<String, dynamic>;

    final episodes = data['episodes'] as List<dynamic>? ?? [];

    return episodes
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getEpisodeDetails(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final response = await _client.get(
      '/tv/$tvId/season/$seasonNumber/episode/$episodeNumber',
    );

    final data = response.data as Map<String, dynamic>;

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getPersonDetails(
    int personId,
  ) async {
    final response = await _client.get('/person/$personId');
    final data = response.data as Map<String, dynamic>;

    return Map<String, dynamic>.from(data);
  }

  Future<List<Movie>> getPersonCombinedCredits(
    int personId,
  ) async {
    final response = await _client.get(
      '/person/$personId/combined_credits',
    );
    final data = response.data as Map<String, dynamic>;

    final cast = data['cast'] as List<dynamic>? ?? [];
    final unique = <String, Movie>{};

    for (final item in cast.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final mediaType = map['media_type']?.toString() ?? '';

      if (mediaType != 'movie' && mediaType != 'tv') {
        continue;
      }

      final id = map['id'];

      if (id is! int || id <= 0) {
        continue;
      }

      final movie = Movie.fromJson(map);
      unique['${movie.mediaType}-${movie.id}'] = movie;
    }

    final credits = unique.values.toList();

    credits.sort((a, b) {
      if (a.releaseDate.isEmpty && b.releaseDate.isEmpty) {
        return b.popularity.compareTo(a.popularity);
      }

      if (a.releaseDate.isEmpty) {
        return 1;
      }

      if (b.releaseDate.isEmpty) {
        return -1;
      }

      return b.releaseDate.compareTo(a.releaseDate);
    });

    return credits;
  }
}