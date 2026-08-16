import 'package:flutter/foundation.dart';

/// Simple notifier for tab-specific events.
///
/// Used so each tab can:
/// - Pop its child page when the tab button is tapped while a child is open.
/// - Scroll to the top when the tab button is tapped again on the root page.
class TabNavigationService {
  TabNavigationService._();

  static final ValueNotifier<int> homeTapSignal =
      ValueNotifier<int>(0);

  static final ValueNotifier<int> libraryTapSignal =
      ValueNotifier<int>(0);

  static final ValueNotifier<int> discoverTapSignal =
      ValueNotifier<int>(0);

  static final ValueNotifier<int> profileTapSignal =
      ValueNotifier<int>(0);

  static void notifyHomeTabTapped() {
    homeTapSignal.value++;
  }

  static void notifyLibraryTabTapped() {
    libraryTapSignal.value++;
  }

  static void notifyDiscoverTabTapped() {
    discoverTapSignal.value++;
  }

  static void notifyProfileTabTapped() {
    profileTapSignal.value++;
  }
}