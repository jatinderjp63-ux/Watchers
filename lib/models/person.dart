class Person {
  final int id;
  final String name;
  final String profilePath;
  final String knownForDepartment;

  const Person({
    required this.id,
    required this.name,
    required this.profilePath,
    required this.knownForDepartment,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name']?.toString() ?? '',
      profilePath: json['profile_path']?.toString() ?? '',
      knownForDepartment: json['known_for_department']?.toString() ?? '',
    );
  }

  String? get profileUrl {
    final path = profilePath.trim();

    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return 'https://image.tmdb.org/t/p/w185$path';
  }
}