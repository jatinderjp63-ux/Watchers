import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../models/tv_progress.dart';
import '../services/metadata_refresh_service.dart';
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
  final cache = MetadataRefreshService.instance;
  const cacheKey = 'next_airing';

  final cached = cache.read<List<NextAiringItem>>(cacheKey);

  if (cached != null && cache.isFresh(cacheKey)) {
    return cached;
  }

  try {
    final library = ref.watch(libraryProvider);
    final progressItems = ref.watch(tvProgressProvider);
    final progressNotifier = ref.watch(tvProgressProvider.notifier);

    final progressById = <int, TvProgress>{
      for (final progress in progressItems) progress.id: progress,
    };

    final trackedShows = library.where((item) {
      return item.mediaType == 'tv' &&
          item.status != MediaStatus.dropped;
    }).toList();

    final items = <NextAiringItem>[];

    for (final item in trackedShows) {
      final progress = progressById[item.id];
      if (progress == null) {
        continue;
      }

      final snapshot = await progressNotifier.getSnapshot(item.id);
      if (snapshot == null) {
        continue;
      }

      final airingEpisodes = snapshot.airingEpisodes;
      if (airingEpisodes.isEmpty) {
        continue;
      }

      // Use the first airing episode
      final episode = airingEpisodes.first;
      if (episode.airDate == null) {
        continue;
      }

      final isWatched = snapshot.isEpisodeWatched(
        episode.seasonNumber,
        episode.episodeNumber,
      );

      final show = Movie(
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
      );

      items.add(
        NextAiringItem(
          show: show,
          airDate: episode.airDate!,
          seasonNumber: episode.seasonNumber,
          episodeNumber: episode.episodeNumber,
          episodeName: '',
          isWatched: isWatched,
        ),
      );
    }

    items.sort(
      (a, b) => a.airDate.compareTo(b.airDate),
    );

    cache.write<List<NextAiringItem>>(
      cacheKey,
      items,
    );

    return items;
  } catch (error) {
    if (cached != null) {
      return cached;
    }

    rethrow;
  }
});