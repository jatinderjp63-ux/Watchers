import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie.dart';
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

  bool isSearching = false;
  bool isLoadingDiscover = false;
  bool isLoadingSearch = false;
  String? discoverError;
  String? searchError;

  bool _hasLoadedOnce = false;

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
      final results = await retryCall<List<List<Movie>>>(() => Future.wait<List<Movie>>([
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

    Future.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      if (searchController.text.trim() != query) return;

      try {
        final results = await retryCall<List<Movie>>(() =>
            ref.read(tmdbServiceProvider).searchMovies(query));

        if (!mounted) return;

        setState(() {
          searchResults = results;
          isLoadingSearch = false;
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          searchResults = [];
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
      final results = await retryCall<List<List<Movie>>>(() => Future.wait<List<Movie>>([
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

  Widget _buildGrid(List<Movie> movies) {
    if (movies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: movies.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.53,
        ),
        itemBuilder: (context, index) {
          final movie = movies[index];
          return MovieCard(
            movie: movie,
            heroTag: 'discover-${movie.mediaType}-${movie.id}-$index',
            sourceTab: 'discover',
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (isSearching) {
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

      if (searchResults.isEmpty) {
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

      return _buildGrid(searchResults);
    }

    // For discover feed, always show the grid (with placeholders in cards)
    // instead of a full-page loader. This avoids the "loading animation first"
    // effect and makes the UI feel instant.
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
      // Optional: show a one-time loader only on very first load.
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
                    hintText: 'Search movies or TV shows',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                    suffixIcon: hasText
                        ? IconButton(
                            onPressed: clearSearch,
                            icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
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