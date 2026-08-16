import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie.dart';

class MovieCache {
  final List<Movie>? trending;
  final List<Movie>? popular;
  final List<Movie>? tvShows;
  final List<Movie>? topRatedMovies;
  final List<Movie>? topRatedTv;

  const MovieCache({
    this.trending,
    this.popular,
    this.tvShows,
    this.topRatedMovies,
    this.topRatedTv,
  });

  bool get hasDiscoverData {
    return trending != null &&
        popular != null &&
        tvShows != null &&
        topRatedMovies != null &&
        topRatedTv != null;
  }

  bool get hasData {
    return hasDiscoverData;
  }

  MovieCache copyWith({
    List<Movie>? trending,
    List<Movie>? popular,
    List<Movie>? tvShows,
    List<Movie>? topRatedMovies,
    List<Movie>? topRatedTv,
  }) {
    return MovieCache(
      trending: trending ?? this.trending,
      popular: popular ?? this.popular,
      tvShows: tvShows ?? this.tvShows,
      topRatedMovies: topRatedMovies ?? this.topRatedMovies,
      topRatedTv: topRatedTv ?? this.topRatedTv,
    );
  }
}

class MovieCacheNotifier extends Notifier<MovieCache> {
  @override
  MovieCache build() {
    return const MovieCache();
  }

  void setDiscoverData({
    required List<Movie> trending,
    required List<Movie> popular,
    required List<Movie> tvShows,
    required List<Movie> topRatedMovies,
    required List<Movie> topRatedTv,
  }) {
    state = state.copyWith(
      trending: trending,
      popular: popular,
      tvShows: tvShows,
      topRatedMovies: topRatedMovies,
      topRatedTv: topRatedTv,
    );
  }

  void clear() {
    state = const MovieCache();
  }
}

final movieCacheProvider =
    NotifierProvider<MovieCacheNotifier, MovieCache>(
  MovieCacheNotifier.new,
);