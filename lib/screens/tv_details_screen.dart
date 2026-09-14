import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cast_member.dart';
import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../models/movie_details.dart';
import '../models/tv_progress.dart';
import '../models/watch_progress_settings.dart';
import '../providers/settings_provider.dart';
import '../services/media_library_service.dart';
import '../services/metadata_refresh_service.dart';
import '../services/retry_helper.dart';
import '../services/tmdb_service.dart';
import '../providers/tv_progress_provider.dart';
import '../providers/tv_display_status.dart';
import 'episode_details_screen.dart';

class TvDetailsScreen extends ConsumerStatefulWidget {
  final Movie show;
  final String heroTag;

  const TvDetailsScreen({
    super.key,
    required this.show,
    required this.heroTag,
  });

  @override
  ConsumerState<TvDetailsScreen> createState() => _TvDetailsScreenState();
}

class _TvDetailsScreenState extends ConsumerState<TvDetailsScreen> {
  final TmdbService _tmdbService = TmdbService();
  final MediaLibraryService _libraryService = MediaLibraryService();
  final MetadataRefreshService _cache = MetadataRefreshService.instance;

  MovieDetails? details;
  List<CastMember> cast = [];
  List<Map<String, dynamic>> trailers = [];
  List<Map<String, dynamic>> _seasonEpisodes = [];

  bool _episodesLoading = false;
  bool _initialLoadDone = false;
  bool isRefreshing = false;
  bool isLoadingTrailers = false;

  String? errorMessage;
  int _tvSelectedTab = 0;
  int _tvAboutSection = 0;
  int? _selectedSeason;
  Future<MediaLibraryItem?>? _itemFuture;
  TvProgressSnapshot? _statusSnapshot;
  bool _statusSnapshotLoading = false;

  final Map<String, int> _episodeCountCache = {};

  String get _mediaType => 'tv';

  String get _detailsKey {
    return MetadataRefreshService.movieDetailsKey(
      widget.show.id,
      _mediaType,
    );
  }

  String get _castKey {
    return MetadataRefreshService.castKey(
      widget.show.id,
      _mediaType,
    );
  }

  String get _trailersKey {
    return MetadataRefreshService.trailersKey(widget.show.id);
  }

  @override
  void initState() {
    super.initState();

    _itemFuture = _libraryService.getItem(widget.show.id);
    _loadDetails();
    _refreshStatusSnapshot();
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

      _selectedSeason ??= 1;
      _loadSeasonEpisodes(_selectedSeason!);
      _loadTrailersInBackground();

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

    await _refreshDetailsSilently(showInitialLoading: true);
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
            widget.show.id,
            _mediaType,
          ),
        ),
        retryCall(
          () => _tmdbService.getCast(
            widget.show.id,
            _mediaType,
          ),
        ),
      ]);

      final loadedDetails = results[0] as MovieDetails;
      final loadedCast = (results[1] as List).cast<CastMember>();

      _cache.write<MovieDetails>(_detailsKey, loadedDetails);
      _cache.write<List<CastMember>>(_castKey, loadedCast);

      if (!mounted) return;

      setState(() {
        details = loadedDetails;
        cast = loadedCast;
        _initialLoadDone = true;
        errorMessage = null;
      });

      _selectedSeason ??= 1;
      _loadSeasonEpisodes(_selectedSeason!);
      _loadTrailersInBackground();
    } catch (error) {
      debugPrint('TV Details Error: $error');

      if (!mounted) return;

      setState(() {
        _initialLoadDone = true;
        errorMessage = 'Failed to load show details.';
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
        () => _tmdbService.getVideos(widget.show.id, _mediaType),
      );

      final filteredTrailers = videos
          .whereType<Map>()
          .map((video) => Map<String, dynamic>.from(video))
          .where((video) {
            final site = video['site']?.toString().toLowerCase() ?? '';
            final key = video['key']?.toString() ?? '';
            final type = video['type']?.toString().toLowerCase() ?? '';

            return site == 'youtube' &&
                key.isNotEmpty &&
                (type == 'trailer' || type == 'teaser');
          })
          .map((video) => <String, dynamic>{
                ...video,
                'yt_title': video['name'] ?? '',
              })
          .toList();

      filteredTrailers.sort((a, b) {
        final aDate = a['published_at']?.toString() ?? '';
        final bDate = b['published_at']?.toString() ?? '';

        if (aDate.isEmpty && bDate.isEmpty) return 0;
        if (aDate.isEmpty) return 1;
        if (bDate.isEmpty) return -1;
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

  Future<void> _openTrailer(Map<String, dynamic> trailer) async {
    final key = trailer['key']?.toString() ?? '';
    if (key.isEmpty) return;

    final uri = Uri.parse('https://www.youtube.com/watch?v=$key');
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open trailer.')),
      );
    }
  }

  Future<void> _refreshStatusSnapshot() async {
    final notifier = ref.read(tvProgressProvider.notifier);

    if (mounted) {
      setState(() {
        _statusSnapshotLoading = true;
      });
    }

    final snapshot = await notifier.getSnapshotForShow(
      id: widget.show.id,
      title: widget.show.title,
      posterPath: widget.show.posterPath,
      totalEpisodes: details?.totalEpisodes ?? 0,
      totalSeasons: details?.totalSeasons ?? 0,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _statusSnapshot = snapshot;
      _statusSnapshotLoading = false;
    });
  }

  Future<void> _changeShowStatus(MediaStatus status) async {
    final existing = await _libraryService.getItem(widget.show.id);

    if (existing == null) {
      await _libraryService.addMedia(widget.show, status);
    } else if (existing.status == status) {
      await _libraryService.removeMedia(widget.show.id);
    } else {
      await _libraryService.updateStatus(widget.show.id, status);
    }

    if (status == MediaStatus.watched && existing?.status != status) {
      final notifier = ref.read(tvProgressProvider.notifier);

      await notifier.ensureShow(
        id: widget.show.id,
        title: widget.show.title,
        posterPath: widget.show.posterPath,
        totalEpisodes: details?.totalEpisodes ?? 0,
        totalSeasons: details?.totalSeasons ?? 0,
      );

      await notifier.markAllReleasedEpisodesWatched(widget.show.id);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _itemFuture = _libraryService.getItem(widget.show.id);
    });

    await _refreshStatusSnapshot();
  }

  Future<void> _loadSeasonEpisodes(int seasonNumber) async {
    if (_episodesLoading) return;

    if (mounted) {
      setState(() {
        _episodesLoading = true;
      });
    }

    try {
      final episodes = await retryCall(
        () => _tmdbService.getSeasonEpisodes(widget.show.id, seasonNumber),
      );

      if (!mounted) return;

      setState(() {
        _seasonEpisodes = episodes
            .map((episode) => Map<String, dynamic>.from(episode))
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

  String? _posterUrlFor(String? path) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    return 'https://image.tmdb.org/t/p/w500$value';
  }

  String? _detailsPosterUrl(MovieDetails? show) {
    final value = show?.posterUrl.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Widget _buildShowStatusButtons() {
    return FutureBuilder<MediaLibraryItem?>(
      future: _itemFuture,
      builder: (context, snapshot) {
        final currentStatus = snapshot.data?.status;

        final displayStatus = resolveTvDisplayStatus(
          manualStatus: currentStatus ?? MediaStatus.planning,
          snapshot: _statusSnapshot,
        );

        final isPlanned = displayStatus == TvDisplayStatus.planned;
        final isWatched = displayStatus == TvDisplayStatus.watched;
        final isDropped = displayStatus == TvDisplayStatus.dropped;

        Widget makeButton({
          required String label,
          required IconData icon,
          required MediaStatus status,
          required Color color,
          required bool selected,
        }) {
          return _PremiumStatusButton(
            label: label,
            icon: icon,
            selected: selected,
            selectedColor: color,
            onPressed: () => _changeShowStatus(status),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (displayStatus == TvDisplayStatus.watching)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      color: Color(0xFFE0A93A),
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _statusSnapshotLoading
                          ? 'Updating progress…'
                          : 'Watching',
                      style: const TextStyle(
                        color: Color(0xFFE0A93A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: makeButton(
                    label: 'Planned',
                    icon: Icons.bookmark_add_outlined,
                    status: MediaStatus.planning,
                    color: const Color(0xFF4C8BF5),
                    selected: isPlanned,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: makeButton(
                    label: 'Watched',
                    icon: Icons.check_circle_outline,
                    status: MediaStatus.watched,
                    color: const Color(0xFF2EAF62),
                    selected: isWatched,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: makeButton(
                    label: 'Dropped',
                    icon: Icons.close_outlined,
                    status: MediaStatus.dropped,
                    color: const Color(0xFFB00020),
                    selected: isDropped,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildShowAboutSections() {
    return _SegmentSelector(
      labels: const ['Overview', 'Cast', 'Trailers'],
      selectedIndex: _tvAboutSection,
      onSelected: (index) {
        setState(() {
          _tvAboutSection = index;
        });

        if (index == 2) {
          _loadTrailers(showLoading: trailers.isEmpty);
        }
      },
    );
  }

  Widget _buildShowOverview(MovieDetails show) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          show.overview.isEmpty ? 'No overview available.' : show.overview,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _InfoLine(
          label: 'Creator',
          value: show.createdBy.isEmpty ? '-' : show.createdBy.join(', '),
        ),
        _InfoLine(label: 'Release Date', value: show.formattedReleaseDate),
        _InfoLine(
          label: 'Genre',
          value: show.genres.isEmpty ? '-' : show.genres.join(', '),
        ),
      ],
    );
  }

  Widget _buildOverviewSkeleton() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonLine(width: double.infinity),
        SizedBox(height: 8),
        _SkeletonLine(width: double.infinity),
        SizedBox(height: 8),
        _SkeletonLine(width: 260),
        SizedBox(height: 24),
        _SkeletonLine(width: 140),
        SizedBox(height: 10),
        _SkeletonLine(width: 120),
        SizedBox(height: 10),
        _SkeletonLine(width: 160),
      ],
    );
  }

  void _openActorDetails(CastMember actor) {
    context.push(
      '/discover/actor',
      extra: {
        'personId': actor.id,
        'initialName': actor.name,
        'initialProfilePath': actor.profilePath,
      },
    );
  }

  Widget _buildCast() {
    final scheme = Theme.of(context).colorScheme;

    if (cast.isEmpty) {
      return Text(
        'Cast information unavailable.',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
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
        mainAxisExtent: 172,
      ),
      itemBuilder: (context, index) {
        final actor = cast[index];

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openActorDetails(actor),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                            errorBuilder: (_, __, ___) => _personPlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      actor.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                SizedBox(
                  height: 14,
                  child: Text(
                    actor.character,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        mainAxisExtent: 172,
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
            const SizedBox(
              height: 32,
              child: _SkeletonLine(width: double.infinity),
            ),
            const SizedBox(height: 1),
            const SizedBox(
              height: 14,
              child: _SkeletonLine(width: double.infinity),
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
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (trailers.isEmpty) {
      return Text(
        'No official trailers available.',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
      );
    }

    return Column(
      children: trailers.map<Widget>((trailer) {
        final key = trailer['key']?.toString() ?? '';
        final youtubeTitle = trailer['yt_title']?.toString() ?? '';
        final tmdbTitle = trailer['name']?.toString() ?? '';
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
                              'https://img.youtube.com/vi/$key/hqdefault.jpg',
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
                                  color: Colors.black.withValues(alpha: 0.72),
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

  Widget _buildShowAboutSelectedSection(MovieDetails? show) {
    switch (_tvAboutSection) {
      case 1:
        return details != null ? _buildCast() : _buildCastSkeleton();
      case 2:
        return _buildTrailers();
      default:
        return details != null
            ? _buildShowOverview(show!)
            : _buildOverviewSkeleton();
    }
  }

  int _watchedInSelectedSeason(
    TvProgress? progress,
    int selectedSeason,
    int episodeCount,
  ) {
    if (progress == null || episodeCount == 0 || progress.totalSeasons == 0) {
      return 0;
    }

    var watchedCount = 0;

    for (final key in progress.watchedEpisodeKeys) {
      if (key.startsWith('${progress.id}:s${selectedSeason}e')) {
        watchedCount++;
      }
    }

    return watchedCount;
  }

  Widget _buildTvEpisodes(
    MovieDetails? show,
    TvProgress? progressItem,
    TvProgressNotifier notifier,
    WatchProgressSettings watchSettings,
    SettingsNotifier settingsNotifier,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final totalSeasons = show?.totalSeasons ?? 0;

    if (totalSeasons == 0) {
      return Text(
        'No season information available.',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
      );
    }

    final selectedSeason = _selectedSeason ?? 1;
    final episodeCount = _seasonEpisodes.length;

    if (episodeCount > 0) {
      final key = '${progressItem?.id ?? widget.show.id}:$selectedSeason';
      _episodeCountCache[key] = episodeCount;
    }

    final watchedInSeason = _watchedInSelectedSeason(
      progressItem,
      selectedSeason,
      episodeCount,
    );

    final isSeasonWatched = episodeCount > 0 && watchedInSeason >= episodeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.22),
            ),
          ),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: totalSeasons,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final seasonNumber = index + 1;
                final isSelected = seasonNumber == selectedSeason;

                return GestureDetector(
                  onTap: () {
                    if (isSelected) return;

                    setState(() {
                      _selectedSeason = seasonNumber;
                    });

                    _loadSeasonEpisodes(seasonNumber);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(minWidth: 64),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color.alphaBlend(
                              scheme.primary.withValues(alpha: 0.22),
                              scheme.surface,
                            )
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: isSelected
                            ? scheme.primary.withValues(alpha: 0.75)
                            : Colors.transparent,
                        width: isSelected ? 1.2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.14),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      'S${seasonNumber.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: isSelected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _SeasonProgressButton(
            selected: isSeasonWatched,
            onPressed: () async {
              await _ensureShowInProgress();

              if (isSeasonWatched) {
                switch (watchSettings.seasonUnmarking) {
                  case SeasonUnmarkingBehavior.laterReleased:
                    await notifier.markSeasonUnwatchedIncludingFutureSeasons(
                      tvId: widget.show.id,
                      seasonNumber: selectedSeason,
                    );
                    break;
                  case SeasonUnmarkingBehavior.onlyThisSeason:
                    await notifier.markSingleSeasonUnwatched(
                      tvId: widget.show.id,
                      seasonNumber: selectedSeason,
                    );
                    break;
                  case SeasonUnmarkingBehavior.askEveryTime:
                    await _showSeasonUnmarkingSheet(
                      notifier: notifier,
                      settingsNotifier: settingsNotifier,
                      seasonNumber: selectedSeason,
                    );
                    break;
                }
              } else {
                switch (watchSettings.seasonMarking) {
                  case SeasonMarkingBehavior.previousReleased:
                    await notifier.markSeasonWatchedIncludingPreviousSeasons(
                      tvId: widget.show.id,
                      seasonNumber: selectedSeason,
                    );
                    await _refreshStatusSnapshot();
                    break;
                  case SeasonMarkingBehavior.onlyThisSeason:
                    await notifier.markSingleSeasonWatched(
                      tvId: widget.show.id,
                      seasonNumber: selectedSeason,
                    );
                    await _refreshStatusSnapshot();
                    break;
                  case SeasonMarkingBehavior.askEveryTime:
                    await _showSeasonMarkingSheet(
                      notifier: notifier,
                      settingsNotifier: settingsNotifier,
                      seasonNumber: selectedSeason,
                    );
                    break;
                }
              }
            },
          ),
        ),
        const SizedBox(height: 14),
        _SeasonProgressMeter(
          watchedEpisodes: watchedInSeason,
          totalEpisodes: episodeCount,
        ),
        const SizedBox(height: 20),
        if (_episodesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_seasonEpisodes.isEmpty)
          Text(
            'No episode information available for this season.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
          )
        else
          ListView.separated(
            key: PageStorageKey<String>(
              'episodes_list_${widget.show.id}_s$selectedSeason',
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _seasonEpisodes.length,
            separatorBuilder: (_, __) {
              return Divider(
                height: 1,
                color: scheme.outline.withValues(alpha: 0.24),
              );
            },
            itemBuilder: (context, index) {
              final episode = _seasonEpisodes[index];
              final episodeNumber =
                  (episode['episode_number'] as int?) ?? (index + 1);
              final title = (episode['name'] as String?)?.trim() ??
                  'Episode $episodeNumber';
              final stillPath = episode['still_path'] as String?;

              final episodeKey =
                  '${widget.show.id}:s${selectedSeason}e$episodeNumber';

              final isWatched =
                  progressItem?.watchedEpisodeKeys.contains(episodeKey) ??
                      false;

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EpisodeDetailsScreen(
                        show: widget.show,
                        seasonNumber: selectedSeason,
                        episodeNumber: episodeNumber,
                        episode: Map<String, dynamic>.from(episode),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox(
                          width: 104,
                          height: 58,
                          child: stillPath != null && stillPath.isNotEmpty
                              ? Image.network(
                                  'https://image.tmdb.org/t/p/w185$stillPath',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return _episodeImagePlaceholder(scheme);
                                  },
                                )
                              : _episodeImagePlaceholder(scheme),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 34,
                        child: Text(
                          'E${episodeNumber.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: isWatched
                                ? const Color(0xFF2EAF62)
                                : scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title.isEmpty ? 'Episode $episodeNumber' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isWatched
                                ? scheme.onSurface.withValues(alpha: 0.82)
                                : scheme.onSurface,
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _EpisodeWatchedButton(
                        selected: isWatched,
                        onPressed: () async {
                          await _ensureShowInProgress();

                          final isReleased = episode['air_date'] != null &&
                              episode['air_date']
                                  .toString()
                                  .trim()
                                  .isNotEmpty &&
                              DateTime.tryParse(
                                      episode['air_date'].toString()) !=
                                  null &&
                              !DateTime.tryParse(
                                      episode['air_date'].toString())!
                                  .isAfter(DateTime.now());

                          if (!isReleased) {
                            return;
                          }

                          if (isWatched) {
                            switch (watchSettings.episodeUnmarking) {
                              case EpisodeUnmarkingBehavior.laterReleased:
                                await notifier
                                    .markUnwatchedFromEpisodeIncludingFutureSeasons(
                                  tvId: widget.show.id,
                                  seasonNumber: selectedSeason,
                                  episodeNumber: episodeNumber,
                                );
                                await _refreshStatusSnapshot();
                                break;
                              case EpisodeUnmarkingBehavior.onlyThisEpisode:
                                await notifier.markSingleEpisodeUnwatched(
                                  tvId: widget.show.id,
                                  seasonNumber: selectedSeason,
                                  episodeNumber: episodeNumber,
                                );
                                await _refreshStatusSnapshot();
                                break;
                              case EpisodeUnmarkingBehavior.askEveryTime:
                                await _showEpisodeUnmarkingSheet(
                                  notifier: notifier,
                                  settingsNotifier: settingsNotifier,
                                  seasonNumber: selectedSeason,
                                  episodeNumber: episodeNumber,
                                );
                                break;
                            }
                          } else {
                            switch (watchSettings.episodeMarking) {
                              case EpisodeMarkingBehavior.previousReleased:
                                await notifier
                                    .toggleEpisodeWatchedIncludingPreviousSeasons(
                                  tvId: widget.show.id,
                                  seasonNumber: selectedSeason,
                                  episodeNumber: episodeNumber,
                                );
                                await _refreshStatusSnapshot();
                                break;
                              case EpisodeMarkingBehavior.onlyThisEpisode:
                                await notifier.markSingleEpisodeWatched(
                                  tvId: widget.show.id,
                                  seasonNumber: selectedSeason,
                                  episodeNumber: episodeNumber,
                                );
                                await _refreshStatusSnapshot();
                                break;
                              case EpisodeMarkingBehavior.askEveryTime:
                                await _showEpisodeMarkingSheet(
                                  notifier: notifier,
                                  settingsNotifier: settingsNotifier,
                                  seasonNumber: selectedSeason,
                                  episodeNumber: episodeNumber,
                                );
                                break;
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showEpisodeMarkingSheet({
    required TvProgressNotifier notifier,
    required SettingsNotifier settingsNotifier,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    final choice = await _showWatchChoiceSheet(
      title: 'Mark episode watched',
      options: const [
        'This episode only',
        'Previous released episodes',
      ],
    );

    if (!mounted || choice == null) {
      return;
    }

    final remember = choice.remember;

    if (remember) {
      settingsNotifier.setEpisodeMarkingBehavior(
        choice.isSingle
            ? EpisodeMarkingBehavior.onlyThisEpisode
            : EpisodeMarkingBehavior.previousReleased,
      );
    }

    if (choice.isSingle) {
      await notifier.markSingleEpisodeWatched(
        tvId: widget.show.id,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    } else {
      await notifier.toggleEpisodeWatchedIncludingPreviousSeasons(
        tvId: widget.show.id,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    }
  }

  Future<void> _showEpisodeUnmarkingSheet({
    required TvProgressNotifier notifier,
    required SettingsNotifier settingsNotifier,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    final choice = await _showWatchChoiceSheet(
      title: 'Unmark episode watched',
      options: const [
        'This episode only',
        'Later released episodes',
      ],
    );

    if (!mounted || choice == null) {
      return;
    }

    final remember = choice.remember;

    if (remember) {
      settingsNotifier.setEpisodeUnmarkingBehavior(
        choice.isSingle
            ? EpisodeUnmarkingBehavior.onlyThisEpisode
            : EpisodeUnmarkingBehavior.laterReleased,
      );
    }

    if (choice.isSingle) {
      await notifier.markSingleEpisodeUnwatched(
        tvId: widget.show.id,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    } else {
      await notifier.markUnwatchedFromEpisodeIncludingFutureSeasons(
        tvId: widget.show.id,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    }
  }

  Future<void> _showSeasonMarkingSheet({
    required TvProgressNotifier notifier,
    required SettingsNotifier settingsNotifier,
    required int seasonNumber,
  }) async {
    final choice = await _showWatchChoiceSheet(
      title: 'Mark season watched',
      options: const [
        'This season only',
        'Previous released seasons',
      ],
    );

    if (!mounted || choice == null) {
      return;
    }

    final remember = choice.remember;

    if (remember) {
      settingsNotifier.setSeasonMarkingBehavior(
        choice.isSingle
            ? SeasonMarkingBehavior.onlyThisSeason
            : SeasonMarkingBehavior.previousReleased,
      );
    }

    if (choice.isSingle) {
      await notifier.markSingleSeasonWatched(
        tvId: widget.show.id,
        seasonNumber: seasonNumber,
      );
    } else {
      await notifier.markSeasonWatchedIncludingPreviousSeasons(
        tvId: widget.show.id,
        seasonNumber: seasonNumber,
      );
    }

    await _refreshStatusSnapshot();
  }

  Future<void> _showSeasonUnmarkingSheet({
    required TvProgressNotifier notifier,
    required SettingsNotifier settingsNotifier,
    required int seasonNumber,
  }) async {
    final choice = await _showWatchChoiceSheet(
      title: 'Unmark season watched',
      options: const [
        'This season only',
        'Later released seasons',
      ],
    );

    if (!mounted || choice == null) {
      return;
    }

    final remember = choice.remember;

    if (remember) {
      settingsNotifier.setSeasonUnmarkingBehavior(
        choice.isSingle
            ? SeasonUnmarkingBehavior.onlyThisSeason
            : SeasonUnmarkingBehavior.laterReleased,
      );
    }

    if (choice.isSingle) {
      await notifier.markSingleSeasonUnwatched(
        tvId: widget.show.id,
        seasonNumber: seasonNumber,
      );
    } else {
      await notifier.markSeasonUnwatchedIncludingFutureSeasons(
        tvId: widget.show.id,
        seasonNumber: seasonNumber,
      );
    }

    await _refreshStatusSnapshot();
  }

  Future<_WatchChoice?> _showWatchChoiceSheet({
    required String title,
    required List<String> options,
  }) async {
    var remember = false;

    IconData iconFor(String option) {
      switch (option) {
        case 'This episode only':
        case 'This season only':
          return Icons.radio_button_checked_rounded;
        case 'Previous released episodes':
        case 'Previous released seasons':
          return Icons.history_rounded;
        case 'Later released episodes':
        case 'Later released seasons':
          return Icons.low_priority_rounded;
        default:
          return Icons.check_circle_outline_rounded;
      }
    }

    return showModalBottomSheet<_WatchChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final scheme = Theme.of(context).colorScheme;

            Widget buildOption(String option, bool isSingle) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(sheetContext).pop(
                      _WatchChoice(
                        isSingle: isSingle,
                        remember: remember,
                      ),
                    );
                  },
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.42,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          iconFor(option),
                          size: 22,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    buildOption(options[0], true),
                    const SizedBox(height: 8),
                    buildOption(options[1], false),
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setSheetState(() {
                            remember = !remember;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: remember,
                                onChanged: (value) {
                                  setSheetState(() {
                                    remember = value ?? false;
                                  });
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Remember this choice',
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _episodeImagePlaceholder(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_outlined,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _ensureShowInProgress() async {
    final notifier = ref.read(tvProgressProvider.notifier);

    if (notifier.getShowById(widget.show.id) != null) {
      return;
    }

    await notifier.addShow(
      TvProgress(
        id: widget.show.id,
        title: widget.show.title,
        posterPath: widget.show.posterPath,
        currentSeason: 1,
        currentEpisode: 1,
        watchedEpisodes: 0,
        totalEpisodes: details?.totalEpisodes ?? 0,
        totalSeasons: details?.totalSeasons ?? 0,
      ),
    );
  }

  Widget _buildPosterHeader(MovieDetails? show) {
    final fallbackPosterUrl = _posterUrlFor(widget.show.posterPath);
    final detailsPosterUrl = _detailsPosterUrl(show);
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              },
              errorWidget: (_, __, ___) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                      placeholder: (_, __) => _posterPlaceholder(),
                      errorWidget: (_, __, ___) => _posterPlaceholder(),
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

  Widget _buildTvPage() {
    final scheme = Theme.of(context).colorScheme;
    final tvProgress = ref.watch(tvProgressProvider);
    final notifier = ref.read(tvProgressProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final progressItem = tvProgress
        .where((progress) => progress.id == widget.show.id)
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
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildPosterHeader(show),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show?.title ?? widget.show.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildShowStatusButtons(),
                    const SizedBox(height: 24),
                    _SegmentSelector(
                      labels: const ['About', 'Episodes'],
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildShowAboutSections(),
                                  const SizedBox(height: 16),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: KeyedSubtree(
                                      key: ValueKey(_tvAboutSection),
                                      child:
                                          _buildShowAboutSelectedSection(show),
                                    ),
                                  ),
                                ],
                              )
                            : _buildTvEpisodes(
                                show,
                                progressItem,
                                notifier,
                                settings.watchProgressSettings,
                                settingsNotifier,
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
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.show.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _loadDetails(forceRefresh: true),
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

    return _buildTvPage();
  }
}

class _WatchChoice {
  final bool isSingle;
  final bool remember;

  const _WatchChoice({
    required this.isSingle,
    required this.remember,
  });
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
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;

  const _SkeletonLine({required this.width});

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

class _PremiumStatusButton extends StatefulWidget {
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
  State<_PremiumStatusButton> createState() => _PremiumStatusButtonState();
}

class _PremiumStatusButtonState extends State<_PremiumStatusButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final surfaceColor = widget.selected
        ? Color.alphaBlend(
            widget.selectedColor.withValues(alpha: 0.20),
            scheme.surface,
          )
        : scheme.surface.withValues(alpha: 0.74);

    final borderColor = widget.selected
        ? widget.selectedColor.withValues(alpha: 0.85)
        : scheme.outline.withValues(alpha: 0.20);

    final iconSurface = widget.selected
        ? widget.selectedColor.withValues(alpha: 0.22)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.62);

    final iconColor =
        widget.selected ? widget.selectedColor : scheme.onSurfaceVariant;

    final labelColor =
        widget.selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.965 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            height: 84,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderColor,
                width: widget.selected ? 1.4 : 1,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: widget.selectedColor.withValues(alpha: 0.18),
                        blurRadius: 22,
                        spreadRadius: 1,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                if (widget.selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(21),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.transparent,
                              widget.selectedColor.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconSurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.selected
                                ? widget.selectedColor.withValues(alpha: 0.48)
                                : scheme.outline.withValues(alpha: 0.18),
                          ),
                          boxShadow: widget.selected
                              ? [
                                  BoxShadow(
                                    color: widget.selectedColor
                                        .withValues(alpha: 0.20),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          widget.icon,
                          size: 22,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 7),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 11,
                          fontWeight: widget.selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          letterSpacing: 0.18,
                        ),
                        child: Text(widget.label),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonProgressButton extends StatefulWidget {
  final bool selected;
  final VoidCallback onPressed;

  const _SeasonProgressButton({
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_SeasonProgressButton> createState() => _SeasonProgressButtonState();
}

class _SeasonProgressButtonState extends State<_SeasonProgressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const watchedColor = Color(0xFF2EAF62);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: widget.selected
                ? Color.alphaBlend(
                    watchedColor.withValues(alpha: 0.22),
                    scheme.surface,
                  )
                : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: widget.selected
                  ? watchedColor.withValues(alpha: 0.82)
                  : scheme.outline.withValues(alpha: 0.24),
              width: widget.selected ? 1.3 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: watchedColor.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.selected
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                size: 19,
                color: widget.selected ? watchedColor : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                widget.selected ? 'Season Watched' : 'Mark Season Watched',
                style: TextStyle(
                  color: widget.selected
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonProgressMeter extends StatelessWidget {
  final int watchedEpisodes;
  final int totalEpisodes;

  const _SeasonProgressMeter({
    required this.watchedEpisodes,
    required this.totalEpisodes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const watchedColor = Color(0xFF2EAF62);

    final safeTotal = totalEpisodes < 0 ? 0 : totalEpisodes;
    final safeWatched =
        safeTotal == 0 ? 0 : watchedEpisodes.clamp(0, safeTotal);
    final progress = safeTotal == 0 ? 0.0 : safeWatched / safeTotal;
    final complete = safeTotal > 0 && safeWatched >= safeTotal;

    final label = safeTotal == 0
        ? 'Loading season progress'
        : complete
            ? 'Season complete'
            : '$safeWatched / $safeTotal watched';

    return Semantics(
      label: safeTotal == 0
          ? 'Loading season progress'
          : '$safeWatched of $safeTotal episodes watched',
      value: safeTotal == 0 ? null : '${(progress * 100).round()} percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete
                    ? Icons.check_circle_rounded
                    : Icons.play_circle_outline_rounded,
                size: 15,
                color: complete ? watchedColor : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: complete ? watchedColor : scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (safeTotal > 0)
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: complete ? watchedColor : scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 9,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.82,
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: progress,
                    ),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  watchedColor.withValues(alpha: 0.72),
                                  watchedColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: [
                                BoxShadow(
                                  color: watchedColor.withValues(alpha: 0.40),
                                  blurRadius: 9,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeWatchedButton extends StatefulWidget {
  final bool selected;
  final VoidCallback onPressed;

  const _EpisodeWatchedButton({
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_EpisodeWatchedButton> createState() => _EpisodeWatchedButtonState();
}

class _EpisodeWatchedButtonState extends State<_EpisodeWatchedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const watchedColor = Color(0xFF2EAF62);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.selected
                ? watchedColor.withValues(alpha: 0.18)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.selected
                  ? watchedColor.withValues(alpha: 0.86)
                  : scheme.outline.withValues(alpha: 0.25),
              width: widget.selected ? 1.4 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: watchedColor.withValues(alpha: 0.16),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.selected
                ? Icons.check_rounded
                : Icons.check_circle_outline_rounded,
            size: 21,
            color: widget.selected ? watchedColor : scheme.onSurfaceVariant,
          ),
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
