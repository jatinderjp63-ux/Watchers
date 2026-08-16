import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/home_section_entry.dart';
import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../providers/library_provider.dart';
import '../services/tab_navigation_service.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TabNavigationService.libraryTapSignal.addListener(_scrollToTop);
  }

  @override
  void dispose() {
    TabNavigationService.libraryTapSignal.removeListener(_scrollToTop);
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

    final movieItems = library
        .where((item) => item.mediaType == 'movie')
        .toList();

    final tvItems = library
        .where((item) => item.mediaType == 'tv')
        .toList();

    Future<void> refreshLibrary() async {
      await ref.read(libraryProvider.notifier).loadLibrary();
    }

    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          body: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Library',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: TabBar(
                        labelColor: Theme.of(context).colorScheme.onSurface,
                        unselectedLabelColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: UnderlineTabIndicator(
                          borderSide: BorderSide(
                            width: 2.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          insets: const EdgeInsets.symmetric(horizontal: 28),
                        ),
                        tabs: const [
                          Tab(text: 'Movies'),
                          Tab(text: 'Shows'),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _LibraryCategoryView(
                  title: 'Movies',
                  items: movieItems,
                  includeDropped: false,
                  onRefresh: refreshLibrary,
                ),
                _LibraryCategoryView(
                  title: 'Shows',
                  items: tvItems,
                  includeDropped: true,
                  onRefresh: refreshLibrary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryCategoryView extends StatelessWidget {
  final String title;
  final List<MediaLibraryItem> items;
  final bool includeDropped;
  final Future<void> Function() onRefresh;

  const _LibraryCategoryView({
    required this.title,
    required this.items,
    required this.includeDropped,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final planned = items
        .where((item) => item.status == MediaStatus.planning)
        .toList();

    final watched = items
        .where((item) => item.status == MediaStatus.watched)
        .toList();

    final dropped = items
        .where((item) => item.status == MediaStatus.dropped)
        .toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: [
          _buildSection(
            context: context,
            sectionTitle: 'Planned',
            sectionItems: planned,
            emptyMessage: 'Nothing planned yet.',
          ),
          const SizedBox(height: 28),
          _buildSection(
            context: context,
            sectionTitle: 'Watched',
            sectionItems: watched,
            emptyMessage: 'Nothing watched yet.',
          ),
          if (includeDropped) ...[
            const SizedBox(height: 28),
            _buildSection(
              context: context,
              sectionTitle: 'Dropped',
              sectionItems: dropped,
              emptyMessage: 'Nothing dropped yet.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String sectionTitle,
    required List<MediaLibraryItem> sectionItems,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: sectionTitle,
          count: sectionItems.length,
          onTap: sectionItems.isEmpty
              ? null
              : () {
                  context.push(
                    '/library/section',
                    extra: {
                      'title': '$title $sectionTitle',
                      'items': sectionItems.map(_toEntry).toList(),
                      'sourceTab': 'library',
                    },
                  );
                },
        ),
        const SizedBox(height: 14),
        if (sectionItems.isEmpty)
          _EmptyBlock(message: emptyMessage)
        else
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 4),
              itemCount: sectionItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return _LibraryPosterCard(
                  item: sectionItems[index],
                );
              },
            ),
          ),
      ],
    );
  }

  HomeSectionEntry _toEntry(MediaLibraryItem item) {
    return HomeSectionEntry(
      movie: Movie(
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
      ),
      heroTag: 'library-${item.id}',
      primaryText: item.title,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onTap;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final content = Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: mutedColor,
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, color: mutedColor),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final String message;

  const _EmptyBlock({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _LibraryPosterCard extends StatelessWidget {
  final MediaLibraryItem item;

  const _LibraryPosterCard({
    required this.item,
  });

  String? get _posterUrl {
    final path = item.posterPath.trim();

    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return 'https://image.tmdb.org/t/p/w342$path';
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

    final movie = Movie(
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

    context.push(
      '/library/details',
      extra: {
        'movie': movie,
        'heroTag': 'library-${item.id}',
        'sourceTab': 'library',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final posterUrl = _posterUrl;

    return SizedBox(
      width: 106,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDetails(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 106,
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: posterUrl == null
                      ? const _PosterPlaceholder(
                          icon: Icons.movie_outlined,
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          width: 106,
                          height: 150,
                          fit: BoxFit.cover,
                          placeholder: (_, __) {
                            return const _PosterPlaceholder(
                              icon: Icons.movie_outlined,
                            );
                          },
                          errorWidget: (_, __, ___) {
                            return const _PosterPlaceholder(
                              icon: Icons.broken_image_outlined,
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  final IconData icon;

  const _PosterPlaceholder({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 106,
      height: 150,
      color: scheme.surfaceContainerHighest,
      child: Icon(
        icon,
        color: scheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }
}