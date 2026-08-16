class CastMember {
  final int id;
  final String name;
  final String character;
  final String profilePath;

  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    required this.profilePath,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json["id"] ?? 0,
      name: json["name"] ?? "",
      character: json["character"] ?? "",
      profilePath: json["profile_path"] ?? "",
    );
  }

  String get profileUrl {
    if (profilePath.isEmpty) {
      return "";
    }

    return "https://image.tmdb.org/t/p/w500$profilePath";
  }
}