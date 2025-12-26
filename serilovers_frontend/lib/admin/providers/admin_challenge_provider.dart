import 'package:flutter/foundation.dart';
import '../../models/challenge.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

/// Provider for managing admin challenge operations
/// 
/// Uses ChangeNotifier to notify listeners of challenge state changes.
/// Provides CRUD operations for challenge management in admin interface.
class AdminChallengeProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// List of challenge items
  List<Challenge> items = [];

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Top watchers from summary
  List<Map<String, dynamic>> topWatchers = [];

  /// Whether summary is loading
  bool isLoadingSummary = false;

  /// User challenge progress list
  List<Map<String, dynamic>> userProgress = [];

  /// Whether user progress is loading
  bool isLoadingProgress = false;

  /// Creates an AdminChallengeProvider instance
  /// 
  /// [apiService] - Service for making API requests
  /// [authProvider] - Provider for authentication (to get token)
  AdminChallengeProvider({
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

  /// Fetches all challenges from the API
  /// 
  /// Updates [items] and [isLoading] state.
  /// Notifies listeners on completion or error.
  Future<void> fetchAll() async {
    isLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final response = await _apiService.get('/Admin/Challenges', token: token);
      
      if (response is List) {
        items = response
            .map((item) => Challenge.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Invalid response format from server');
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ AdminChallengeProvider: Error fetching challenges: $e');
      rethrow;
    }
  }

  /// Creates a new challenge
  /// 
  /// [data] - Challenge data as a Map
  /// 
  /// Returns the created challenge or throws an exception on error.
  /// Updates the local items list and notifies listeners.
  Future<Challenge> createChallenge(Map<String, dynamic> data) async {
    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final response = await _apiService.post(
        '/Admin/Challenges',
        data,
        token: token,
      );

      final createdChallenge = Challenge.fromJson(response as Map<String, dynamic>);
      
      items.add(createdChallenge);
      notifyListeners();
      
      return createdChallenge;
    } catch (e) {
      print('❌ AdminChallengeProvider: Error creating challenge: $e');
      rethrow;
    }
  }

  /// Updates an existing challenge
  /// 
  /// [id] - ID of the challenge to update
  /// [data] - Updated challenge data as a Map
  /// 
  /// Returns the updated challenge or throws an exception on error.
  /// Updates the local items list and notifies listeners.
  Future<Challenge> updateChallenge(int id, Map<String, dynamic> data) async {
    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final response = await _apiService.put(
        '/Admin/Challenges/$id',
        data,
        token: token,
      );

      final updatedChallenge = Challenge.fromJson(response as Map<String, dynamic>);
      
      // Update in local list
      final index = items.indexWhere((c) => c.id == id);
      if (index != -1) {
        items[index] = updatedChallenge;
      } else {
        items.add(updatedChallenge);
      }
      notifyListeners();
      
      return updatedChallenge;
    } catch (e) {
      print('❌ AdminChallengeProvider: Error updating challenge: $e');
      rethrow;
    }
  }

  /// Deletes a challenge
  /// 
  /// [id] - ID of the challenge to delete
  /// 
  /// Throws an exception on error.
  /// Removes the challenge from the local items list and notifies listeners.
  Future<void> deleteChallenge(int id) async {
    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      await _apiService.delete(
        '/Admin/Challenges/$id',
        token: token,
      );

      items.removeWhere((challenge) => challenge.id == id);
      notifyListeners();
    } catch (e) {
      print('❌ AdminChallengeProvider: Error deleting challenge: $e');
      rethrow;
    }
  }

  /// Fetches challenges summary including top watchers
  Future<void> fetchSummary() async {
    isLoadingSummary = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final response = await _apiService.get('/Admin/Challenges/summary', token: token);
      
      if (response is Map<String, dynamic>) {
        final topWatchersList = response['topWatchers'] as List<dynamic>? ?? [];
        topWatchers = topWatchersList
            .map((item) => item as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Invalid response format from server');
      }

      isLoadingSummary = false;
      notifyListeners();
    } catch (e) {
      isLoadingSummary = false;
      notifyListeners();
      print('❌ AdminChallengeProvider: Error fetching summary: $e');
      rethrow;
    }
  }

  /// Fetches all user challenge progress from the API
  /// 
  /// Updates [userProgress] and [isLoadingProgress] state.
  /// Notifies listeners on completion or error.
  Future<void> fetchUserProgress() async {
    isLoadingProgress = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final response = await _apiService.get('/Admin/Challenges/progress', token: token);
      
      if (response is List) {
        userProgress = response
            .map((item) => item as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Invalid response format from server');
      }

      isLoadingProgress = false;
      notifyListeners();
    } catch (e) {
      isLoadingProgress = false;
      notifyListeners();
      print('❌ AdminChallengeProvider: Error fetching user progress: $e');
      rethrow;
    }
  }
}

