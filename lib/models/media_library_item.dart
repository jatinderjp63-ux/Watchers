import 'media_status.dart';

class MediaLibraryItem {
  final int id;
  final String title;
  final String posterPath;
  final String backdropPath;
  final String mediaType;
  final MediaStatus status;
  final int currentSeason;
  final int currentEpisode;
  final DateTime addedDate;
  final DateTime? releaseDate;

  const MediaLibraryItem({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.mediaType,
    required this.status,
    this.currentSeason = 0,
    this.currentEpisode = 0,
    required this.addedDate,
    this.releaseDate,
  });

  factory MediaLibraryItem.fromJson(Map<String, dynamic> json) {
    final statusString = json["status"]?.toString() ?? "planning";

    MediaStatus parsedStatus;
    switch (statusString) {
      case "planning":
        parsedStatus = MediaStatus.planning;
        break;
      case "watched":
        parsedStatus = MediaStatus.watched;
        break;
      case "dropped":
        parsedStatus = MediaStatus.dropped;
        break;
      case "completed":
        parsedStatus = MediaStatus.watched;
        break;
      case "watching":
        parsedStatus = MediaStatus.watched;
        break;
      case "onHold":
        parsedStatus = MediaStatus.dropped;
        break;
      default:
        parsedStatus = MediaStatus.planning;
    }

    return MediaLibraryItem(
      id: json["id"] ?? 0,
      title: json["title"] ?? "",
      posterPath: json["posterPath"] ?? "",
      backdropPath: json["backdropPath"] ?? "",
      mediaType: json["mediaType"] ?? "movie",
      status: parsedStatus,
      currentSeason: json["currentSeason"] ?? 0,
      currentEpisode: json["currentEpisode"] ?? 0,
      addedDate: DateTime.tryParse(json["addedDate"] ?? "") ?? DateTime.now(),
      releaseDate: DateTime.tryParse(json["releaseDate"] ?? ""),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "posterPath": posterPath,
      "backdropPath": backdropPath,
      "mediaType": mediaType,
      "status": status.name,
      "currentSeason": currentSeason,
      "currentEpisode": currentEpisode,
      "addedDate": addedDate.toIso8601String(),
      "releaseDate": releaseDate?.toIso8601String(),
    };
  }

  MediaLibraryItem copyWith({
    MediaStatus? status,
    int? currentSeason,
    int? currentEpisode,
    DateTime? releaseDate,
    bool clearReleaseDate = false,
  }) {
    return MediaLibraryItem(
      id: id,
      title: title,
      posterPath: posterPath,
      backdropPath: backdropPath,
      mediaType: mediaType,
      status: status ?? this.status,
      currentSeason: currentSeason ?? this.currentSeason,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      addedDate: addedDate,
      releaseDate: clearReleaseDate ? null : (releaseDate ?? this.releaseDate),
    );
  }
}