import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/tv_progress.dart';

class ResumeCard extends StatelessWidget {
  final TvProgress show;
  final VoidCallback? onTap;

  const ResumeCard({
    super.key,
    required this.show,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final posterUrl = show.posterPath.isEmpty
        ? null
        : "https://image.tmdb.org/t/p/w500${show.posterPath}";

    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final progressText =
        "${show.watchedEpisodes}/${show.totalEpisodes > 0 ? show.totalEpisodes : "?"} episodes";
    final statusLabel = show.isFinished ? "Status" : "Next episode";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 240,
          margin: const EdgeInsets.only(right: 12),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: posterUrl == null
                        ? _posterPlaceholder(context)
                        : CachedNetworkImage(
                            imageUrl: posterUrl,
                            width: 54,
                            height: 78,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _posterLoading(context),
                            errorWidget: (context, url, error) =>
                                _posterPlaceholder(context),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          show.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          show.nextEpisodeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: show.progress,
                            minHeight: 5,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          progressText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _posterLoading(BuildContext context) {
    return Container(
      width: 54,
      height: 78,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _posterPlaceholder(BuildContext context) {
    return Container(
      width: 54,
      height: 78,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}