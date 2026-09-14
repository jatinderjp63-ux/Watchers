import '../models/media_status.dart';
import 'tv_progress_provider.dart';

enum TvDisplayStatus {
  planned,
  watching,
  watched,
  dropped,
}

extension TvDisplayStatusLabel on TvDisplayStatus {
  String get label {
    switch (this) {
      case TvDisplayStatus.planned:
        return 'Planned';
      case TvDisplayStatus.watching:
        return 'Watching';
      case TvDisplayStatus.watched:
        return 'Watched';
      case TvDisplayStatus.dropped:
        return 'Dropped';
    }
  }

  MediaStatus? get storedStatus {
    switch (this) {
      case TvDisplayStatus.planned:
        return MediaStatus.planning;
      case TvDisplayStatus.watching:
        return MediaStatus.watched;
      case TvDisplayStatus.watched:
        return MediaStatus.watched;
      case TvDisplayStatus.dropped:
        return MediaStatus.dropped;
    }
  }
}

TvDisplayStatus resolveTvDisplayStatus({
  required MediaStatus manualStatus,
  required TvProgressSnapshot? snapshot,
}) {
  if (manualStatus == MediaStatus.dropped) {
    return TvDisplayStatus.dropped;
  }

  if (snapshot == null || snapshot.watchedKeys.isEmpty) {
    return TvDisplayStatus.planned;
  }

  final lastWatched = _lastWatchedAnyEpisode(snapshot);

  if (lastWatched == null) {
    return TvDisplayStatus.planned;
  }

  final hasLaterEpisode = snapshot.allEpisodes.any((episode) {
    if (episode.seasonNumber > lastWatched.seasonNumber) {
      return true;
    }

    return episode.seasonNumber == lastWatched.seasonNumber &&
        episode.episodeNumber > lastWatched.episodeNumber;
  });

  return hasLaterEpisode ? TvDisplayStatus.watching : TvDisplayStatus.watched;
}

TvEpisodePosition? _lastWatchedAnyEpisode(TvProgressSnapshot snapshot) {
  final watched = snapshot.allEpisodes
      .where((episode) => snapshot.watchedKeys.contains(episode.key))
      .toList();

  if (watched.isEmpty) {
    return null;
  }

  watched.sort((a, b) {
    if (a.seasonNumber != b.seasonNumber) {
      return a.seasonNumber.compareTo(b.seasonNumber);
    }

    return a.episodeNumber.compareTo(b.episodeNumber);
  });

  return watched.last;
}
