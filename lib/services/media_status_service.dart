import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_status.dart';

class MediaStatusService {
  static const String _keyPrefix = "media_status_";
  static const String _trackedMediaKey = "tracked_media_ids";

  Future<void> setStatus(
    int mediaId,
    MediaStatus status,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "$_keyPrefix$mediaId",
      status.name,
    );

    await _addTrackedMedia(mediaId);
  }

  Future<MediaStatus?> getStatus(
    int mediaId,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getString(
      "$_keyPrefix$mediaId",
    );

    if (value == null) {
      return null;
    }

    switch (value) {
      case "planning":
        return MediaStatus.planning;
      case "watched":
        return MediaStatus.watched;
      case "completed":
        return MediaStatus.watched;
      case "dropped":
        return MediaStatus.dropped;
      default:
        return MediaStatus.planning;
    }
  }

  Future<void> removeStatus(
    int mediaId,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(
      "$_keyPrefix$mediaId",
    );

    final ids = prefs.getStringList(_trackedMediaKey) ?? [];

    ids.remove(mediaId.toString());

    await prefs.setStringList(
      _trackedMediaKey,
      ids,
    );
  }

  Future<void> _addTrackedMedia(
    int mediaId,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final ids = prefs.getStringList(_trackedMediaKey) ?? [];

    if (!ids.contains(mediaId.toString())) {
      ids.add(mediaId.toString());

      await prefs.setStringList(
        _trackedMediaKey,
        ids,
      );
    }
  }

  Future<int> getWatchedCount() async {
    final prefs = await SharedPreferences.getInstance();

    final ids = prefs.getStringList(_trackedMediaKey) ?? [];

    int count = 0;

    for (final id in ids) {
      final status = prefs.getString(
        "$_keyPrefix$id",
      );

      if (status == MediaStatus.watched.name || status == "completed") {
        count++;
      }
    }

    return count;
  }

  Future<int> getWatchlistCount() async {
    final prefs = await SharedPreferences.getInstance();

    final ids = prefs.getStringList(_trackedMediaKey) ?? [];

    int count = 0;

    for (final id in ids) {
      final status = prefs.getString(
        "$_keyPrefix$id",
      );

      if (status == MediaStatus.planning.name) {
        count++;
      }
    }

    return count;
  }
}