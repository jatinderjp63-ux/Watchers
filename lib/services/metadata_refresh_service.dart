import 'package:flutter/foundation.dart';

/// Session-scoped cache for remote metadata.
///
/// Cached values can be displayed immediately while stale values are
/// refreshed silently by the caller.
class MetadataRefreshService {
  MetadataRefreshService._();

  static final MetadataRefreshService instance =
      MetadataRefreshService._();

  static const Duration defaultTtl = Duration(minutes: 30);

  final Map<String, _CacheEntry> _entries = {};

  T? read<T>(String key) {
    final entry = _entries[key];

    if (entry == null) {
      return null;
    }

    if (entry.value is! T) {
      debugPrint(
        'Metadata cache type mismatch for key: $key',
      );
      return null;
    }

    return entry.value as T;
  }

  DateTime? fetchedAt(String key) {
    return _entries[key]?.fetchedAt;
  }

  bool contains(String key) {
    return _entries.containsKey(key);
  }

  bool isFresh(
    String key, {
    Duration ttl = defaultTtl,
  }) {
    final timestamp = fetchedAt(key);

    if (timestamp == null) {
      return false;
    }

    return DateTime.now().difference(timestamp) < ttl;
  }

  bool isStale(
    String key, {
    Duration ttl = defaultTtl,
  }) {
    return !isFresh(key, ttl: ttl);
  }

  void write<T>(
    String key,
    T value, {
    DateTime? timestamp,
  }) {
    _entries[key] = _CacheEntry(
      value: value,
      fetchedAt: timestamp ?? DateTime.now(),
    );
  }

  void remove(String key) {
    _entries.remove(key);
  }

  void clear() {
    _entries.clear();
  }

  static String movieDetailsKey(
    int id,
    String mediaType,
  ) {
    return 'movie_details_${mediaType}_$id';
  }

  static String castKey(
    int id,
    String mediaType,
  ) {
    return 'cast_${mediaType}_$id';
  }

  static String trailersKey(int id) {
    return 'trailers_movie_$id';
  }

  static String trailerTitlesKey(int id) {
    return 'trailer_titles_movie_$id';
  }

  static String seasonEpisodesKey(
    int id,
    int seasonNumber,
  ) {
    return 'season_episodes_${id}_$seasonNumber';
  }

  static String nextAiringKey() {
    return 'next_airing';
  }
}

class _CacheEntry {
  final Object? value;
  final DateTime fetchedAt;

  const _CacheEntry({
    required this.value,
    required this.fetchedAt,
  });
}