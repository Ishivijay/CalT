import 'package:flutter/foundation.dart';

/// Which bottom-nav tab `MainScreen` currently shows. A locator singleton
/// rather than local `State` so other screens (the calorie ring, the coach
/// card) can jump the user to a specific tab without needing a `BuildContext`
/// that's actually above `MainScreen` in the tree — `HomePage` is a sibling
/// tab, not an ancestor of `DiaryPage`, so `DefaultTabController`/named-route
/// tricks don't reach across; a shared notifier does.
class MainTabController extends ValueNotifier<int> {
  MainTabController() : super(0);

  static const homeIndex = 0;
  static const diaryIndex = 1;
  static const trendsIndex = 2;
  static const profileIndex = 3;

  void showDiary() => value = diaryIndex;
}
