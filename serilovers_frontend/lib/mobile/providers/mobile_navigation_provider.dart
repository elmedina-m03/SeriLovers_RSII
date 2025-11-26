import 'package:flutter/foundation.dart';

/// Provider for managing mobile navigation state
/// 
/// Tracks the current selected tab index in the bottom navigation bar.
class MobileNavigationProvider extends ChangeNotifier {
  /// Current selected tab index (0-3)
  /// 0 = Home
  /// 1 = Categories
  /// 2 = Lists (Watchlist)
  /// 3 = Profile
  int _currentIndex = 0;

  /// Gets the current selected tab index
  int get currentIndex => _currentIndex;

  /// Sets the current selected tab index
  /// 
  /// [index] - The tab index to select (0-3)
  void setIndex(int index) {
    if (index >= 0 && index <= 3) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}

