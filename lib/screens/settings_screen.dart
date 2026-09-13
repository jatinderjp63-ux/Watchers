import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/watch_progress_settings.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final watchSettings = settings.watchProgressSettings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Watching behavior',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how episode and season progress should be applied.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _BehaviorSelector<EpisodeMarkingBehavior>(
            title: 'Episode marking',
            value: watchSettings.episodeMarking,
            items: const [
              DropdownMenuItem(
                value: EpisodeMarkingBehavior.previousReleased,
                child: Text('Previous released episodes'),
              ),
              DropdownMenuItem(
                value: EpisodeMarkingBehavior.onlyThisEpisode,
                child: Text('This episode only'),
              ),
              DropdownMenuItem(
                value: EpisodeMarkingBehavior.askEveryTime,
                child: Text('Ask every time'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                notifier.setEpisodeMarkingBehavior(value);
              }
            },
          ),
          const SizedBox(height: 12),
          _BehaviorSelector<EpisodeUnmarkingBehavior>(
            title: 'Episode unmarking',
            value: watchSettings.episodeUnmarking,
            items: const [
              DropdownMenuItem(
                value: EpisodeUnmarkingBehavior.laterReleased,
                child: Text('Later released episodes'),
              ),
              DropdownMenuItem(
                value: EpisodeUnmarkingBehavior.onlyThisEpisode,
                child: Text('This episode only'),
              ),
              DropdownMenuItem(
                value: EpisodeUnmarkingBehavior.askEveryTime,
                child: Text('Ask every time'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                notifier.setEpisodeUnmarkingBehavior(value);
              }
            },
          ),
          const SizedBox(height: 12),
          _BehaviorSelector<SeasonMarkingBehavior>(
            title: 'Season marking',
            value: watchSettings.seasonMarking,
            items: const [
              DropdownMenuItem(
                value: SeasonMarkingBehavior.previousReleased,
                child: Text('Previous released seasons'),
              ),
              DropdownMenuItem(
                value: SeasonMarkingBehavior.onlyThisSeason,
                child: Text('This season only'),
              ),
              DropdownMenuItem(
                value: SeasonMarkingBehavior.askEveryTime,
                child: Text('Ask every time'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                notifier.setSeasonMarkingBehavior(value);
              }
            },
          ),
          const SizedBox(height: 12),
          _BehaviorSelector<SeasonUnmarkingBehavior>(
            title: 'Season unmarking',
            value: watchSettings.seasonUnmarking,
            items: const [
              DropdownMenuItem(
                value: SeasonUnmarkingBehavior.laterReleased,
                child: Text('Later released seasons'),
              ),
              DropdownMenuItem(
                value: SeasonUnmarkingBehavior.onlyThisSeason,
                child: Text('This season only'),
              ),
              DropdownMenuItem(
                value: SeasonUnmarkingBehavior.askEveryTime,
                child: Text('Ask every time'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                notifier.setSeasonUnmarkingBehavior(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _BehaviorSelector<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _BehaviorSelector({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: title,
            border: InputBorder.none,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
