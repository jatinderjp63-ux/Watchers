import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie.dart';
import '../models/tv_progress.dart';
import '../providers/tv_progress_provider.dart';
import '../services/retry_helper.dart';
import '../services/tmdb_service.dart';

class EpisodeDetailsScreen extends ConsumerStatefulWidget {
  final Movie show;
  final int seasonNumber;
  final int episodeNumber;
  final Map episode;

  const EpisodeDetailsScreen({
    super.key,
    required this.show,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episode,
  });

  @override
  ConsumerState createState() => _EpisodeDetailsScreenState();
}

class _EpisodeDetailsScreenState extends ConsumerState<EpisodeDetailsScreen> {
  final TmdbService _tmdbService = TmdbService();

  late Map _episodeData;
  bool _detailsLoading = false;

  @override
  void initState() {
    super.initState();
    _episodeData = Map.from(widget.episode);
    _loadFullEpisodeDetails();
  }

  Future<void> _loadFullEpisodeDetails() async {
    if (_detailsLoading) return;

    setState(() {
      _detailsLoading = true;
    });

    try {
      final loadedDetails = await retryCall(
        () => _tmdbService.getEpisodeDetails(
          widget.show.id,
          widget.seasonNumber,
          widget.episodeNumber,
        ),
      );

      if (!mounted) return;

      setState(() {
        _episodeData = {
          ..._episodeData,
          ...loadedDetails,
        };
        _detailsLoading = false;
      });
    } catch (error) {
      debugPrint('Episode details error: $error');

      if (!mounted) return;

      setState(() {
        _detailsLoading = false;
      });
    }
  }

  String get _title {
    final value = _episodeData['name']?.toString().trim() ?? '';
    return value.isEmpty ? 'Episode ${widget.episodeNumber}' : value;
  }

  String get _overview {
    final value = _episodeData['overview']?.toString().trim() ?? '';
    return value.isEmpty ? 'No episode description available.' : value;
  }

  String? get _stillUrl {
    final path = _episodeData['still_path']?.toString().trim() ?? '';

    if (path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return 'https://image.tmdb.org/t/p/w780$path';
  }

  String get _formattedCode {
    final season = widget.seasonNumber.toString().padLeft(2, '0');
    final episode = widget.episodeNumber.toString().padLeft(2, '0');
    return 'S$season E$episode';
  }

  String get _formattedRuntime {
    final rawRuntime = _episodeData['runtime'];

    int? runtime;
    if (rawRuntime is int) {
      runtime = rawRuntime;
    } else if (rawRuntime is num) {
      runtime = rawRuntime.toInt();
    } else {
      runtime = int.tryParse(rawRuntime?.toString() ?? '');
    }

    if (runtime == null || runtime <= 0) {
      return '-';
    }

    return '$runtime min';
  }

  String get _formattedDate {
    final rawDate = _episodeData['air_date']?.toString().trim() ?? '';

    if (rawDate.isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(rawDate);
    if (date == null) {
      return rawDate;
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get _formattedDirector {
    final rawCrew = _episodeData['crew'];

    if (rawCrew is! List) {
      return '-';
    }

    final directors = rawCrew
        .whereType<Map>()
        .where((member) {
          final job = member['job']?.toString().toLowerCase() ?? '';
          return job == 'director';
        })
        .map((member) => member['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    return directors.isEmpty ? '-' : directors.join(', ');
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
        totalEpisodes: 0,
        totalSeasons: 0,
      ),
    );
  }

  Future<void> _toggleWatched() async {
    await _ensureShowInProgress();

    final notifier = ref.read(tvProgressProvider.notifier);
    
    await notifier.toggleEpisodeWatchedIncludingPreviousSeasons(
      tvId: widget.show.id,
      seasonNumber: widget.seasonNumber,
      episodeNumber: widget.episodeNumber,
    );
  }

  Widget _buildStillImage(ColorScheme scheme) {
    final stillUrl = _stillUrl;

    if (stillUrl == null) {
      return Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.movie_outlined,
          color: scheme.onSurfaceVariant,
          size: 48,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: stillUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) {
        return Container(color: scheme.surfaceContainerHighest);
      },
      errorWidget: (_, __, ___) {
        return Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            color: scheme.onSurfaceVariant,
            size: 42,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    final progressItems = ref.watch(tvProgressProvider);
    final progress = progressItems.where((item) => item.id == widget.show.id).firstOrNull;
    final episodeKey = '${widget.show.id}:s${widget.seasonNumber}e${widget.episodeNumber}';
    final isWatched = progress?.watchedEpisodeKeys.contains(episodeKey) ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                SizedBox(
                  height: 278,
                  width: double.infinity,
                  child: _buildStillImage(scheme),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 12,
                  left: 16,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.52),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      tooltip: 'Back',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                MediaQuery.paddingOf(context).bottom + 150,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formattedCode,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 27,
                      height: 1.16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _EpisodeProgressButton(
                    selected: isWatched,
                    onPressed: _toggleWatched,
                  ),
                  const SizedBox(height: 28),
                  Divider(
                    height: 1,
                    color: scheme.outline.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Overview',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _overview,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                      height: 1.52,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Divider(
                    height: 1,
                    color: scheme.outline.withValues(alpha: 0.28),
                  ),
                  const SizedBox(height: 22),
                  _EpisodeInfoLine(
                    label: 'Director',
                    value: _formattedDirector,
                  ),
                  _EpisodeInfoLine(
                    label: 'Runtime',
                    value: _formattedRuntime,
                  ),
                  _EpisodeInfoLine(
                    label: 'Date',
                    value: _formattedDate,
                  ),
                  if (_detailsLoading) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          height: 13,
                          width: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.7,
                            color: scheme.primary.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading episode information',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeProgressButton extends StatefulWidget {
  final bool selected;
  final VoidCallback onPressed;

  const _EpisodeProgressButton({
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_EpisodeProgressButton> createState() => _EpisodeProgressButtonState();
}

class _EpisodeProgressButtonState extends State<_EpisodeProgressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const watchedColor = Color(0xFF2EAF62);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.selected ? 'Watched' : 'Mark Watched',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.selected
                  ? Color.alphaBlend(
                      watchedColor.withValues(alpha: 0.20),
                      scheme.surface,
                    )
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.selected
                    ? watchedColor.withValues(alpha: 0.84)
                    : scheme.outline.withValues(alpha: 0.24),
                width: widget.selected ? 1.35 : 1,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: watchedColor.withValues(alpha: 0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.selected
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  color: widget.selected ? watchedColor : scheme.onSurfaceVariant,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Text(
                  widget.selected ? 'Watched' : 'Mark Watched',
                  style: TextStyle(
                    color: widget.selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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

class _EpisodeInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _EpisodeInfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}