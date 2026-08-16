import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';

class HomeMediaCard extends StatelessWidget {
  final Movie movie;
  final String heroTag;
  final String primaryText;
  final String? secondaryText;
  final String? tertiaryText;
  final double? cardWidth;
  final String sourceTab;

  const HomeMediaCard({
    super.key,
    required this.movie,
    required this.heroTag,
    required this.primaryText,
    this.secondaryText,
    this.tertiaryText,
    this.cardWidth = 100,
    this.sourceTab = 'home',
  });

  String get _detailsPath {
    switch (sourceTab) {
      case 'library':
        return '/library/details';
      case 'discover':
        return '/discover/details';
      case 'profile':
        return '/profile/details';
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

  Future<void> _openDetails(BuildContext context) async {
    final posterUrl = _posterUrl;

    if (posterUrl != null) {
      // Uses the same cached-image provider as the visible card. This starts
      // decoding the poster before the route transition without changing UI.
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
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetails(context),
        child: SizedBox(
          width: cardWidth,
          child: Column(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryText,
                      maxLines: tertiaryText == null ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: titleColor,
                      ),
                    ),
                    if (secondaryText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        secondaryText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: mutedColor,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                    if (tertiaryText != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        tertiaryText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: mutedColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
          size: 28,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}