import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../services/retry_helper.dart';
import '../services/tmdb_service.dart';

class ActorDetailsScreen extends StatefulWidget {
  final int personId;
  final String initialName;
  final String initialProfilePath;

  const ActorDetailsScreen({
    super.key,
    required this.personId,
    required this.initialName,
    required this.initialProfilePath,
  });

  @override
  State<ActorDetailsScreen> createState() => _ActorDetailsScreenState();
}

class _ActorDetailsScreenState extends State<ActorDetailsScreen> {
  final TmdbService _tmdbService = TmdbService();

  List<Movie> _movies = [];
  List<Movie> _shows = [];

  String _name = '';
  String _profilePath = '';

  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _name = widget.initialName;
    _profilePath = widget.initialProfilePath;
    _loadActor();
  }

  Future<void> _loadActor() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        retryCall(() => _tmdbService.getPersonDetails(widget.personId)),
        retryCall(() => _tmdbService.getPersonCombinedCredits(widget.personId)),
      ]);

      final person = results[0] as Map<String, dynamic>;
      final credits = results[1] as List<Movie>;

      final movies = credits
          .where((movie) => movie.mediaType == 'movie')
          .toList();

      final shows = credits
          .where((movie) => movie.mediaType == 'tv')
          .toList();

      if (!mounted) return;

      setState(() {
        _name = person['name']?.toString().trim().isNotEmpty == true
            ? person['name'].toString().trim()
            : widget.initialName;

        _profilePath = person['profile_path']?.toString().trim().isNotEmpty ==
                true
            ? person['profile_path'].toString().trim()
            : widget.initialProfilePath;

        _movies = movies;
        _shows = shows;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Actor details error: $error');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Could not load actor filmography.';
      });
    }
  }

  String? get _profileUrl {
    final path = _profilePath.trim();

    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return 'https://image.tmdb.org/t/p/w780$path';
  }

  String? _posterUrl(Movie movie) {
    final path = movie.posterPath.trim();

    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return 'https://image.tmdb.org/t/p/w342$path';
  }

  void _openFilmography(
    String mediaType,
    List<Movie> items,
  ) {
    context.push(
      '/discover/actor/filmography',
      extra: {
        'personName': _name,
        'mediaType': mediaType,
        'items': items,
      },
    );
  }

  void _openDetails(
    Movie movie,
    int index,
  ) {
    context.push(
      '/discover/details',
      extra: {
        'movie': movie,
        'heroTag': 'actor-preview-${movie.mediaType}-${movie.id}-$index',
        'sourceTab': 'discover',
      },
    );
  }

  Widget _buildProfileImage(ColorScheme scheme) {
    final url = _profileUrl;

    if (url == null) {
      return Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          size: 72,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) {
        return Container(color: scheme.surfaceContainerHighest);
      },
      errorWidget: (_, __, ___) {
        return Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.person,
            size: 72,
            color: scheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  Widget _buildCreditSection({
    required String title,
    required String mediaType,
    required List<Movie> items,
  }) {
    final scheme = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final previewItems = items.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openFilmography(mediaType, items),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 28,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: previewItems.length,
            padding: EdgeInsets.zero,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = previewItems[index];
              final posterUrl = _posterUrl(movie);

              return SizedBox(
                width: 112,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openDetails(movie, index),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag:
                              'actor-preview-${movie.mediaType}-${movie.id}-$index',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 168,
                              width: 112,
                              child: posterUrl == null
                                  ? _posterPlaceholder(
                                      scheme,
                                      Icons.movie_outlined,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      fadeInDuration: Duration.zero,
                                      placeholder: (_, __) {
                                        return _posterPlaceholder(
                                          scheme,
                                          Icons.movie_outlined,
                                        );
                                      },
                                      errorWidget: (_, __, ___) {
                                        return _posterPlaceholder(
                                          scheme,
                                          Icons.broken_image_outlined,
                                        );
                                      },
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
                            color: scheme.onSurface,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _posterPlaceholder(
    ColorScheme scheme,
    IconData icon,
  ) {
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: scheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadActor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: _buildProfileImage(scheme),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              scheme.surface.withValues(alpha: 0.10),
                              scheme.surface,
                            ],
                            stops: const [0.45, 0.76, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 12,
                    left: 16,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.52),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => context.pop(),
                        tooltip: 'Back',
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 160),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 44,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _loadActor,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _buildCreditSection(
                                title: 'Movies',
                                mediaType: 'movie',
                                items: _movies,
                              ),
                              if (_movies.isNotEmpty && _shows.isNotEmpty)
                                const SizedBox(height: 26),
                              _buildCreditSection(
                                title: 'Shows',
                                mediaType: 'tv',
                                items: _shows,
                              ),
                              if (_movies.isEmpty && _shows.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 36),
                                  child: Center(
                                    child: Text(
                                      'No acting credits available.',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}