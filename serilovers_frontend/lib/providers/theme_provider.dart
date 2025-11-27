import 'package:flutter/foundation.dart';
import '../core/theme/app_theme.dart';

/// Provider for managing app theme (light/dark mode)
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  /// Whether dark mode is currently enabled
  bool get isDarkMode => _isDarkMode;

  /// Get the current theme (light or dark)
  get currentTheme => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  /// Toggle between light and dark mode
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  /// Set dark mode explicitly
  void setDarkMode(bool isDark) {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();
    }
  }
}

