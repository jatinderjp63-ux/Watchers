class Movie {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final String releaseDate;
  final double popularity;
  final String originalLanguage;
  final String mediaType;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.releaseDate,
    required this.popularity,
    required this.originalLanguage,
    required this.mediaType,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json["id"] ?? 0,

      title:
          json["title"] ??
          json["name"] ??
          "Unknown Title",

      overview:
          json["overview"] ??
          "",

      posterPath:
          json["poster_path"] ??
          "",

      backdropPath:
          json["backdrop_path"] ??
          "",

      voteAverage:
          (json["vote_average"] ?? 0).toDouble(),

      releaseDate:
          json["release_date"] ??
          json["first_air_date"] ??
          "",

      popularity:
          (json["popularity"] ?? 0).toDouble(),

      originalLanguage:
          json["original_language"] ??
          "",

      mediaType:
          json["media_type"] ??
          (json["title"] != null ? "movie" : "tv"),
    );
  }
}