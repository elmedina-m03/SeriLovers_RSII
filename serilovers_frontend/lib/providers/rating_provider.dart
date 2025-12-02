import 'package:flutter/foundation.dart';
import '../models/rating.dart';
import '../services/rating_service.dart';
import 'auth_provider.dart';

class RatingProvider extends ChangeNotifier {
  final RatingService _service;
  AuthProvider? _authProvider;

  RatingProvider({
    required RatingService service,
    AuthProvider? authProvider,
  })  : _service = service,
        _authProvider = authProvider;

  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  bool loading = false;
  String? error;

  // Cache for series ratings
  final Map<int, List<Rating>> _seriesRatingsCache = {};
  final Map<int, Rating?> _myRatingsCache = {};

  List<Rating> getSeriesRatings(int seriesId) {
    return _seriesRatingsCache[seriesId] ?? [];
  }

  Rating? getMyRating(int seriesId) {
    return _myRatingsCache[seriesId];
  }

  /// Load ratings for a series
  /// Note: Viewing reviews is public and doesn't require authentication
  Future<void> loadSeriesRatings(int seriesId) async {
    loading = true;
    notifyListeners();

    try {
      // Token is optional for viewing reviews (public endpoint)
      final token = _authProvider?.token;
      final ratings = await _service.getSeriesRatings(seriesId, token: token);
      _seriesRatingsCache[seriesId] = ratings;
      error = null;
    } catch (e) {
      error = e.toString();
      // Don't throw - allow viewing reviews even if there's an error
      _seriesRatingsCache[seriesId] = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Load current user's rating for a series
  Future<void> loadMyRating(int seriesId) async {
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final rating = await _service.getMyRating(seriesId, token: token);
      _myRatingsCache[seriesId] = rating;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Create or update a rating
  Future<void> createOrUpdateRating({
    required int seriesId,
    required int score,
    String? comment,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final rating = await _service.createOrUpdateRating(
        seriesId: seriesId,
        score: score,
        comment: comment,
        token: token,
      );

      // Update caches
      _myRatingsCache[seriesId] = rating;
      
      // Add to ratings list if not already there
      final ratings = _seriesRatingsCache[seriesId] ?? [];
      final existingIndex = ratings.indexWhere((r) => r.id == rating.id);
      if (existingIndex >= 0) {
        ratings[existingIndex] = rating;
      } else {
        ratings.add(rating);
        ratings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      _seriesRatingsCache[seriesId] = ratings;

      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Delete a rating
  Future<void> deleteRating(int ratingId, int seriesId) async {
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      await _service.deleteRating(ratingId, token: token);

      // Update caches
      _myRatingsCache[seriesId] = null;
      final ratings = _seriesRatingsCache[seriesId] ?? [];
      ratings.removeWhere((r) => r.id == ratingId);
      _seriesRatingsCache[seriesId] = ratings;

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

