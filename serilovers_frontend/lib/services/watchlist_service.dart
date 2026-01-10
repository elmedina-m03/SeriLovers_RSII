import '../models/watchlist.dart';
import 'api_service.dart';

class WatchlistService {
  final ApiService _apiService;

  WatchlistService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<List<Watchlist>> getWatchlistsForUser(int userId, {String? token}) async {
    final response = await _apiService.get(
      '/WatchlistCollection?userId=$userId',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => Watchlist.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }

  Future<Watchlist> createWatchlist(Map<String, dynamic> payload, {String? token}) async {
    final response = await _apiService.post(
      '/WatchlistCollection',
      payload,
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return Watchlist.fromJson(response);
    } else {
      throw Exception('Invalid response format');
    }
  }

  Future<Map<String, dynamic>?> addSeriesToList(int listId, int seriesId, {String? token}) async {
    // Backend expects: POST /api/WatchlistCollection/{collectionId}/series/{seriesId}
    final response = await _apiService.post(
      '/WatchlistCollection/$listId/series/$seriesId',
      {}, // Empty body - seriesId is in the route
      token: token,
    );
    
    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
  }

  Future<void> removeSeriesFromList(int listId, int seriesId, {String? token}) async {
    await _apiService.delete(
      '/WatchlistCollection/$listId/series/$seriesId',
      token: token,
    );
  }

  /// Get a watchlist collection with its series
  Future<Map<String, dynamic>> getWatchlistCollection(int collectionId, {String? token}) async {
    final response = await _apiService.get(
      '/WatchlistCollection/$collectionId',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Delete a watchlist collection
  Future<void> deleteWatchlistCollection(int collectionId, {String? token}) async {
    await _apiService.delete(
      '/WatchlistCollection/$collectionId',
      token: token,
    );
  }
}


