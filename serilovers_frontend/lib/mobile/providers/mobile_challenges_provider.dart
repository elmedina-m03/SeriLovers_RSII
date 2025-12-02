import 'package:flutter/foundation.dart';
import '../../models/challenge.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

/// Provider for managing mobile challenges
class MobileChallengesProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// Updates the auth provider reference (used by ChangeNotifierProxyProvider)
  void updateAuthProvider(AuthProvider authProvider) {
    if (_authProvider != authProvider) {
      _authProvider.removeListener(_onAuthChanged);
      _authProvider = authProvider;
      _authProvider.addListener(_onAuthChanged);
    }
  }

  /// List of all available challenges
  List<Challenge> availableChallenges = [];

  /// List of user's challenge progress
  List<Map<String, dynamic>> myProgress = [];

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Current page for pagination
  int currentPage = 1;

  /// Page size for pagination
  int pageSize = 10;

  /// Total number of challenges
  int totalCount = 0;

  MobileChallengesProvider({
    required ApiService apiService,
    required AuthProvider authProvider,
  })  : _apiService = apiService,
        _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    // Token might have changed
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Fetches all available challenges
  Future<void> fetchAvailableChallenges({int? page, int? pageSize}) async {
    isLoading = true;
    notifyListeners();

    try {
      if (page != null) currentPage = page;
      if (pageSize != null) this.pageSize = pageSize;

      // Public endpoint - no auth required
      final response = await _apiService.get('/Challenges');

      if (response is List) {
        availableChallenges = response
            .map((item) => Challenge.fromJson(item as Map<String, dynamic>))
            .toList();
        totalCount = availableChallenges.length;
      } else {
        throw Exception('Invalid response format from server');
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ MobileChallengesProvider: Error fetching challenges: $e');
      rethrow;
    }
  }

  /// Fetches user's challenge progress
  Future<void> fetchMyProgress() async {
    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        // User not logged in, clear progress
        myProgress = [];
        notifyListeners();
        return;
      }

      final response = await _apiService.get('/Challenges/my-progress', token: token);

      if (response is List) {
        myProgress = response
            .map((item) => item as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Invalid response format from server');
      }

      notifyListeners();
    } catch (e) {
      print('❌ MobileChallengesProvider: Error fetching progress: $e');
      rethrow;
    }
  }

  /// Starts a challenge for the current user
  Future<void> startChallenge(int challengeId) async {
    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      await _apiService.post(
        '/Challenges/$challengeId/start',
        {},
        token: token,
      );

      // Refresh progress and challenges after starting
      await fetchMyProgress();
      await fetchAvailableChallenges();
      
      notifyListeners();
    } catch (e) {
      print('❌ MobileChallengesProvider: Error starting challenge: $e');
      // Don't rethrow - let the UI handle the error gracefully
      // The error will be shown in the UI via SnackBar
      throw Exception('Failed to start challenge. Please try again later.');
    }
  }

  /// Gets progress for a specific challenge
  Map<String, dynamic>? getProgressForChallenge(int challengeId) {
    try {
      final progressItem = myProgress.firstWhere(
        (p) => (p['challenge'] as Map<String, dynamic>?)?['id'] == challengeId,
        orElse: () => {},
      );
      
      if (progressItem.isEmpty) return null;
      
      return progressItem['progress'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Checks if user has started a challenge
  bool hasStartedChallenge(int challengeId) {
    return getProgressForChallenge(challengeId) != null;
  }
}

