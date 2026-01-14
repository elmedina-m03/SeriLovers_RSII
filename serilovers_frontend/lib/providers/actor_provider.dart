import 'package:flutter/foundation.dart';
import '../models/series.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// Provider for managing actor data
class ActorProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// List of actors
  List<Actor> items = [];

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Creates an ActorProvider instance
  ActorProvider({
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

  /// Fetches all actors from the API
  Future<void> fetchActors() async {
    isLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final response = await _apiService.get('/Actor', token: token);

      if (response is List) {
        items = response
            .map((item) => Actor.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        items = [];
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes an actor
  Future<void> deleteActor(int actorId) async {
    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token available');
      }

      await _apiService.delete('/Actor/$actorId', token: token);
      items.removeWhere((actor) => actor.id == actorId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}

