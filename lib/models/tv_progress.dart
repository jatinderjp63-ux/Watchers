class TvProgress {
  final int id;
  final String title;
  final String posterPath;
  final int currentSeason;
  final int currentEpisode;
  final int watchedEpisodes;
  final int totalEpisodes;
  final int totalSeasons;
  final DateTime? lastWatchedAt;

  /// Persisted watched episode identifiers in `season:episode` form,
  /// such as `1:1`, `1:2`, or `4:1`.
  ///
  /// Existing saved progress with only `watchedEpisodes` remains readable.
  /// The provider migrates legacy counts to keys when it has TMDB episode data.
  final Set<String> watchedEpisodeKeys;

  TvProgress({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.currentSeason,
    required this.currentEpisode,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    required this.totalSeasons,
    this.lastWatchedAt,
    Set<String>? watchedEpisodeKeys,
  }) : watchedEpisodeKeys = Set.unmodifiable(
          watchedEpisodeKeys ?? const <String>{},
        );

  bool get isFinished {
    if (totalEpisodes <= 0) return false;

    if (watchedEpisodeKeys.isNotEmpty) {
      return watchedEpisodeKeys.length >= totalEpisodes;
    }

    return watchedEpisodes >= totalEpisodes;
  }

  bool get hasStarted {
    return watchedEpisodeKeys.isNotEmpty ||
        currentSeason > 1 ||
        currentEpisode > 1 ||
        watchedEpisodes > 0;
  }

  bool get usesEpisodeKeys {
    return watchedEpisodeKeys.isNotEmpty;
  }

  String get nextEpisodeLabel {
    if (isFinished) return 'Completed';

    return 'S${currentSeason.toString().padLeft(2, '0')} '
        'E${currentEpisode.toString().padLeft(2, '0')}';
  }

  double get progress {
    if (totalEpisodes <= 0) return 0.0;

    final completed = watchedEpisodeKeys.isNotEmpty
        ? watchedEpisodeKeys.length
        : watchedEpisodes;

    return (completed / totalEpisodes).clamp(0.0, 1.0);
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
    DateTime? lastWatchedAt,
    bool clearLastWatchedAt = false,
    Set<String>? watchedEpisodeKeys,
    bool clearWatchedEpisodeKeys = false,
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
      lastWatchedAt: clearLastWatchedAt
          ? null
          : (lastWatchedAt ?? this.lastWatchedAt),
      watchedEpisodeKeys: clearWatchedEpisodeKeys
          ? const <String>{}
          : (watchedEpisodeKeys ?? this.watchedEpisodeKeys),
    );
  }

  factory TvProgress.fromJson(Map<String, dynamic> json) {
    final rawKeys = json['watchedEpisodeKeys'];

    final watchedKeys = rawKeys is List
        ? rawKeys
            .map((value) => value.toString().trim())
            .where((value) => _isEpisodeKey(value))
            .toSet()
        : <String>{};

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
      lastWatchedAt: json['lastWatchedAt'] != null
          ? DateTime.tryParse(json['lastWatchedAt'].toString())
          : null,
      watchedEpisodeKeys: watchedKeys,
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
      'watchedEpisodeKeys': watchedEpisodeKeys.toList()..sort(),
      if (lastWatchedAt != null)
        'lastWatchedAt': lastWatchedAt!.toIso8601String(),
    };
  }

  static bool _isEpisodeKey(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return false;
    }

    final season = int.tryParse(parts[0]);
    final episode = int.tryParse(parts[1]);

    return season != null &&
        episode != null &&
        season > 0 &&
        episode > 0;
  }
}