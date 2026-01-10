import '../models/series_recommendation.dart';
import 'api_service.dart';

class RecommendationService {
  final ApiService _apiService;

  RecommendationService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Get personalized recommendations for a user
  Future<List<SeriesRecommendation>> getRecommendations({
    required int userId,
    int maxResults = 10,
    String? token,
  }) async {
    final response = await _apiService.get(
      '/Recommendations/$userId?maxResults=$maxResults',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => SeriesRecommendation.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Get recommendations for the current authenticated user
  Future<List<SeriesRecommendation>> getMyRecommendations({
    int maxResults = 10,
    String? token,
  }) async {
    // Use the better RecommendationService endpoint that considers:
    // - Watched episodes
    // - Ratings/reviews
    // - Watchlists (favorites and custom lists)
    // Path is /Recommendations/me (baseUrl already includes /api)
    final response = await _apiService.get(
      '/Recommendations/me?maxResults=$maxResults',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => SeriesRecommendation.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }
}

