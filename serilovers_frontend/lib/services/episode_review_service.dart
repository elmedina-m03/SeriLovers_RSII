import '../models/episode_review.dart';
import 'api_service.dart';

class EpisodeReviewService {
  final ApiService _apiService;

  EpisodeReviewService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Get all reviews for an episode
  Future<List<EpisodeReview>> getEpisodeReviews(
    int episodeId, {
    String? token,
  }) async {
    final response = await _apiService.get(
      '/EpisodeReview/episode/$episodeId',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => EpisodeReview.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Get current user's review for an episode
  Future<EpisodeReview?> getMyReview(
    int episodeId, {
    String? token,
  }) async {
    try {
      final response = await _apiService.get(
        '/EpisodeReview/episode/$episodeId/my-review',
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return EpisodeReview.fromJson(response);
      }
      return null;
    } catch (e) {
      // Review doesn't exist
      return null;
    }
  }

  /// Create or update a review for an episode
  Future<EpisodeReview> createOrUpdateReview({
    required int episodeId,
    required int rating,
    String? reviewText,
    String? token,
  }) async {
    final response = await _apiService.post(
      '/EpisodeReview',
      {
        'episodeId': episodeId,
        'rating': rating,
        if (reviewText != null && reviewText.isNotEmpty) 'reviewText': reviewText,
      },
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return EpisodeReview.fromJson(response);
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Update an existing review
  Future<EpisodeReview> updateReview({
    required int reviewId,
    required int rating,
    String? reviewText,
    String? token,
  }) async {
    final response = await _apiService.put(
      '/EpisodeReview/$reviewId',
      {
        'rating': rating,
        if (reviewText != null && reviewText.isNotEmpty) 'reviewText': reviewText,
      },
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return EpisodeReview.fromJson(response);
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Delete a review
  Future<void> deleteReview(int reviewId, {String? token}) async {
    await _apiService.delete(
      '/EpisodeReview/$reviewId',
      token: token,
    );
  }

  /// Get all reviews by current user
  Future<List<EpisodeReview>> getMyReviews({String? token}) async {
    final response = await _apiService.get(
      '/EpisodeReview/my-reviews',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => EpisodeReview.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }
}

