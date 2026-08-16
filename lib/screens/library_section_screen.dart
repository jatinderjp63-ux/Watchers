import 'package:flutter/material.dart';

import '../models/home_section_entry.dart';
import '../widgets/home_media_card.dart';

class LibrarySectionScreen extends StatelessWidget {
  final String title;
  final List<HomeSectionEntry> items;

  const LibrarySectionScreen({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                'Nothing here yet.',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
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
                mainAxisSpacing: 16,
                childAspectRatio: 0.53,
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
                  sourceTab: 'library',
                );
              },
            ),
    );
  }
}