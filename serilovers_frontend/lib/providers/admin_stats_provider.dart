import 'package:flutter/foundation.dart';
import '../models/genre_distribution.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// Provider for managing admin statistics data
class AdminStatsProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// Total number of users
  int usersCount = 0;

  /// Total number of series
  int seriesCount = 0;

  /// Total number of actors
  int actorsCount = 0;

  /// Total number of ratings
  int ratingsCount = 0;

  /// Total number of watchlist entries
  int watchlistCount = 0;

  /// List of genre distribution statistics
  List<GenreDistribution> genreStats = [];

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Creates an AdminStatsProvider instance
  AdminStatsProvider({
    required ApiService apiService,
    required AuthProvider authProvider,
  })  : _apiService = apiService,
        _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  /// Called when AuthProvider changes
  void _onAuthChanged() {
    // Token might have changed
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Updates the auth provider reference
  void updateAuthProvider(AuthProvider authProvider) {
    if (_authProvider != authProvider) {
      _authProvider.removeListener(_onAuthChanged);
      _authProvider = authProvider;
      _authProvider.addListener(_onAuthChanged);
    }
  }

  /// Fetches admin statistics from the API
  Future<void> fetchStats() async {
    isLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final response = await _apiService.get('/AdminStats/stats', token: token);

      if (response is Map<String, dynamic>) {
        usersCount = response['usersCount'] as int? ?? 0;
        seriesCount = response['seriesCount'] as int? ?? 0;
        actorsCount = response['actorsCount'] as int? ?? 0;
        ratingsCount = response['ratingsCount'] as int? ?? 0;
        watchlistCount = response['watchlistCount'] as int? ?? 0;

        // Parse genre distribution
        if (response['genreDistribution'] is List) {
          final genreList = response['genreDistribution'] as List<dynamic>;
          genreStats = genreList
              .map((item) => GenreDistribution.fromJson(
                    item as Map<String, dynamic>,
                  ))
              .toList();
        } else {
          genreStats = [];
        }
      } else {
        throw Exception('Invalid response format from server');
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}

