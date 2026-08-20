import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';

class ActorFilmographyScreen extends StatelessWidget {
  final String personName;
  final String mediaType;
  final List<Movie> items;

  const ActorFilmographyScreen({
    super.key,
    required this.personName,
    required this.mediaType,
    required this.items,
  });

  String get _title => mediaType == 'tv' ? 'Shows' : 'Movies';

  String? _posterUrl(Movie movie) {
    final path = movie.posterPath.trim();

    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return 'https://image.tmdb.org/t/p/w500$path';
  }

  void _openDetails(
    BuildContext context,
    Movie movie,
    int index,
  ) {
    context.push(
      '/discover/details',
      extra: {
        'movie': movie,
        'heroTag': 'actor-$mediaType-${movie.id}-$index',
        'sourceTab': 'discover',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No $_title available for $personName.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 18,
                childAspectRatio: 0.53,
              ),
              itemBuilder: (context, index) {
                final movie = items[index];
                final posterUrl = _posterUrl(movie);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openDetails(context, movie, index),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'actor-$mediaType-${movie.id}-$index',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: posterUrl == null
                                  ? _posterPlaceholder(
                                      context,
                                      Icons.movie_outlined,
                                    )
                                  : Image.network(
                                      posterUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        return _posterPlaceholder(
                                          context,
                                          Icons.broken_image_outlined,
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _posterPlaceholder(
    BuildContext context,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: scheme.onSurfaceVariant,
        size: 30,
      ),
    );
  }
}