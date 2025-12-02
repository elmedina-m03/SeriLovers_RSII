import '../models/rating.dart';
import 'api_service.dart';

class RatingService {
  final ApiService _apiService;

  RatingService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Get all ratings for a series
  Future<List<Rating>> getSeriesRatings(int seriesId, {String? token}) async {
    final response = await _apiService.get(
      '/Rating/series/$seriesId',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => Rating.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Get current user's rating for a series
  Future<Rating?> getMyRating(int seriesId, {String? token}) async {
    try {
      // Get all user ratings and find the one for this series
      final response = await _apiService.get(
        '/Rating',
        token: token,
      );

      if (response is List) {
        final ratings = response
            .map((item) => Rating.fromJson(item as Map<String, dynamic>))
            .toList();
        try {
          return ratings.firstWhere(
            (r) => r.seriesId == seriesId,
          );
        } catch (_) {
          // Not found
          return null;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create or update a rating
  Future<Rating> createOrUpdateRating({
    required int seriesId,
    required int score,
    String? comment,
    String? token,
  }) async {
    final response = await _apiService.post(
      '/Rating',
      {
        'seriesId': seriesId,
        'score': score,
        'comment': comment,
      },
      token: token,
    );

    // Response format: { "message": "...", "rating": {...} }
    if (response is Map<String, dynamic>) {
      if (response.containsKey('rating')) {
        return Rating.fromJson(response['rating'] as Map<String, dynamic>);
      } else {
        return Rating.fromJson(response);
      }
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Delete a rating
  Future<void> deleteRating(int ratingId, {String? token}) async {
    await _apiService.delete(
      '/Rating/$ratingId',
      token: token,
    );
  }

  /// Get all ratings by a specific user
  Future<List<Rating>> getUserRatings(int userId, {String? token}) async {
    final response = await _apiService.get(
      '/Rating/user/$userId',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => Rating.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }
}

