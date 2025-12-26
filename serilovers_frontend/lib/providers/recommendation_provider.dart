import 'package:flutter/foundation.dart';
import '../models/series_recommendation.dart';
import '../services/recommendation_service.dart';
import '../providers/auth_provider.dart';

class RecommendationProvider extends ChangeNotifier {
  final RecommendationService _service;
  AuthProvider _authProvider;

  List<SeriesRecommendation> _recommendations = [];
  bool _isLoading = false;
  String? _error;

  RecommendationProvider({
    required RecommendationService service,
    required AuthProvider authProvider,
  })  : _service = service,
        _authProvider = authProvider;

  /// Updates the auth provider reference (used by ChangeNotifierProxyProvider)
  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  List<SeriesRecommendation> get recommendations => _recommendations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasRecommendations => _recommendations.isNotEmpty;

  /// Fetch recommendations for the current user
  Future<void> fetchRecommendations({int maxResults = 10}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final recommendations = await _service.getMyRecommendations(
        maxResults: maxResults,
        token: token,
      );

      _recommendations = recommendations;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _recommendations = [];
      debugPrint('Error fetching recommendations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh recommendations (useful after user marks episodes as watched)
  Future<void> refresh() async {
    await fetchRecommendations();
  }

  /// Clear recommendations
  void clear() {
    _recommendations = [];
    _error = null;
    notifyListeners();
  }
}

