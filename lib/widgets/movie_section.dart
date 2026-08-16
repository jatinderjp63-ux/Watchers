import 'package:flutter/material.dart';

import '../models/movie.dart';
import 'movie_card.dart';

class MovieSection extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final String sourceTab;

  const MovieSection({
    super.key,
    required this.title,
    required this.movies,
    required this.sourceTab,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 214,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];

              return Padding(
                padding: EdgeInsets.only(
                  right: index == movies.length - 1 ? 0 : 12,
                ),
                child: MovieCard(
                  movie: movie,
                  heroTag: '$title-${movie.id}',
                  sourceTab: sourceTab,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}