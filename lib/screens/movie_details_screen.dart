import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cast_member.dart';
import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../models/movie_details.dart';
import '../models/tv_progress.dart';
import '../services/media_library_service.dart';
import '../services/metadata_refresh_service.dart';
import '../services/retry_helper.dart';
import '../services/tmdb_service.dart';
import '../providers/tv_progress_provider.dart';

class MovieDetailsScreen extends ConsumerStatefulWidget {
  final Movie movie;
  final String heroTag;

  const MovieDetailsScreen({
    super.key,
    required this.movie,
    required this.heroTag,
  });

  @override
  ConsumerState<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends ConsumerState<MovieDetailsScreen> {
  final TmdbService _tmdbService = TmdbService();
  final MediaLibraryService _libraryService = MediaLibraryService();
  final MetadataRefreshService _cache = MetadataRefreshService.instance;

  MovieDetails? details;
  List cast = [];
  List<Map<String, dynamic>> trailers = [];
  List<Map<String, dynamic>> _seasonEpisodes = [];

  bool _episodesLoading = false;
  bool _initialLoadDone = false;
  bool isRefreshing = false;
  bool isLoadingTrailers = false;

  String? errorMessage;
  int selectedSection = 0;
  int _tvSelectedTab = 0;
  int _tvAboutSection = 0;
  int? _selectedSeason;
  Future<MediaLibraryItem?>? _itemFuture;

  bool get _isTv => widget.movie.mediaType == 'tv';

  String get _mediaType => _isTv ? 'tv' : 'movie';

  String get _detailsKey {
    return MetadataRefreshService.movieDetailsKey(
      widget.movie.id,
      _mediaType,
    );
  }

  String get _castKey {
    return MetadataRefreshService.castKey(
      widget.movie.id,
      _mediaType,
    );
  }

  String get _trailersKey {
    return MetadataRefreshService.trailersKey(widget.movie.id);
  }

  @override
  void initState() {
    super.initState();

    _itemFuture = _libraryService.getItem(widget.movie.id);
    _loadDetails();
  }

  Future<void> _loadDetails({
    bool forceRefresh = false,
  }) async {
    final cachedDetails = _cache.read<MovieDetails>(_detailsKey);
    final cachedCast = _cache.read<List<CastMember>>(_castKey);
    final cachedTrailers =
        _cache.read<List<Map<String, dynamic>>>(_trailersKey);

    if (cachedDetails != null) {
      if (!mounted) return;

      setState(() {
        details = cachedDetails;
        cast = cachedCast ?? [];
        trailers = cachedTrailers ?? [];
        _initialLoadDone = true;
        errorMessage = null;
      });

      if (_isTv) {
        _selectedSeason ??= 1;
        _loadSeasonEpisodes(_selectedSeason!);
      } else {
        _loadTrailersInBackground();
      }

      if (!forceRefresh && _cache.isFresh(_detailsKey)) {
        return;
      }

      await _refreshDetailsSilently();
      return;
    }

    if (mounted) {
      setState(() {
        _initialLoadDone = false;
        errorMessage = null;
      });
    }

    await _refreshDetailsSilently(
      showInitialLoading: true,
    );
  }

  Future<void> _refreshDetailsSilently({
    bool showInitialLoading = false,
  }) async {
    if (isRefreshing) return;

    isRefreshing = true;

    if (showInitialLoading && mounted) {
      setState(() {
        _initialLoadDone = false;
      });
    }

    try {
      final results = await Future.wait([
        retryCall(
          () => _tmdbService.getMovieDetails(
            widget.movie.id,
            _mediaType,
          ),
        ),
        retryCall(
          () => _tmdbService.getCast(
            widget.movie.id,
            _mediaType,
          ),
        ),
      ]);

      final loadedDetails = results[0] as MovieDetails;
      final loadedCast = (results[1] as List).cast<CastMember>();

      _cache.write<MovieDetails>(
        _detailsKey,
        loadedDetails,
      );

      _cache.write<List<CastMember>>(
        _castKey,
        loadedCast,
      );

      if (!mounted) return;

      setState(() {
        details = loadedDetails;
        cast = loadedCast;
        _initialLoadDone = true;
        errorMessage = null;
      });

      if (_isTv) {
        _selectedSeason ??= 1;
        _loadSeasonEpisodes(_selectedSeason!);
      } else {
        _loadTrailersInBackground();
      }
    } catch (error) {
      debugPrint('Movie Details Error: $error');

      if (!mounted) return;

      setState(() {
        _initialLoadDone = true;
        errorMessage = _isTv
            ? 'Failed to load show details.'
            : 'Failed to load movie details.';
      });
    } finally {
      isRefreshing = false;
    }
  }

  Future<void> _loadTrailersInBackground({
    bool forceRefresh = false,
  }) async {
    if (isLoadingTrailers) return;

    final cachedTrailers =
        _cache.read<List<Map<String, dynamic>>>(_trailersKey);

    if (cachedTrailers != null &&
        cachedTrailers.isNotEmpty &&
        !forceRefresh &&
        _cache.isFresh(_trailersKey)) {
      if (mounted) {
        setState(() {
          trailers = cachedTrailers;
        });
      }

      return;
    }

    await _loadTrailers(
      forceRefresh: forceRefresh,
      showLoading: false,
    );
  }

  Future<void> _loadTrailers({
    bool forceRefresh = false,
    bool showLoading = true,
  }) async {
    if (isLoadingTrailers) return;

    final cachedTrailers =
        _cache.read<List<Map<String, dynamic>>>(_trailersKey);

    if (!forceRefresh &&
        cachedTrailers != null &&
        cachedTrailers.isNotEmpty &&
        _cache.isFresh(_trailersKey)) {
      if (mounted) {
        setState(() {
          trailers = cachedTrailers;
        });
      }

      return;
    }

    if (mounted && showLoading) {
      setState(() {
        isLoadingTrailers = true;
      });
    } else {
      isLoadingTrailers = true;
    }

    try {
      final videos = await retryCall(
        () => _tmdbService.getVideos(
          widget.movie.id,
          _mediaType,
        ),
      );

      final filteredTrailers = videos
          .whereType<Map>()
          .map(
            (video) => Map<String, dynamic>.from(video),
          )
          .where((video) {
            final site =
                video['site']?.toString().toLowerCase() ?? '';
            final key = video['key']?.toString() ?? '';
            final type =
                video['type']?.toString().toLowerCase() ?? '';

            return site == 'youtube' &&
                key.isNotEmpty &&
                (type == 'trailer' || type == 'teaser');
          })
          .map(
            (video) => <String, dynamic>{
              ...video,
              'yt_title': video['name'] ?? '',
            },
          )
          .toList();

      filteredTrailers.sort((a, b) {
        final aDate = a['published_at']?.toString() ?? '';
        final bDate = b['published_at']?.toString() ?? '';

        if (aDate.isEmpty && bDate.isEmpty) {
          return 0;
        }

        if (aDate.isEmpty) {
          return 1;
        }

        if (bDate.isEmpty) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });

      _cache.write<List<Map<String, dynamic>>>(
        _trailersKey,
        filteredTrailers,
      );

      if (!mounted) return;

      setState(() {
        trailers = filteredTrailers;
        isLoadingTrailers = false;
      });
    } catch (error) {
      debugPrint('Trailer Error: $error');

      if (!mounted) return;

      setState(() {
        isLoadingTrailers = false;
      });
    }
  }

  Future<void> _openTrailer(
    Map<String, dynamic> trailer,
  ) async {
    final key = trailer['key']?.toString() ?? '';

    if (key.isEmpty) return;

    final uri = Uri.parse(
      'https://www.youtube.com/watch?v=$key',
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open trailer.'),
        ),
      );
    }
  }

  Future<void> _changeMovieStatus(
    MediaStatus status,
  ) async {
    final existing = await _libraryService.getItem(
      widget.movie.id,
    );

    if (existing == null) {
      await _libraryService.addMedia(
        widget.movie,
        status,
      );
    } else if (existing.status == status) {
      await _libraryService.removeMedia(
        widget.movie.id,
      );
    } else {
      await _libraryService.updateStatus(
        widget.movie.id,
        status,
      );
    }

    if (!mounted) return;

    setState(() {
      _itemFuture = _libraryService.getItem(
        widget.movie.id,
      );
    });
  }

  Future<void> _loadSeasonEpisodes(
    int seasonNumber,
  ) async {
    if (_episodesLoading) return;

    if (mounted) {
      setState(() {
        _episodesLoading = true;
      });
    }

    try {
      final episodes = await retryCall(
        () => _tmdbService.getSeasonEpisodes(
          widget.movie.id,
          seasonNumber,
        ),
      );

      if (!mounted) return;

      setState(() {
        _seasonEpisodes = episodes
            .map(
              (episode) => Map<String, dynamic>.from(episode),
            )
            .toList();
        _episodesLoading = false;
      });
    } catch (error) {
      debugPrint('Season Episodes Error: $error');

      if (!mounted) return;

      setState(() {
        _seasonEpisodes = [];
        _episodesLoading = false;
      });
    }
  }

  String? _posterUrlFor(
    String? path,
  ) {
    final value = path?.trim() ?? '';

    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') ||
        value.startsWith('https://')) {
      return value;
    }

    return 'https://image.tmdb.org/t/p/w500$value';
  }

  String? _detailsPosterUrl(
    MovieDetails? movie,
  ) {
    final value = movie?.posterUrl.trim() ?? '';

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  Widget _buildMovieStatusButtons() {
    return FutureBuilder<MediaLibraryItem?>(
      future: _itemFuture,
      builder: (context, snapshot) {
        final currentStatus = snapshot.data?.status;

        Widget makeButton({
          required String label,
          required IconData icon,
          required MediaStatus status,
          required Color color,
        }) {
          return _PremiumStatusButton(
            label: label,
            icon: icon,
            selected: currentStatus == status,
            selectedColor: color,
            onPressed: () => _changeMovieStatus(status),
          );
        }

        if (_isTv) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: makeButton(
                      label: 'Planned',
                      icon: Icons.bookmark_add_outlined,
                      status: MediaStatus.planning,
                      color: const Color(0xFF4C8BF5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: makeButton(
                      label: 'Watched',
                      icon: Icons.check_circle_outline,
                      status: MediaStatus.watched,
                      color: const Color(0xFF2EAF62),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: makeButton(
                      label: 'Dropped',
                      icon: Icons.close_outlined,
                      status: MediaStatus.dropped,
                      color: const Color(0xFFB00020),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: makeButton(
                label: 'Planned',
                icon: Icons.bookmark_add_outlined,
                status: MediaStatus.planning,
                color: const Color(0xFF4C8BF5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: makeButton(
                label: 'Watched',
                icon: Icons.check_circle_outline,
                status: MediaStatus.watched,
                color: const Color(0xFF2EAF62),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMovieSections() {
    return _SegmentSelector(
      labels: const [
        'Overview',
        'Cast',
        'Trailers',
      ],
      selectedIndex: selectedSection,
      onSelected: (index) {
        setState(() {
          selectedSection = index;
        });

        if (index == 2) {
          _loadTrailers(
            showLoading: trailers.isEmpty,
          );
        }
      },
    );
  }

  Widget _buildShowAboutSections() {
    return _SegmentSelector(
      labels: const [
        'Overview',
        'Cast',
        'Trailers',
      ],
      selectedIndex: _tvAboutSection,
      onSelected: (index) {
        setState(() {
          _tvAboutSection = index;
        });

        if (index == 2) {
          _loadTrailers(
            showLoading: trailers.isEmpty,
          );
        }
      },
    );
  }

  Widget _buildOverview(
    MovieDetails movie,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.overview.isEmpty
              ? 'No overview available.'
              : movie.overview,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _InfoLine(
          label: 'Director',
          value: movie.formattedDirectors,
        ),
        _InfoLine(
          label: 'Runtime',
          value: movie.formattedRuntime,
        ),
        _InfoLine(
          label: 'Genre',
          value: movie.genres.isEmpty
              ? '-'
              : movie.genres.join(', '),
        ),
        _InfoLine(
          label: 'Release Date',
          value: movie.formattedReleaseDate,
        ),
      ],
    );
  }

  Widget _buildShowOverview(
    MovieDetails show,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          show.overview.isEmpty
              ? 'No overview available.'
              : show.overview,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _InfoLine(
          label: 'Creator',
          value: show.createdBy.isEmpty
              ? '-'
              : show.createdBy.join(', '),
        ),
        _InfoLine(
          label: 'Release Date',
          value: show.formattedReleaseDate,
        ),
        _InfoLine(
          label: 'Genre',
          value: show.genres.isEmpty
              ? '-'
              : show.genres.join(', '),
        ),
      ],
    );
  }

  Widget _buildOverviewSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SkeletonLine(
          width: double.infinity,
        ),
        const SizedBox(height: 8),
        const _SkeletonLine(
          width: double.infinity,
        ),
        const SizedBox(height: 8),
        const _SkeletonLine(
          width: 260,
        ),
        const SizedBox(height: 24),
        const _SkeletonLine(width: 140),
        const SizedBox(height: 10),
        const _SkeletonLine(width: 120),
        const SizedBox(height: 10),
        const _SkeletonLine(width: 160),
      ],
    );
  }

  Widget _buildCast() {
    final scheme = Theme.of(context).colorScheme;

    if (cast.isEmpty) {
      return Text(
        'Cast information unavailable.',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cast.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 18,
        mainAxisExtent: 178,
      ),
      itemBuilder: (context, index) {
        final actor = cast[index];

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: 108,
                child: actor.profileUrl.isEmpty
                    ? _personPlaceholder()
                    : Image.network(
                        actor.profileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return _personPlaceholder();
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: Text(
                actor.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              actor.character,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCastSkeleton() {
    final scheme = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 18,
        mainAxisExtent: 178,
      ),
      itemBuilder: (_, __) {
        return Column(
          children: [
            Container(
              height: 108,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 8),
            const _SkeletonLine(
              width: double.infinity,
            ),
            const SizedBox(height: 4),
            const _SkeletonLine(
              width: double.infinity,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrailers() {
    final scheme = Theme.of(context).colorScheme;

    if (isLoadingTrailers && trailers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (trailers.isEmpty) {
      return Text(
        'No official trailers available.',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
        ),
      );
    }

    return Column(
      children: trailers.map<Widget>((trailer) {
        final key = trailer['key']?.toString() ?? '';

        final youtubeTitle =
            trailer['yt_title']?.toString() ?? '';
        final tmdbTitle =
            trailer['name']?.toString() ?? '';

        final title = youtubeTitle.trim().isNotEmpty
            ? youtubeTitle
            : tmdbTitle.trim().isNotEmpty
                ? tmdbTitle
                : 'Official trailer';

        return Column(
          children: [
            InkWell(
              onTap: () => _openTrailer(trailer),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 68,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              'https://img.youtube.com/vi/'
                              '$key/hqdefault.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                            Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(
                                    alpha: 0.72,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outline.withValues(alpha: 0.45),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMovieSelectedSection(
    MovieDetails? movie,
  ) {
    switch (selectedSection) {
      case 1:
        return details != null
            ? _buildCast()
            : _buildCastSkeleton();
      case 2:
        return _buildTrailers();
      default:
        return details != null
            ? _buildOverview(movie!)
            : _buildOverviewSkeleton();
    }
  }

  Widget _buildShowAboutSelectedSection(
    MovieDetails? show,
  ) {
    switch (_tvAboutSection) {
      case 1:
        return details != null
            ? _buildCast()
            : _buildCastSkeleton();
      case 2:
        return _buildTrailers();
      default:
        return details != null
            ? _buildShowOverview(show!)
            : _buildOverviewSkeleton();
    }
  }

  Widget _buildPosterHeader(
    MovieDetails? movie,
  ) {
    final fallbackPosterUrl = _posterUrlFor(
      widget.movie.posterPath,
    );

    final detailsPosterUrl = _detailsPosterUrl(movie);

    final posterUrl = detailsPosterUrl ?? fallbackPosterUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl != null && posterUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 24,
              sigmaY: 24,
            ),
            child: CachedNetworkImage(
              imageUrl: posterUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              fadeInDuration: Duration.zero,
              placeholder: (_, __) {
                return Container(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                );
              },
              errorWidget: (_, __, ___) {
                return Container(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                );
              },
            ),
          ),
        Container(
          color: Colors.black.withValues(alpha: 0.45),
        ),
        Center(
          child: Hero(
            tag: widget.heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: posterUrl == null || posterUrl.isEmpty
                  ? _posterPlaceholder()
                  : CachedNetworkImage(
                      imageUrl: posterUrl,
                      width: 240,
                      height: 360,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      fadeInDuration: Duration.zero,
                      placeholder: (_, __) {
                        return _posterPlaceholder();
                      },
                      errorWidget: (_, __, ___) {
                        return _posterPlaceholder();
                      },
                    ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoviePage() {
    final scheme = Theme.of(context).colorScheme;
    final movie = details;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshDetailsSilently();
          await _loadTrailers(
            forceRefresh: true,
            showLoading: false,
          );
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 470,
              backgroundColor: scheme.surface,
              leading: IconButton(
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.arrow_back),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildPosterHeader(movie),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  160,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie?.title ?? widget.movie.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildMovieStatusButtons(),
                    const SizedBox(height: 24),
                    _buildMovieSections(),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(selectedSection),
                        child: _buildMovieSelectedSection(movie),
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

  Widget _buildTvPage() {
    final scheme = Theme.of(context).colorScheme;
    final tvProgress = ref.watch(tvProgressProvider);
    final notifier = ref.read(tvProgressProvider.notifier);

    final progressItem = tvProgress
        .where((progress) => progress.id == widget.movie.id)
        .firstOrNull;

    final show = details;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final currentSeason = _selectedSeason ?? 1;

          await _refreshDetailsSilently();

          if (_selectedSeason != currentSeason) {
            setState(() {
              _selectedSeason = currentSeason;
            });

            _loadSeasonEpisodes(currentSeason);
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 470,
              backgroundColor: scheme.surface,
              leading: IconButton(
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.arrow_back),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildPosterHeader(show),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  160,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show?.title ?? widget.movie.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildMovieStatusButtons(),
                    const SizedBox(height: 24),
                    _SegmentSelector(
                      labels: const [
                        'About',
                        'Episodes',
                      ],
                      selectedIndex: _tvSelectedTab,
                      onSelected: (index) {
                        setState(() {
                          _tvSelectedTab = index;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(_tvSelectedTab),
                        child: _tvSelectedTab == 0
                            ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _buildShowAboutSections(),
                                  const SizedBox(height: 16),
                                  AnimatedSwitcher(
                                    duration: const Duration(
                                      milliseconds: 180,
                                    ),
                                    child: KeyedSubtree(
                                      key: ValueKey(_tvAboutSection),
                                      child:
                                          _buildShowAboutSelectedSection(
                                        show,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _buildTvEpisodes(
                                show,
                                progressItem,
                                notifier,
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

  Widget _buildTvEpisodes(
    MovieDetails? show,
    TvProgress? progressItem,
    TvProgressNotifier notifier,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final totalSeasons = show?.totalSeasons ?? 0;

    if (totalSeasons == 0) {
      return Text(
        'No season information available.',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
        ),
      );
    }

    final selectedSeason = _selectedSeason ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: totalSeasons,
            itemBuilder: (context, index) {
              final seasonNumber = index + 1;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('S$seasonNumber'),
                  selected: seasonNumber == selectedSeason,
                  onSelected: (selected) {
                    if (!selected) return;

                    setState(() {
                      _selectedSeason = seasonNumber;
                    });

                    _loadSeasonEpisodes(seasonNumber);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _ensureShowInProgress();

                  ref.invalidate(tvProgressProvider);

                  notifier.toggleSeasonWatched(
                    widget.movie.id,
                    selectedSeason,
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Watched'),
              ),
            ),
            if (progressItem != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Season $selectedSeason · '
                  '${progressItem.currentSeason == selectedSeason ? progressItem.currentEpisode : 0} '
                  'of ${_seasonEpisodes.length} watched',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (_episodesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_seasonEpisodes.isEmpty)
          Text(
            'No episode information available for this season.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 15,
            ),
          )
        else
          ListView.separated(
            key: PageStorageKey<String>(
              'episodes_list_${widget.movie.id}_s$selectedSeason',
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _seasonEpisodes.length,
            separatorBuilder: (_, __) {
              return const Divider(height: 1);
            },
            itemBuilder: (context, index) {
              final episode = _seasonEpisodes[index];

              final episodeNumber =
                  (episode['episode_number'] as int?) ??
                      (index + 1);

              final title =
                  (episode['name'] as String?) ??
                      'Episode $episodeNumber';

              final overview =
                  (episode['overview'] as String?) ?? '';

              final stillPath =
                  episode['still_path'] as String?;

              final isWatched = progressItem != null &&
                  progressItem.currentSeason == selectedSeason &&
                  progressItem.currentEpisode >= episodeNumber;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 100,
                    height: 56,
                    child: stillPath != null &&
                            stillPath.isNotEmpty
                        ? Image.network(
                            'https://image.tmdb.org/t/p/w185'
                            '$stillPath',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: scheme
                                    .surfaceContainerHighest,
                                child: Icon(
                                  Icons
                                      .image_not_supported_outlined,
                                  color: scheme.onSurfaceVariant,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.movie_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                title: Text(
                  'S${selectedSeason.toString().padLeft(2, '0')} '
                  'E${episodeNumber.toString().padLeft(2, '0')} · '
                  '$title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: overview.isEmpty
                    ? null
                    : Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                trailing: IconButton(
                  icon: Icon(
                    isWatched
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: isWatched
                        ? const Color(0xFF2EAF62)
                        : scheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    await _ensureShowInProgress();

                    ref.invalidate(tvProgressProvider);

                    notifier.toggleEpisodeWatchedAt(
                      widget.movie.id,
                      selectedSeason,
                      episodeNumber,
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _ensureShowInProgress() async {
    final notifier = ref.read(tvProgressProvider.notifier);

    if (notifier.getShowById(widget.movie.id) != null) {
      return;
    }

    await notifier.addShow(
      TvProgress(
        id: widget.movie.id,
        title: widget.movie.title,
        posterPath: widget.movie.posterPath,
        currentSeason: 1,
        currentEpisode: 1,
        watchedEpisodes: 0,
        totalEpisodes: details?.totalEpisodes ?? 0,
        totalSeasons: details?.totalSeasons ?? 0,
      ),
    );
  }

  Widget _posterPlaceholder() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      height: 360,
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_outlined,
        size: 60,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Widget _personPlaceholder() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.movie.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  _loadDetails(forceRefresh: true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoadDone && details == null) {
      return _buildError();
    }

    return _isTv
        ? _buildTvPage()
        : _buildMoviePage();
  }
}

class _SegmentSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SegmentSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline,
        ),
      ),
      child: Row(
        children: List.generate(
          labels.length,
          (index) {
            final selected = selectedIndex == index;

            return Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;

  const _SkeletonLine({
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 14,
      width: width,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _PremiumStatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onPressed;

  const _PremiumStatusButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? selectedColor
              : scheme.outline.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected
              ? selectedColor
              : scheme.surface,
          foregroundColor: selected
              ? Colors.white
              : scheme.onSurface,
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.white
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}