import 'package:flutter/foundation.dart';
import '../models/series.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// Provider for managing watchlist data
/// 
/// Uses ChangeNotifier to notify listeners of watchlist state changes.
/// Manages watchlist items and provides methods to add/remove series.
class WatchlistProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// List of series in the watchlist
  List<Series> items = [];

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Creates a WatchlistProvider instance
  /// 
  /// [apiService] - Service for making API requests
  /// [authProvider] - Provider for authentication (to get token)
  WatchlistProvider({
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
    // The token is fetched fresh each time a method is called
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

  /// Fetches the user's watchlist from the API
  /// 
  /// [token] - Authentication token for the API request
  /// 
  /// Fetches all series in the current user's watchlist and updates [items].
  /// Parses full series objects from the backend response.
  /// Notifies listeners on completion or error.
  /// 
  /// Throws [ApiException] if the request fails.
  Future<void> fetchWatchlist(String token) async {
    isLoading = true;
    notifyListeners();

    try {
      if (token.isEmpty) {
        throw ApiException('Authentication required. Please log in.');
      }

      // Make API request to get watchlist
      final response = await _apiService.get(
        '/Watchlist',
        token: token,
      );

      // Parse response
      if (response is List) {
        // Extract Series objects from watchlist entries
        // The response is a list of WatchlistDto objects
        // Each entry has a 'series' property with full SeriesDto data
        final seriesList = <Series>[];
        
        for (var entry in response) {
          if (entry is Map<String, dynamic>) {
            // Check if Series data is included in the response
            if (entry.containsKey('series') && entry['series'] != null) {
              try {
                final seriesData = entry['series'] as Map<String, dynamic>;
                seriesList.add(Series.fromJson(seriesData));
              } catch (e) {
                print('Error parsing series from watchlist entry: $e');
                print('Series data: ${entry['series']}');
                // Skip entries with invalid Series data
              }
            } else {
              print('Warning: Watchlist entry missing series data. Entry: $entry');
            }
          }
        }

        items = seriesList;
        isLoading = false;
        notifyListeners();
      } else {
        throw ApiException('Invalid response format from server. Expected a list of watchlist entries.');
      }
    } on ApiException catch (e) {
      isLoading = false;
      notifyListeners();
      print('Error fetching watchlist: ${e.message} (Status: ${e.statusCode})');
      rethrow;
    } catch (e, stackTrace) {
      isLoading = false;
      notifyListeners();
      print('Unexpected error fetching watchlist: $e');
      print('Stack trace: $stackTrace');
      throw ApiException('Failed to fetch watchlist: ${e.toString()}');
    }
  }

  /// Loads the user's watchlist from the API (backward compatibility)
  /// 
  /// Uses AuthProvider to get the token automatically.
  /// 
  /// Throws [ApiException] if the request fails.
  Future<void> loadWatchlist() async {
    final token = _authProvider.token;
    if (token == null || token.isEmpty) {
      throw ApiException('Authentication required. Please log in.');
    }
    await fetchWatchlist(token);
  }

  /// Adds a series to the watchlist
  /// 
  /// [seriesId] - The ID of the series to add to the watchlist
  /// 
  /// After successful addition, reloads the watchlist to update [items].
  /// Notifies listeners on completion or error.
  /// 
  /// Throws [ApiException] if the request fails or series is already in watchlist.
  Future<void> addToWatchlist(int seriesId) async {
    try {
      // Get authentication token
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw ApiException('Authentication required. Please log in.');
      }

      // Make API request to add to watchlist
      final response = await _apiService.post(
        '/Watchlist',
        {'seriesId': seriesId},
        token: token,
      );

      // Check response message
      if (response is Map<String, dynamic>) {
        final message = response['message'] as String? ?? '';
        
        if (message.contains('already in watchlist')) {
          // Series is already in watchlist - reload to ensure state is correct
          await loadWatchlist();
          throw ApiException('This series is already in your watchlist.', 400);
        }
        
        if (message.contains('added to watchlist')) {
          // Successfully added - reload watchlist
          await loadWatchlist();
          return;
        }
      }

      // If we get here, reload watchlist anyway to ensure consistency
      await loadWatchlist();
    } on ApiException catch (e) {
      print('Error adding to watchlist: ${e.message} (Status: ${e.statusCode})');
      
      // If the error message already indicates it's in watchlist, use that message
      if (e.message.contains('already in your watchlist')) {
        rethrow; // Keep the original message
      }
      
      // Create user-friendly error message for other errors
      String errorMessage = 'Failed to add series to watchlist.';
      if (e.statusCode == 400) {
        errorMessage = 'Invalid series ID or series does not exist.';
      } else if (e.statusCode == 401) {
        errorMessage = 'Authentication required. Please log in.';
      } else if (e.statusCode == 404) {
        errorMessage = 'Series not found.';
      }
      
      throw ApiException(errorMessage, e.statusCode);
    } catch (e, stackTrace) {
      print('Unexpected error adding to watchlist: $e');
      print('Stack trace: $stackTrace');
      throw ApiException('Failed to add series to watchlist: ${e.toString()}');
    }
  }

  /// Removes a series from the watchlist
  /// 
  /// [seriesId] - The ID of the series to remove from the watchlist
  /// [token] - Authentication token for the API request
  /// 
  /// After successful removal, updates [items] by removing the series locally
  /// and notifies listeners. Also reloads the watchlist to ensure consistency.
  /// 
  /// Throws [ApiException] if the request fails or series is not in watchlist.
  Future<void> removeFromWatchlist(int seriesId, String token) async {
    try {
      if (token.isEmpty) {
        throw ApiException('Authentication required. Please log in.');
      }

      // Make API request to remove from watchlist
      await _apiService.delete(
        '/Watchlist/$seriesId',
        token: token,
      );

      // Remove from local list immediately for better UX
      items.removeWhere((series) => series.id == seriesId);
      notifyListeners();

      // Reload watchlist to ensure consistency with server
      await fetchWatchlist(token);
    } on ApiException catch (e) {
      print('Error removing from watchlist: ${e.message} (Status: ${e.statusCode})');
      
      // Create user-friendly error message
      String errorMessage = 'Failed to remove series from watchlist.';
      if (e.statusCode == 401) {
        errorMessage = 'Authentication required. Please log in.';
      } else if (e.statusCode == 404) {
        errorMessage = 'Series not found in your watchlist.';
      }
      
      throw ApiException(errorMessage, e.statusCode);
    } catch (e, stackTrace) {
      print('Unexpected error removing from watchlist: $e');
      print('Stack trace: $stackTrace');
      throw ApiException('Failed to remove series from watchlist: ${e.toString()}');
    }
  }

  /// Removes a series from the watchlist (backward compatibility)
  /// 
  /// Uses AuthProvider to get the token automatically.
  /// 
  /// Throws [ApiException] if the request fails or series is not in watchlist.
  Future<void> removeFromWatchlistAuto(int seriesId) async {
    final token = _authProvider.token;
    if (token == null || token.isEmpty) {
      throw ApiException('Authentication required. Please log in.');
    }
    await removeFromWatchlist(seriesId, token);
  }

  /// Checks if a series is in the watchlist
  /// 
  /// [seriesId] - The ID of the series to check
  /// 
  /// Returns true if the series is in the watchlist, false otherwise.
  bool isInWatchlist(int seriesId) {
    return items.any((series) => series.id == seriesId);
  }
}

