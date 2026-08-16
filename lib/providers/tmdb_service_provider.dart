import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tmdb_service.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService();
});