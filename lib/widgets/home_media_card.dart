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
  final bool isWatched;
  final String sourceTab;
  final double cardWidth;

  const HomeMediaCard({
    super.key,
    required this.movie,
    required this.heroTag,
    required this.primaryText,
    this.secondaryText,
    this.tertiaryText,
    this.isWatched = false,
    required this.sourceTab,
    this.cardWidth = 112,
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

  void _openDetails(BuildContext context) {
    final posterUrl = _posterUrl;

    // Best-effort precache only. Routing must never wait for a network
    // request or image decode.
    if (posterUrl != null) {
      precacheImage(
        CachedNetworkImageProvider(posterUrl),
        context,
      ).catchError((_) {});
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
    final titleColor = scheme.onSurface;
    final mutedColor = scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetails(context),
        child: SizedBox(
          width: cardWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
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
                                placeholder: (_, __) {
                                  return _posterPlaceholder(
                                    context,
                                    Icons.movie_outlined,
                                  );
                                },
                                errorWidget: (_, __, ___) {
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
                  if (isWatched)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2EAF62),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                primaryText,
                maxLines: tertiaryText == null ? 2 : 1,
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
                  maxLines: 1,
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