import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_library_item.dart';
import '../models/media_status.dart';
import '../models/movie.dart';
import '../providers/library_provider.dart';

class MediaStatusButtons extends ConsumerWidget {
  final Movie movie;

  const MediaStatusButtons({
    super.key,
    required this.movie,
  });

  bool get _isTv => movie.mediaType == "tv";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);

    MediaLibraryItem? existing;
    for (final item in library) {
      if (item.id == movie.id) {
        existing = item;
        break;
      }
    }

    final currentStatus = existing?.status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "My Status",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ...(_isTv
              ? _buildTvButtons(
                  context,
                  ref,
                  currentStatus,
                )
              : _buildMovieButtons(
                  context,
                  ref,
                  currentStatus,
                )),
        ],
      ),
    );
  }

  List<Widget> _buildMovieButtons(
    BuildContext context,
    WidgetRef ref,
    MediaStatus? currentStatus,
  ) {
    return [
      _statusButton(
        context: context,
        ref: ref,
        currentStatus: currentStatus,
        status: MediaStatus.planning,
        label: "Planning",
        icon: Icons.bookmark_add,
        color: Colors.blue,
      ),
      _statusButton(
        context: context,
        ref: ref,
        currentStatus: currentStatus,
        status: MediaStatus.watched,
        label: "Watched",
        icon: Icons.check_circle,
        color: Colors.green,
      ),
    ];
  }

  List<Widget> _buildTvButtons(
    BuildContext context,
    WidgetRef ref,
    MediaStatus? currentStatus,
  ) {
    return [
      _statusButton(
        context: context,
        ref: ref,
        currentStatus: currentStatus,
        status: MediaStatus.planning,
        label: "Planned",
        icon: Icons.bookmark_add,
        color: Colors.blue,
      ),
      _statusButton(
        context: context,
        ref: ref,
        currentStatus: currentStatus,
        status: MediaStatus.watched,
        label: "Watched",
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      _statusButton(
        context: context,
        ref: ref,
        currentStatus: currentStatus,
        status: MediaStatus.dropped,
        label: "Dropped",
        icon: Icons.cancel,
        color: Colors.red,
      ),
    ];
  }

  Widget _statusButton({
    required BuildContext context,
    required WidgetRef ref,
    required MediaStatus? currentStatus,
    required MediaStatus status,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final selected = currentStatus == status;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: selected ? color : surfaceColor,
            foregroundColor: selected ? Colors.white : onSurface,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: selected
                ? null
                : BorderSide(color: Theme.of(context).dividerColor),
          ),
          onPressed: () async {
            final libraryNotifier = ref.read(libraryProvider.notifier);

            if (selected) {
              await libraryNotifier.removeMedia(movie.id);
              return;
            }

            await libraryNotifier.upsertMovieStatus(
              movie,
              status,
            );
          },
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}