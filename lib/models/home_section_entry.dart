import 'movie.dart';

class HomeSectionEntry {
  final Movie movie;
  final String heroTag;
  final String primaryText;
  final String? secondaryText;
  final String? tertiaryText;

  const HomeSectionEntry({
    required this.movie,
    required this.heroTag,
    required this.primaryText,
    this.secondaryText,
    this.tertiaryText,
  });
}