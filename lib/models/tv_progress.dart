class TvProgress {
  final int id;
  final String title;
  final String posterPath;
  final int currentSeason;
  final int currentEpisode;
  final int watchedEpisodes;
  final int totalEpisodes;
  final int totalSeasons;

  TvProgress({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.currentSeason,
    required this.currentEpisode,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    required this.totalSeasons,
  });

  bool get isFinished {
    if (totalEpisodes <= 0) return false;
    return watchedEpisodes >= totalEpisodes;
  }

  bool get hasStarted {
    return currentSeason > 1 || currentEpisode > 1 || watchedEpisodes > 0;
  }

  String get nextEpisodeLabel {
    if (isFinished) return 'Completed';
    return 'S${currentSeason.toString().padLeft(2, '0')} E${currentEpisode.toString().padLeft(2, '0')}';
  }

  double get progress {
    if (totalEpisodes <= 0) return 0.0;
    return watchedEpisodes / totalEpisodes;
  }

  TvProgress copyWith({
    int? id,
    String? title,
    String? posterPath,
    int? currentSeason,
    int? currentEpisode,
    int? watchedEpisodes,
    int? totalEpisodes,
    int? totalSeasons,
  }) {
    return TvProgress(
      id: id ?? this.id,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      currentSeason: currentSeason ?? this.currentSeason,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      totalSeasons: totalSeasons ?? this.totalSeasons,
    );
  }

  factory TvProgress.fromJson(Map<String, dynamic> json) {
    return TvProgress(
      id: json['id'] is int ? json['id'] as int : 0,
      title: json['title']?.toString() ?? 'Unknown Title',
      posterPath: json['posterPath']?.toString() ?? '',
      currentSeason: json['currentSeason'] is int
          ? json['currentSeason'] as int
          : 1,
      currentEpisode: json['currentEpisode'] is int
          ? json['currentEpisode'] as int
          : 1,
      watchedEpisodes: json['watchedEpisodes'] is int
          ? json['watchedEpisodes'] as int
          : 0,
      totalEpisodes: json['totalEpisodes'] is int
          ? json['totalEpisodes'] as int
          : 0,
      totalSeasons: json['totalSeasons'] is int
          ? json['totalSeasons'] as int
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'currentSeason': currentSeason,
      'currentEpisode': currentEpisode,
      'watchedEpisodes': watchedEpisodes,
      'totalEpisodes': totalEpisodes,
      'totalSeasons': totalSeasons,
    };
  }
}