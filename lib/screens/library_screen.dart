import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/home_section_entry.dart';
import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../providers/library_provider.dart';
import '../providers/tv_library_sections_provider.dart';
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

    final tvSectionsAsync = ref.watch(tvLibrarySectionsProvider);

    Future<void> refreshLibrary() async {
      await ref.read(libraryProvider.notifier).loadLibrary();
      await ref.read(tvLibrarySectionsProvider.future);
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
                _MovieLibraryCategoryView(
                  items: movieItems,
                  onRefresh: refreshLibrary,
                ),
                tvSectionsAsync.when(
                  loading: () {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  error: (_, __) {
                    final tvItems = library
                        .where((item) => item.mediaType == 'tv')
                        .toList();

                    return _ShowLibraryCategoryView(
                      planned: tvItems
                          .where(
                            (item) =>
                                item.status == MediaStatus.planning,
                          )
                          .toList(),
                      watching: const [],
                      watched: tvItems
                          .where(
                            (item) =>
                                item.status == MediaStatus.watched,
                          )
                          .toList(),
                      dropped: tvItems
                          .where(
                            (item) =>
                                item.status == MediaStatus.dropped,
                          )
                          .toList(),
                      onRefresh: refreshLibrary,
                    );
                  },
                  data: (sections) {
                    return _ShowLibraryCategoryView(
                      planned: sections.planned,
                      watching: sections.watching,
                      watched: sections.watched,
                      dropped: sections.dropped,
                      onRefresh: refreshLibrary,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MovieLibraryCategoryView extends StatelessWidget {
  final List<MediaLibraryItem> items;
  final Future<void> Function() onRefresh;

  const _MovieLibraryCategoryView({
    required this.items,
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

    return _LibrarySectionsList(
      categoryTitle: 'Movies',
      sections: [
        _LibrarySectionData(
          title: 'Planned',
          items: planned,
          emptyMessage: 'Nothing planned yet.',
        ),
        _LibrarySectionData(
          title: 'Watched',
          items: watched,
          emptyMessage: 'Nothing watched yet.',
        ),
      ],
      onRefresh: onRefresh,
    );
  }
}

class _ShowLibraryCategoryView extends StatelessWidget {
  final List<MediaLibraryItem> planned;
  final List<MediaLibraryItem> watching;
  final List<MediaLibraryItem> watched;
  final List<MediaLibraryItem> dropped;
  final Future<void> Function() onRefresh;

  const _ShowLibraryCategoryView({
    required this.planned,
    required this.watching,
    required this.watched,
    required this.dropped,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return _LibrarySectionsList(
      categoryTitle: 'Shows',
      sections: [
        _LibrarySectionData(
          title: 'Planned',
          items: planned,
          emptyMessage: 'Nothing planned yet.',
        ),
        _LibrarySectionData(
          title: 'Watching',
          items: watching,
          emptyMessage: 'Start an episode to see shows here.',
        ),
        _LibrarySectionData(
          title: 'Watched',
          items: watched,
          emptyMessage: 'Nothing completed yet.',
        ),
        _LibrarySectionData(
          title: 'Dropped',
          items: dropped,
          emptyMessage: 'Nothing dropped yet.',
        ),
      ],
      onRefresh: onRefresh,
    );
  }
}

class _LibrarySectionData {
  final String title;
  final List<MediaLibraryItem> items;
  final String emptyMessage;

  const _LibrarySectionData({
    required this.title,
    required this.items,
    required this.emptyMessage,
  });
}

class _LibrarySectionsList extends StatelessWidget {
  final String categoryTitle;
  final List<_LibrarySectionData> sections;
  final Future<void> Function() onRefresh;

  const _LibrarySectionsList({
    required this.categoryTitle,
    required this.sections,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 28),
        itemBuilder: (context, index) {
          final section = sections[index];

          return _buildSection(
            context: context,
            categoryTitle: categoryTitle,
            sectionTitle: section.title,
            sectionItems: section.items,
            emptyMessage: section.emptyMessage,
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String categoryTitle,
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
                      'title': '$categoryTitle $sectionTitle',
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