class MovieDetails {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String releaseDate;
  final List<String> genres;
  final double voteAverage;
  final int runtime;
  final List<String> directors;
  final List<String> createdBy;
  final int totalSeasons;
  final int totalEpisodes;

  MovieDetails({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.genres,
    required this.voteAverage,
    required this.runtime,
    required this.directors,
    required this.createdBy,
    required this.totalSeasons,
    required this.totalEpisodes,
  });

  factory MovieDetails.fromJson(Map<String, dynamic> json, String mediaType) {
    return MovieDetails(
      id: json['id'] as int,
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      posterPath: json['poster_path']?.toString() ?? '',
      backdropPath: json['backdrop_path']?.toString() ?? '',
      releaseDate: mediaType == 'movie'
          ? json['release_date']?.toString() ?? ''
          : json['first_air_date']?.toString() ?? '',
      genres: (json['genres'] as List?)
              ?.map((g) => (g as Map)['name'] as String)
              .toList() ??
          [],
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      runtime: mediaType == 'movie'
          ? json['runtime'] as int? ?? 0
          : json['episode_run_time'] is List
              ? ((json['episode_run_time'] as List).isNotEmpty
                  ? (json['episode_run_time'] as List).first as int? ?? 0
                  : 0)
              : 0,
      directors: (json['credits']?['crew'] as List?)
              ?.where((c) =>
                  (c as Map)['job']?.toString().toLowerCase() == 'director')
              .map((c) => c['name'] as String)
              .toList() ??
          [],
      createdBy: (json['created_by'] as List?)
              ?.map((c) => (c as Map)['name'] as String)
              .toList() ??
          [],
      totalSeasons: json['number_of_seasons'] as int? ?? 0,
      totalEpisodes: json['number_of_episodes'] as int? ?? 0,
    );
  }

  String get posterUrl {
    if (posterPath.isEmpty) {
      return '';
    }
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String get backdropUrl {
    if (backdropPath.isEmpty) {
      return '';
    }
    return 'https://image.tmdb.org/t/p/w1280$backdropPath';
  }

  String get formattedReleaseDate {
    if (releaseDate.isEmpty || releaseDate.length < 4) {
      return '-';
    }

    final date = DateTime.tryParse(releaseDate);
    if (date == null) {
      return releaseDate;
    }

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get formattedDirectors {
    if (directors.isEmpty) {
      return '-';
    }

    if (directors.length == 1) {
      return directors.first;
    }

    return '${directors.take(directors.length - 1).join(', ')} & ${directors.last}';
  }

  String get formattedRuntime {
    if (runtime == 0) {
      return '-';
    }

    final hours = runtime ~/ 60;
    final minutes = runtime % 60;

    if (hours == 0) {
      return '$minutes min';
    }

    if (minutes == 0) {
      return '$hours hr';
    }

    return '$hours hr $minutes min';
  }

  MovieDetails copyWith({
    int? id,
    String? title,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    List<String>? genres,
    double? voteAverage,
    int? runtime,
    List<String>? directors,
    List<String>? createdBy,
    int? totalSeasons,
    int? totalEpisodes,
  }) {
    return MovieDetails(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      genres: genres ?? this.genres,
      voteAverage: voteAverage ?? this.voteAverage,
      runtime: runtime ?? this.runtime,
      directors: directors ?? this.directors,
      createdBy: createdBy ?? this.createdBy,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
    );
  }
}