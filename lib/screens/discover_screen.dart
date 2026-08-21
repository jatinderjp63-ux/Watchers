import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../models/person.dart';
import '../providers/tmdb_service_provider.dart';
import '../services/retry_helper.dart';
import '../services/tab_navigation_service.dart';
import '../widgets/movie_card.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() {
    return _DiscoverScreenState();
  }
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Movie> discoverItems = [];
  List<Movie> searchResults = [];
  List<Person> personResults = [];

  bool isSearching = false;
  bool isLoadingDiscover = false;
  bool isLoadingSearch = false;
  String? discoverError;
  String? searchError;

  bool _hasLoadedOnce = false;
  int _searchRequestCounter = 0;

  @override
  void initState() {
    super.initState();

    TabNavigationService.discoverTapSignal.addListener(_scrollToTop);
    _loadDiscoverFeedOnce();
  }

  Future<void> _loadDiscoverFeedOnce() async {
    if (_hasLoadedOnce) {
      return;
    }

    setState(() {
      isLoadingDiscover = true;
      discoverError = null;
    });

    final service = ref.read(tmdbServiceProvider);

    try {
      final results =
          await retryCall<List<List<Movie>>>(() => Future.wait<List<Movie>>([
                service.getPopularMovies(),
                service.getPopularTvShows(),
                service.getTopRatedMovies(),
                service.getTopRatedTvShows(),
                service.getTrendingMovies(),
              ]));

      final combined = results.expand((items) => items).toList();

      final unique = <String, Movie>{};
      for (final movie in combined) {
        final key = '${movie.mediaType}-${movie.id}';
        unique[key] = movie;
      }

      final shuffled = unique.values.toList();
      shuffled.shuffle(Random());

      if (!mounted) return;

      setState(() {
        discoverItems = shuffled;
        isLoadingDiscover = false;
        discoverError = null;
        _hasLoadedOnce = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        discoverItems = [];
        discoverError = 'Could not load discover items.';
        isLoadingDiscover = false;
        _hasLoadedOnce = true;
      });
    }
  }

  void _search(String value) {
    final query = value.trim();

    if (query.isEmpty) {
      if (!mounted) return;

      setState(() {
        isSearching = false;
        isLoadingSearch = false;
        searchResults = [];
        personResults = [];
        searchError = null;
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      isSearching = true;
      isLoadingSearch = true;
      searchError = null;
    });

    // Increment request counter to invalidate older in-flight searches
    final requestId = ++_searchRequestCounter;

    Future.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      if (searchController.text.trim() != query) return;
      if (requestId != _searchRequestCounter) return;

      try {
        final service = ref.read(tmdbServiceProvider);

        final results = await retryCall<List<dynamic>>(
          () => Future.wait<dynamic>([
            service.searchMovies(query),
            service.searchPeople(query),
          ]),
        );

        if (!mounted) return;
        if (searchController.text.trim() != query) return;
        if (requestId != _searchRequestCounter) return;

        setState(() {
          searchResults = results[0] as List<Movie>;
          personResults = results[1] as List<Person>;
          isLoadingSearch = false;
        });
      } catch (_) {
        if (!mounted) return;
        if (requestId != _searchRequestCounter) return;

        setState(() {
          searchResults = [];
          personResults = [];
          searchError = 'Search failed.';
          isLoadingSearch = false;
        });
      }
    });
  }

  Future<void> refresh() async {
    final hasQuery = searchController.text.trim().isNotEmpty;

    if (hasQuery) {
      _search(searchController.text);
      return;
    }

    setState(() {
      isLoadingDiscover = true;
      discoverError = null;
      _hasLoadedOnce = false;
    });

    final service = ref.read(tmdbServiceProvider);

    try {
      final results =
          await retryCall<List<List<Movie>>>(() => Future.wait<List<Movie>>([
                service.getPopularMovies(),
                service.getPopularTvShows(),
                service.getTopRatedMovies(),
                service.getTopRatedTvShows(),
                service.getTrendingMovies(),
              ]));

      final combined = results.expand((items) => items).toList();

      final unique = <String, Movie>{};
      for (final movie in combined) {
        final key = '${movie.mediaType}-${movie.id}';
        unique[key] = movie;
      }

      final shuffled = unique.values.toList();
      shuffled.shuffle(Random());

      if (!mounted) return;

      setState(() {
        discoverItems = shuffled;
        isLoadingDiscover = false;
        discoverError = null;
        _hasLoadedOnce = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        discoverItems = [];
        discoverError = 'Could not load discover items.';
        isLoadingDiscover = false;
        _hasLoadedOnce = true;
      });
    }
  }

  void clearSearch() {
    searchController.clear();

    if (!mounted) return;

    setState(() {
      searchResults = [];
      personResults = [];
      isSearching = false;
      isLoadingSearch = false;
      searchError = null;
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= 0) return;

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildGrid(
    List<Movie> movies, {
    bool showMediaType = false,
  }) {
    if (movies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: movies.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: showMediaType ? 0.44 : 0.53,
        ),
        itemBuilder: (context, index) {
          final movie = movies[index];

          return MovieCard(
            movie: movie,
            heroTag: 'discover-${movie.mediaType}-${movie.id}-$index',
            sourceTab: 'discover',
            showMediaType: showMediaType,
          );
        },
      ),
    );
  }

  Widget _buildPeopleSection() {
    if (personResults.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'People',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: personResults.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final person = personResults[index];

                return _PersonSearchCard(
                  person: person,
                  onTap: () {
                    context.push(
                      '/discover/actor',
                      extra: {
                        'personId': person.id,
                        'initialName': person.name,
                        'initialProfilePath': person.profilePath,
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBody() {
    if (isLoadingSearch) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (searchError != null) {
      return _RetryMessage(
        message: searchError!,
        onRetry: () => _search(searchController.text),
      );
    }

    if (personResults.isEmpty && searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 48,
        ),
        child: Center(
          child: Text(
            'No results found.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeopleSection(),
        if (searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Titles',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        _buildGrid(
          searchResults,
          showMediaType: true,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (isSearching) {
      return _buildSearchBody();
    }

    if (discoverError != null) {
      return _RetryMessage(
        message: discoverError!,
        onRetry: () {
          setState(() {
            isLoadingDiscover = true;
            discoverError = null;
            _hasLoadedOnce = false;
          });
          _loadDiscoverFeedOnce();
        },
      );
    }

    if (discoverItems.isEmpty && isLoadingDiscover) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (discoverItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 48,
        ),
        child: Center(
          child: Text(
            'Could not load discover items.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return _buildGrid(discoverItems);
  }

  @override
  void dispose() {
    TabNavigationService.discoverTapSignal.removeListener(_scrollToTop);
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final hasText = searchController.text.trim().isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Discover',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: searchController,
                  onChanged: _search,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search movies, TV shows, or people',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(
                      Icons.search,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: hasText
                        ? IconButton(
                            onPressed: clearSearch,
                            icon: Icon(
                              Icons.clear,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildBody(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonSearchCard extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;

  const _PersonSearchCard({
    required this.person,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = person.profileUrl;

    return SizedBox(
      width: 100,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 100,
                  height: 92,
                  child: imageUrl == null
                      ? Container(
                          color: scheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.person,
                            color: scheme.onSurfaceVariant,
                            size: 34,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          placeholder: (_, __) {
                            return Container(
                              color: scheme.surfaceContainerHighest,
                            );
                          },
                          errorWidget: (_, __, ___) {
                            return Container(
                              color: scheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.person,
                                color: scheme.onSurfaceVariant,
                                size: 34,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.38),
                  ),
                ),
                child: Text(
                  'ACTOR',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RetryMessage({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 44,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
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