import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/next_airing_provider.dart';
import 'providers/settings_provider.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: WatchersApp(),
    ),
  );
}

class WatchersApp extends ConsumerStatefulWidget {
  const WatchersApp({super.key});

  @override
  ConsumerState<WatchersApp> createState() {
    return _WatchersAppState();
  }
}

class _WatchersAppState
    extends ConsumerState<WatchersApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      // The provider returns cached data immediately when it is
      // still fresh. If stale, it refreshes the data.
      ref.invalidate(nextAiringProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Watchers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      themeAnimationDuration: Duration.zero,
      routerConfig: appRouter,
    );
  }
}