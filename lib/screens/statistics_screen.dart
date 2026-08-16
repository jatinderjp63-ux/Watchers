import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_status.dart';
import '../providers/library_provider.dart';
import '../providers/tv_progress_provider.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final tvProgress = ref.watch(tvProgressProvider);

    final plannedCount =
        library.where((item) => item.status == MediaStatus.planning).length;
    final droppedCount =
        library.where((item) => item.status == MediaStatus.dropped).length;
    final watchedMovies = library
        .where((item) =>
            item.mediaType == 'movie' && item.status == MediaStatus.watched)
        .length;
    final watchedShows = library
        .where((item) =>
            item.mediaType == 'tv' && item.status == MediaStatus.watched)
        .length;
    final watchedEpisodes =
        tvProgress.fold<int>(0, (sum, item) => sum + item.watchedEpisodes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.18,
          children: [
            _StatCard(
              title: 'Planned',
              value: '$plannedCount',
              icon: Icons.bookmark_add,
            ),
            _StatCard(
              title: 'Movies Watched',
              value: '$watchedMovies',
              icon: Icons.movie,
            ),
            _StatCard(
              title: 'Shows Watched',
              value: '$watchedShows',
              icon: Icons.live_tv,
            ),
            _StatCard(
              title: 'Episodes Watched',
              value: '$watchedEpisodes',
              icon: Icons.check_circle,
            ),
            _StatCard(
              title: 'Dropped',
              value: '$droppedCount',
              icon: Icons.remove_circle,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: Theme.of(context).colorScheme.onSurface),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}