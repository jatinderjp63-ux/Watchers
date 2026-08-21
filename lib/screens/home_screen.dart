import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/home_section_entry.dart';
import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../models/tv_progress.dart';
import '../providers/library_provider.dart';
import '../providers/next_airing_provider.dart';
import '../providers/tv_progress_provider.dart';
import '../services/tab_navigation_service.dart';
import '../widgets/home_media_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();

  static const int _previewCount = 6;

  @override
  void initState() {
    super.initState();

    TabNavigationService.homeTapSignal.addListener(_scrollToTop);
  }

  @override
  void dispose() {
    TabNavigationService.homeTapSignal.removeListener(_scrollToTop);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients || _scrollController.offset <= 0) {
      return;
    }

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final tvProgress = ref.watch(tvProgressProvider);
    final nextAiringAsync = ref.watch(nextAiringProvider);

    final upcomingMovies = _buildUpcomingMovies(library);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(libraryProvider.notifier).loadLibrary();
          await ref.read(tvProgressProvider.notifier).load();
          ref.invalidate(nextAiringProvider);
        },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Home',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 20),
            nextAiringAsync.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () {
                return _buildHomeWithResume(
                  context,
                  library: library,
                  tvProgress: tvProgress,
                  upcomingMovies: upcomingMovies,
                  airingItems: const [],
                  resumeItems: const [],
                  isAiringLoading: true,
                  isResumeLoading: true,
                );
              },
              error: (_, __) {
                return _buildHomeWithResume(
                  context,
                  library: library,
                  tvProgress: tvProgress,
                  upcomingMovies: upcomingMovies,
                  airingItems: const [],
                  resumeItems: const [],
                  showAiringError: true,
                );
              },
              data: (items) {
                return _buildHomeWithResume(
                  context,
                  library: library,
                  tvProgress: tvProgress,
                  upcomingMovies: upcomingMovies,
                  airingItems: _buildAiringEntries(items),
                  resumeItems: _buildResumeEntries(library, tvProgress),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeWithResume(
    BuildContext context, {
    required List<MediaLibraryItem> library,
    required List<TvProgress> tvProgress,
    required List<HomeSectionEntry> upcomingMovies,
    required List<HomeSectionEntry> airingItems,
    required List<HomeSectionEntry> resumeItems,
    bool isAiringLoading = false,
    bool isResumeLoading = false,
    bool showAiringError = false,
  }) {
    final isAiringEmpty = airingItems.isEmpty && !showAiringError && !isAiringLoading;
    final isResumeEmpty = resumeItems.isEmpty && !isResumeLoading;

    final hasAnySection =
        airingItems.isNotEmpty ||
        upcomingMovies.isNotEmpty ||
        resumeItems.isNotEmpty;

    if (isAiringLoading && isResumeLoading && upcomingMovies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAiringError)
          _ErrorBlock(
            onRetry: () {
              ref.invalidate(nextAiringProvider);
            },
          ),
        if (!hasAnySection &&
            !showAiringError &&
            !isAiringLoading &&
            !isResumeLoading)
          _buildEmptyState(
            context,
            icon: Icons.home_outlined,
            title: 'Nothing on Home yet',
            subtitle:
                'Upcoming episodes, planned movies, '
                'and shows to resume will appear here.',
          ),
        if (airingItems.isNotEmpty)
          _buildSection(
            context,
            title: 'Airing',
            items: airingItems,
          ),
        if (isAiringEmpty)
          _buildAiringEmptyState(context, scheme: scheme),
        if (upcomingMovies.isNotEmpty)
          _buildSection(
            context,
            title: 'Movies',
            items: upcomingMovies,
          ),
        if (isResumeLoading && resumeItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        if (resumeItems.isNotEmpty)
          _buildSection(
            context,
            title: 'Resume',
            items: resumeItems,
          ),
      ],
    );
  }

  List<HomeSectionEntry> _buildAiringEntries(
    List<NextAiringItem> items,
  ) {
    return items.map((item) {
      final isToday = _isToday(item.airDate);

      return HomeSectionEntry(
        movie: item.show,
        heroTag:
            'home-airing-${item.show.id}-'
            '${item.seasonNumber}-'
            '${item.episodeNumber}',
        primaryText: _episodeLabel(
          season: item.seasonNumber,
          episode: item.episodeNumber,
        ),
        secondaryText: isToday ? 'Today' : _relativeFromToday(item.airDate),
        tertiaryText: _formatDate(item.airDate),
        isWatched: item.isWatched,
      );
    }).toList();
  }

  List<HomeSectionEntry> _buildResumeEntries(
    List<MediaLibraryItem> library,
    List<TvProgress> progressItems,
  ) {
    final activeShowIds = library
        .where(
          (item) =>
              item.mediaType == 'tv' &&
              item.status != MediaStatus.dropped,
        )
        .map((item) => item.id)
        .toSet();

    final itemById = <int, MediaLibraryItem>{
      for (final item in library) item.id: item,
    };

    final notifier = ref.read(tvProgressProvider.notifier);

    final startedShows = progressItems
        .where(
          (progress) =>
              activeShowIds.contains(progress.id) &&
              progress.watchedEpisodes > 0,
        )
        .toList()
      ..sort((a, b) {
        final aTime = a.lastWatchedAt;
        final bTime = b.lastWatchedAt;

        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        }

        if (aTime != null) {
          return -1;
        }

        if (bTime != null) {
          return 1;
        }

        return a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            );
      });

    final entries = <HomeSectionEntry>[];

    for (final progress in startedShows) {
      final libraryItem = itemById[progress.id];
      if (libraryItem == null) {
        continue;
      }

      // For now, use a placeholder label; the exact next episode
      // can be resolved in a more advanced version via a provider.
      entries.add(
        HomeSectionEntry(
          movie: _movieFromLibraryItem(libraryItem),
          heroTag: 'home-resume-${progress.id}',
          primaryText: 'Next Episode',
          isWatched: false,
        ),
      );
    }

    return entries;
  }

  List<HomeSectionEntry> _buildUpcomingMovies(
    List<MediaLibraryItem> library,
  ) {
    final today = _todayOnly();

    final items = library.where((item) {
      if (item.mediaType != 'movie') {
        return false;
      }

      if (item.status != MediaStatus.planning) {
        return false;
      }

      final releaseDate = item.releaseDate;
      if (releaseDate == null) {
        return false;
      }

      final dateOnly = DateTime(
        releaseDate.year,
        releaseDate.month,
        releaseDate.day,
      );

      return !dateOnly.isBefore(today);
    }).toList()
      ..sort(
        (a, b) => a.releaseDate!.compareTo(b.releaseDate!),
      );

    return items.map((item) {
      final releaseDate = item.releaseDate!;

      return HomeSectionEntry(
        movie: _movieFromLibraryItem(item),
        heroTag: 'home-movie-${item.id}',
        primaryText: item.title,
        secondaryText: _relativeFromToday(releaseDate),
        tertiaryText: _formatDate(releaseDate),
        isWatched: false,
      );
    }).toList();
  }

  Widget _buildAiringEmptyState(
    BuildContext context, {
    required ColorScheme scheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            child: Text(
              'Airing',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No upcoming episodes for your tracked shows.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<HomeSectionEntry> items,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final previewItems = items.take(_previewCount).toList();

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                context.push(
                  '/home/section',
                  extra: {
                    'title': title,
                    'items': items,
                    'sourceTab': 'home',
                  },
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: title == 'Resume' ? 214 : 270,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: previewItems.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(width: 14);
                },
                itemBuilder: (context, index) {
                  final entry = previewItems[index];

                  return HomeMediaCard(
                    movie: entry.movie,
                    heroTag: entry.heroTag,
                    primaryText: entry.primaryText,
                    secondaryText: entry.secondaryText,
                    tertiaryText: entry.tertiaryText,
                    isWatched: entry.isWatched,
                    sourceTab: 'home',
                    cardWidth: 150,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 52),
      child: Column(
        children: [
          Icon(
            icon,
            size: 56,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static Movie _movieFromLibraryItem(
    MediaLibraryItem item,
  ) {
    return Movie(
      id: item.id,
      title: item.title,
      overview: '',
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      voteAverage: 0,
      releaseDate: item.releaseDate?.toIso8601String() ?? '',
      popularity: 0,
      originalLanguage: '',
      mediaType: item.mediaType,
    );
  }

  static String _episodeLabel({
    required int season,
    required int episode,
  }) {
    final formattedSeason = season.toString().padLeft(2, '0');
    final formattedEpisode = episode.toString().padLeft(2, '0');

    return 'S$formattedSeason E$formattedEpisode';
  }

  static DateTime _todayOnly() {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly == today;
  }

  static String _relativeFromToday(
    DateTime date,
  ) {
    final today = _todayOnly();

    final target = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final difference = target.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference <= 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Tomorrow';
    }

    if (difference < 7) {
      return 'In $difference days';
    }

    if (difference < 14) {
      return 'In 1 week';
    }

    if (difference < 30) {
      return 'In ${(difference / 7).floor()} weeks';
    }

    if (difference < 60) {
      return 'In 1 month';
    }

    if (difference < 365) {
      return 'In ${(difference / 30).floor()} months';
    }

    if (difference < 730) {
      return 'In 1 year';
    }

    return 'In ${(difference / 365).floor()} years';
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _ErrorBlock extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBlock({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'Failed to load airing data.',
              style: TextStyle(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}