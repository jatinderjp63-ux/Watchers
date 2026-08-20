import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/home_section_entry.dart';
import '../models/movie.dart';
import '../screens/account_screen.dart';
import '../screens/actor_details_screen.dart';
import '../screens/actor_filmography_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/home_screen.dart';
import '../screens/home_section_screen.dart';
import '../screens/library_screen.dart';
import '../screens/library_section_screen.dart';
import '../screens/main_shell.dart';
import '../screens/movie_details_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> homeNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> libraryNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> discoverNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> profileNavigatorKey =
    GlobalKey<NavigatorState>();

Widget _detailsRoute(GoRouterState state) {
  final extra = state.extra;

  if (extra is! Map<String, dynamic>) {
    return const RouterErrorScreen(
      message: 'Movie details data is missing.',
    );
  }

  final movie = extra['movie'];

  if (movie is! Movie) {
    return const RouterErrorScreen(
      message: 'Movie data is missing.',
    );
  }

  final heroTag = extra['heroTag'];

  return MovieDetailsScreen(
    movie: movie,
    heroTag: heroTag is String ? heroTag : '',
  );
}

Widget _actorRoute(GoRouterState state) {
  final extra = state.extra;

  if (extra is! Map<String, dynamic>) {
    return const RouterErrorScreen(
      message: 'Actor data is missing.',
    );
  }

  final personId = extra['personId'];
  final initialName = extra['initialName'];
  final initialProfilePath = extra['initialProfilePath'];

  if (personId is! int ||
      personId <= 0 ||
      initialName is! String ||
      initialName.trim().isEmpty) {
    return const RouterErrorScreen(
      message: 'Actor data is invalid.',
    );
  }

  return ActorDetailsScreen(
    personId: personId,
    initialName: initialName.trim(),
    initialProfilePath:
        initialProfilePath is String ? initialProfilePath : '',
  );
}

Widget _actorFilmographyRoute(GoRouterState state) {
  final extra = state.extra;

  if (extra is! Map<String, dynamic>) {
    return const RouterErrorScreen(
      message: 'Filmography data is missing.',
    );
  }

  final personName = extra['personName'];
  final mediaType = extra['mediaType'];
  final items = extra['items'];

  if (personName is! String ||
      (mediaType != 'movie' && mediaType != 'tv') ||
      items is! List) {
    return const RouterErrorScreen(
      message: 'Filmography data is invalid.',
    );
  }

  try {
    return ActorFilmographyScreen(
      personName: personName,
      mediaType: mediaType,
      items: items.cast<Movie>(),
    );
  } catch (_) {
    return const RouterErrorScreen(
      message: 'Filmography items are invalid.',
    );
  }
}

Widget _homeSectionRoute(GoRouterState state) {
  final extra = state.extra;

  if (extra is! Map<String, dynamic>) {
    return const RouterErrorScreen(
      message: 'Home section data is missing.',
    );
  }

  final title = extra['title'];
  final items = extra['items'];

  if (title is! String || items is! List) {
    return const RouterErrorScreen(
      message: 'Home section data is invalid.',
    );
  }

  return HomeSectionScreen(
    title: title,
    items: items.cast<HomeSectionEntry>(),
  );
}

Widget _librarySectionRoute(GoRouterState state) {
  final extra = state.extra;

  if (extra is! Map<String, dynamic>) {
    return const RouterErrorScreen(
      message: 'Library section data is missing.',
    );
  }

  final title = extra['title'];
  final items = extra['items'];

  if (title is! String || items is! List) {
    return const RouterErrorScreen(
      message: 'Library section data is invalid.',
    );
  }

  return LibrarySectionScreen(
    title: title,
    items: items.cast<HomeSectionEntry>(),
  );
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) {
        return MainShell(
          navigationShell: navigationShell,
        );
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: homeNavigatorKey,
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) {
                return const NoTransitionPage(
                  child: HomePage(),
                );
              },
              routes: [
                GoRoute(
                  path: 'details',
                  builder: (context, state) {
                    return _detailsRoute(state);
                  },
                ),
                GoRoute(
                  path: 'section',
                  builder: (context, state) {
                    return _homeSectionRoute(state);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: libraryNavigatorKey,
          routes: [
            GoRoute(
              path: '/library',
              pageBuilder: (context, state) {
                return const NoTransitionPage(
                  child: LibraryScreen(),
                );
              },
              routes: [
                GoRoute(
                  path: 'details',
                  builder: (context, state) {
                    return _detailsRoute(state);
                  },
                ),
                GoRoute(
                  path: 'section',
                  builder: (context, state) {
                    return _librarySectionRoute(state);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: discoverNavigatorKey,
          routes: [
            GoRoute(
              path: '/discover',
              pageBuilder: (context, state) {
                return const NoTransitionPage(
                  child: DiscoverScreen(),
                );
              },
              routes: [
                GoRoute(
                  path: 'details',
                  builder: (context, state) {
                    return _detailsRoute(state);
                  },
                ),
                GoRoute(
                  path: 'actor',
                  builder: (context, state) {
                    return _actorRoute(state);
                  },
                  routes: [
                    GoRoute(
                      path: 'filmography',
                      builder: (context, state) {
                        return _actorFilmographyRoute(state);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: profileNavigatorKey,
          routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) {
                return const NoTransitionPage(
                  child: ProfileScreen(),
                );
              },
              routes: [
                GoRoute(
                  path: 'details',
                  builder: (context, state) {
                    return _detailsRoute(state);
                  },
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) {
                    return const SettingsScreen();
                  },
                ),
                GoRoute(
                  path: 'statistics',
                  builder: (context, state) {
                    return const StatisticsScreen();
                  },
                ),
                GoRoute(
                  path: 'account',
                  builder: (context, state) {
                    return const AccountScreen();
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class RouterErrorScreen extends StatelessWidget {
  final String message;

  const RouterErrorScreen({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Error'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}