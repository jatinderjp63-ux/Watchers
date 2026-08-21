import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/tv_progress.dart';
import 'library_provider.dart';
import 'tv_progress_provider.dart';

class TvLibrarySections {
  final List<MediaLibraryItem> planned;
  final List<MediaLibraryItem> watching;
  final List<MediaLibraryItem> watched;
  final List<MediaLibraryItem> dropped;

  const TvLibrarySections({
    required this.planned,
    required this.watching,
    required this.watched,
    required this.dropped,
  });
}

final tvLibrarySectionsProvider =
    FutureProvider<TvLibrarySections>((ref) async {
  final library = ref.watch(libraryProvider);
  final progressItems = ref.watch(tvProgressProvider);
  final progressNotifier = ref.watch(tvProgressProvider.notifier);

  final progressById = <int, TvProgress>{
    for (final progress in progressItems) progress.id: progress,
  };

  final planned = <MediaLibraryItem>[];
  final watching = <MediaLibraryItem>[];
  final watched = <MediaLibraryItem>[];
  final dropped = <MediaLibraryItem>[];

  final shows = library
      .where((item) => item.mediaType == 'tv')
      .toList();

  for (final show in shows) {
    if (show.status == MediaStatus.dropped) {
      dropped.add(show);
      continue;
    }

    final progress = progressById[show.id];

    // Planned: no episodes watched yet
    if (progress == null || progress.watchedEpisodes <= 0) {
      planned.add(show);
      continue;
    }

    try {
      final snapshot = await progressNotifier.getSnapshot(show.id);

      if (snapshot == null) {
        // If we can't get snapshot, treat as Watching if started
        watching.add(show);
        continue;
      }

      final hasAnyWatched = snapshot.hasStarted;
      final allReleasedWatched = snapshot.hasFinishedReleasedEpisodes;
      final hasFuture = snapshot.hasFutureEpisodes;

      // Watched:
      // - All released episodes watched AND
      // - No future episodes/seasons expected
      if (hasAnyWatched && allReleasedWatched && !hasFuture) {
        watched.add(show);
      } else if (hasAnyWatched) {
        // Watching: at least one episode watched, but not fully done
        watching.add(show);
      } else {
        // Fallback: should not happen if progress.watchedEpisodes > 0
        planned.add(show);
      }
    } catch (_) {
      // On error, if started, keep in Watching; else Planned
      if (progress != null && progress.watchedEpisodes > 0) {
        watching.add(show);
      } else {
        planned.add(show);
      }
    }
  }

  int compareByAddedDate(
    MediaLibraryItem a,
    MediaLibraryItem b,
  ) {
    return b.addedDate.compareTo(a.addedDate);
  }

  int compareWatching(
    MediaLibraryItem a,
    MediaLibraryItem b,
  ) {
    final aProgress = progressById[a.id];
    final bProgress = progressById[b.id];

    final aTime = aProgress?.lastWatchedAt;
    final bTime = bProgress?.lastWatchedAt;

    if (aTime != null && bTime != null) {
      final timeCompare = bTime.compareTo(aTime);
      if (timeCompare != 0) {
        return timeCompare;
      }
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }

    return b.addedDate.compareTo(a.addedDate);
  }

  planned.sort(compareByAddedDate);
  watching.sort(compareWatching);
  watched.sort(compareByAddedDate);
  dropped.sort(compareByAddedDate);

  return TvLibrarySections(
    planned: planned,
    watching: watching,
    watched: watched,
    dropped: dropped,
  );
});