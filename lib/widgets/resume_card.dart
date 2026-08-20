import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final String heroTag;
  final String sourceTab;
  final bool showMediaType;

  const MovieCard({
    super.key,
    required this.movie,
    required this.heroTag,
    required this.sourceTab,
    this.showMediaType = false,
  });

  String get _detailsPath {
    switch (sourceTab) {
      case 'library':
        return '/library/details';
      case 'profile':
        return '/profile/details';
      case 'discover':
        return '/discover/details';
      default:
        return '/home/details';
    }
  }

  String? get _posterUrl {
    final path = movie.posterPath.trim();

    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return 'https://image.tmdb.org/t/p/w500$path';
  }

  String get _mediaTypeLabel {
    return movie.mediaType == 'tv' ? 'Show' : 'Movie';
  }

  Future<void> _openDetails(BuildContext context) async {
    final posterUrl = _posterUrl;

    if (posterUrl != null) {
      await precacheImage(
        CachedNetworkImageProvider(posterUrl),
        context,
      );
    }

    if (!context.mounted) {
      return;
    }

    context.push(
      _detailsPath,
      extra: {
        'movie': movie,
        'heroTag': heroTag,
        'sourceTab': sourceTab,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = _posterUrl;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetails(context),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: posterUrl == null
                        ? _posterPlaceholder(
                            context,
                            Icons.movie_outlined,
                          )
                        : CachedNetworkImage(
                            imageUrl: posterUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) {
                              return _posterPlaceholder(
                                context,
                                Icons.movie_outlined,
                              );
                            },
                            errorWidget: (context, url, error) {
                              return _posterPlaceholder(
                                context,
                                Icons.broken_image_outlined,
                              );
                            },
                            fadeInDuration: const Duration(
                              milliseconds: 150,
                            ),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: scheme.onSurface,
                ),
              ),
              if (showMediaType) ...[
                const SizedBox(height: 3),
                Text(
                  _mediaTypeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterPlaceholder(
    BuildContext context,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          icon,
          size: 30,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}