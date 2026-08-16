import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tvmaze_service.dart';

final tvMazeServiceProvider = Provider<TvMazeService>((ref) {
  return TvMazeService();
});