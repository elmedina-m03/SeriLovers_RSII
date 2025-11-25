import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../models/admin_statistics.dart';

/// Provider for managing admin statistics data
/// 
/// Uses ChangeNotifier to notify listeners of statistics state changes.
/// Provides dashboard statistics and chart data for admin interface.
class AdminStatisticsProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Statistics data model
  AdminStatistics? stats;

  /// Error message if fetch fails
  String? error;

  /// Creates an AdminStatisticsProvider instance
  /// 
  /// [apiService] - Service for making API requests
  /// [authProvider] - Provider for authentication (to get token)
  AdminStatisticsProvider({
    required ApiService apiService,
    required AuthProvider authProvider,
  })  : _apiService = apiService,
        _authProvider = authProvider {
    // Listen to auth provider changes to update token reference
    _authProvider.addListener(_onAuthChanged);
  }

  /// Called when AuthProvider changes (e.g., user logs in/out)
  void _onAuthChanged() {
    // Token might have changed, but we don't need to do anything here
    // The token is fetched fresh each time methods are called
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Updates the auth provider reference (used by ChangeNotifierProxyProvider)
  void updateAuthProvider(AuthProvider authProvider) {
    if (_authProvider != authProvider) {
      _authProvider.removeListener(_onAuthChanged);
      _authProvider = authProvider;
      _authProvider.addListener(_onAuthChanged);
    }
  }

  /// Fetches statistics from the API
  Future<void> fetchStats() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token available');
      }

      print('📡 AdminStatisticsProvider: Fetching statistics from /Admin/Statistics');
      final json = await _apiService.get('/Admin/Statistics', token: token);
      print('📥 AdminStatisticsProvider: Received response: ${json.runtimeType}');
      print('📥 AdminStatisticsProvider: Response data: $json');

      if (json == null) {
        throw Exception('Response is null');
      }

      if (json is! Map<String, dynamic>) {
        throw Exception('Unexpected response type: ${json.runtimeType}');
      }

      stats = AdminStatistics.fromJson(json);
      error = null;
      print('✅ AdminStatisticsProvider: Statistics loaded successfully');
      print('   Totals - Users: ${stats?.totals.users}, Series: ${stats?.totals.series}, Actors: ${stats?.totals.actors}, WatchlistItems: ${stats?.totals.watchlistItems}');
      print('   GenreDistribution: ${stats?.genreDistribution.length} items');
      print('   MonthlyWatching: ${stats?.monthlyWatching.length} items');
      print('   TopSeries: ${stats?.topSeries.length} items');
    } catch (e, stackTrace) {
      print('❌ AdminStatisticsProvider: Error fetching statistics: $e');
      print('Stack trace: $stackTrace');
      error = e.toString();
      stats = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes statistics data
  /// 
  /// Convenience method that calls fetchStats()
  Future<void> refresh() async {
    print('🔄 AdminStatisticsProvider: Refreshing statistics...');
    await fetchStats();
  }

  /// Checks if statistics data is available
  bool get hasData => stats != null;

  /// Gets totals object
  Totals get totals => stats?.totals ?? Totals(users: 0, series: 0, actors: 0, watchlistItems: 0);

  /// Gets total users count
  int get totalUsers => totals.users;

  /// Gets total series count
  int get totalSeries => totals.series;

  /// Gets total actors count
  int get totalActors => totals.actors;

  /// Gets total watchlist count
  int get totalWatchlistItems => totals.watchlistItems;

  /// Gets genre distribution
  List<GenreDistribution> get genreDistribution => stats?.genreDistribution ?? [];

  /// Gets monthly watching data
  List<MonthlyWatching> get monthlyWatching => stats?.monthlyWatching ?? [];

  /// Gets top rated series
  List<TopSeries> get topSeries => stats?.topSeries ?? [];
}
