enum EpisodeMarkingBehavior {
  previousReleased,
  onlyThisEpisode,
  askEveryTime,
}

enum EpisodeUnmarkingBehavior {
  laterReleased,
  onlyThisEpisode,
  askEveryTime,
}

enum SeasonMarkingBehavior {
  previousReleased,
  onlyThisSeason,
  askEveryTime,
}

enum SeasonUnmarkingBehavior {
  laterReleased,
  onlyThisSeason,
  askEveryTime,
}

class WatchProgressSettings {
  final EpisodeMarkingBehavior episodeMarking;
  final EpisodeUnmarkingBehavior episodeUnmarking;
  final SeasonMarkingBehavior seasonMarking;
  final SeasonUnmarkingBehavior seasonUnmarking;

  const WatchProgressSettings({
    this.episodeMarking = EpisodeMarkingBehavior.previousReleased,
    this.episodeUnmarking = EpisodeUnmarkingBehavior.laterReleased,
    this.seasonMarking = SeasonMarkingBehavior.previousReleased,
    this.seasonUnmarking = SeasonUnmarkingBehavior.laterReleased,
  });

  WatchProgressSettings copyWith({
    EpisodeMarkingBehavior? episodeMarking,
    EpisodeUnmarkingBehavior? episodeUnmarking,
    SeasonMarkingBehavior? seasonMarking,
    SeasonUnmarkingBehavior? seasonUnmarking,
  }) {
    return WatchProgressSettings(
      episodeMarking: episodeMarking ?? this.episodeMarking,
      episodeUnmarking: episodeUnmarking ?? this.episodeUnmarking,
      seasonMarking: seasonMarking ?? this.seasonMarking,
      seasonUnmarking: seasonUnmarking ?? this.seasonUnmarking,
    );
  }
}
