import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_status.dart';
import '../models/movie.dart';
import 'library_provider.dart';
import 'tv_progress_provider.dart';

class NextAiringItem {
  final Movie show;
  final DateTime airDate;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeName;
  final bool isWatched;

  const NextAiringItem({
    required this.show,
    required this.airDate,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeName,
    required this.isWatched,
  });
}

final nextAiringProvider =
    FutureProvider<List<NextAiringItem>>((ref) async {
  final library = ref.watch(libraryProvider);
  final progressNotifier = ref.watch(tvProgressProvider.notifier);

  final trackedShows = library.where((item) {
    return item.mediaType == 'tv' &&
        item.status != MediaStatus.dropped;
  }).toList();

  final items = <NextAiringItem>[];

  for (final item in trackedShows) {
    try {
      // Airing must work even before the user has created TV progress
      // by opening Episodes or marking an episode.
      final snapshot = await progressNotifier.getSnapshotForShow(
        id: item.id,
        title: item.title,
        posterPath: item.posterPath,
      );

      if (snapshot.airingEpisodes.isEmpty) {
        continue;
      }

      // One upcoming/today episode per show on Home. The catalog is sorted,
      // so today appears first, otherwise the nearest future episode.
      final episode = snapshot.airingEpisodes.first;
      final airDate = episode.airDate;

      if (airDate == null) {
        continue;
      }

      items.add(
        NextAiringItem(
          show: Movie(
            id: item.id,
            title: item.title,
            overview: '',
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            voteAverage: 0,
            releaseDate: item.releaseDate?.toIso8601String() ?? '',
            popularity: 0,
            originalLanguage: '',
            mediaType: 'tv',
          ),
          airDate: airDate,
          seasonNumber: episode.seasonNumber,
          episodeNumber: episode.episodeNumber,
          episodeName: '',
          isWatched: snapshot.isEpisodeWatched(
  '${episode.tvId}:s${episode.seasonNumber}e${episode.episodeNumber}',
),
        ),
      );
    } catch (_) {
      // A single failing TMDB show request must not make Home fail.
      continue;
    }
  }

  items.sort((a, b) {
    final dateCompare = a.airDate.compareTo(b.airDate);

    if (dateCompare != 0) {
      return dateCompare;
    }

    final showCompare = a.show.title.toLowerCase().compareTo(
          b.show.title.toLowerCase(),
        );

    if (showCompare != 0) {
      return showCompare;
    }

    if (a.seasonNumber != b.seasonNumber) {
      return a.seasonNumber.compareTo(b.seasonNumber);
    }

    return a.episodeNumber.compareTo(b.episodeNumber);
  });

  return items;
});