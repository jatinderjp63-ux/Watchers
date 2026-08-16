import 'package:flutter/material.dart';

import '../models/home_section_entry.dart';
import '../widgets/home_media_card.dart';

class HomeSectionScreen extends StatelessWidget {
  final String title;
  final List<HomeSectionEntry> items;

  const HomeSectionScreen({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                'Nothing here yet.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : GridView.builder(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24,
              ),
              itemCount: items.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 18,
                mainAxisExtent: 250,
              ),
              itemBuilder: (context, index) {
                final entry = items[index];

                return HomeMediaCard(
                  movie: entry.movie,
                  heroTag: entry.heroTag,
                  primaryText: entry.primaryText,
                  secondaryText: entry.secondaryText,
                  tertiaryText: entry.tertiaryText,
                  cardWidth: double.infinity,
                  sourceTab: 'home',
                );
              },
            ),
    );
  }
}