import 'package:flutter/foundation.dart';
import '../models/episode_review.dart';
import '../services/episode_review_service.dart';
import 'auth_provider.dart';

class EpisodeReviewProvider extends ChangeNotifier {
  final EpisodeReviewService _service;
  AuthProvider? _authProvider;

  EpisodeReviewProvider({
    required EpisodeReviewService service,
    AuthProvider? authProvider,
  })  : _service = service,
        _authProvider = authProvider;

  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  bool loading = false;
  String? error;

  // Cache for episode reviews
  final Map<int, List<EpisodeReview>> _episodeReviewsCache = {};
  final Map<int, EpisodeReview?> _myReviewsCache = {};

  List<EpisodeReview> getEpisodeReviews(int episodeId) {
    return _episodeReviewsCache[episodeId] ?? [];
  }

  EpisodeReview? getMyReview(int episodeId) {
    return _myReviewsCache[episodeId];
  }

  /// Load reviews for an episode
  Future<void> loadEpisodeReviews(int episodeId) async {
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final reviews = await _service.getEpisodeReviews(episodeId, token: token);
      _episodeReviewsCache[episodeId] = reviews;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Load current user's review for an episode
  Future<void> loadMyReview(int episodeId) async {
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final review = await _service.getMyReview(episodeId, token: token);
      _myReviewsCache[episodeId] = review;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Create or update a review
  Future<void> createOrUpdateReview({
    required int episodeId,
    required int rating,
    String? reviewText,
    bool isAnonymous = false,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final review = await _service.createOrUpdateReview(
        episodeId: episodeId,
        rating: rating,
        reviewText: reviewText,
        isAnonymous: isAnonymous,
        token: token,
      );

      // Update caches
      _myReviewsCache[episodeId] = review;
      
      // Add to reviews list if not already there
      final reviews = _episodeReviewsCache[episodeId] ?? [];
      final existingIndex = reviews.indexWhere((r) => r.id == review.id);
      if (existingIndex >= 0) {
        reviews[existingIndex] = review;
      } else {
        reviews.add(review);
        reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      _episodeReviewsCache[episodeId] = reviews;

      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Delete a review
  Future<void> deleteReview(int reviewId, int episodeId) async {
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      await _service.deleteReview(reviewId, token: token);

      // Update caches
      _myReviewsCache[episodeId] = null;
      final reviews = _episodeReviewsCache[episodeId] ?? [];
      reviews.removeWhere((r) => r.id == reviewId);
      _episodeReviewsCache[episodeId] = reviews;

      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

