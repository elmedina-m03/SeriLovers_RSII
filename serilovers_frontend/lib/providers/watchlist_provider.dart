import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../models/watchlist.dart';
import '../models/series.dart';
import '../services/watchlist_service.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// Provider for managing user watchlists (lists of series collections).
class WatchlistProvider extends ChangeNotifier {
  final WatchlistService? service;
  final ApiService? _apiService;
  AuthProvider? _authProvider;

  /// All watchlists for the current user (collections).
  List<Watchlist> lists = <Watchlist>[];

  /// Series items in the user's watchlist (backward compatibility).
  List<Series> items = <Series>[];

  /// Whether a request is currently in progress.
  bool loading = false;

  /// Alias for backward compatibility.
  bool get isLoading => loading;

  /// Last error message, if any.
  String? error;

  WatchlistProvider({
    this.service,
    ApiService? apiService,
    AuthProvider? authProvider,
  })  : _apiService = apiService,
        _authProvider = authProvider;

  /// Updates the auth provider reference (used by ChangeNotifierProxyProvider).
  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  // ========== New API Methods (Collections) ==========

  Future<void> loadUserWatchlists(int userId) async {
    if (service == null) return;
    
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      lists = await service!.getWatchlistsForUser(userId, token: token);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Cache for favorites list to avoid repeated lookups
  Watchlist? _cachedFavoritesList;

  Future<void> createList(
    String name, {
    String? coverUrl,
    String? description,
    String? category,
    String? status,
  }) async {
    if (service == null) return;
    
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final payload = <String, dynamic>{
        'name': name,
        if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
        if (description != null && description.isNotEmpty) 'description': description,
        if (category != null && category.isNotEmpty) 'category': category,
        if (status != null && status.isNotEmpty) 'status': status,
      };

      final created = await service!.createWatchlist(payload, token: token);
      lists = List<Watchlist>.from(lists)..add(created);
      error = null;
      
      // Clear favorites cache if a new favorites list was created
      if (created.name.toLowerCase() == 'favorites' || created.name.toLowerCase() == 'favourite') {
        _cachedFavoritesList = created;
      }
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addSeries(int listId, int seriesId) async {
    if (service == null) return;
    
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }
      await service!.addSeriesToList(listId, seriesId, token: token);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Get or create a Favorites watchlist collection
  Future<Watchlist> getOrCreateFavoritesList() async {
    if (service == null) {
      throw Exception('WatchlistService not available');
    }
    
    final token = _authProvider?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required');
    }

    // Use cached favorites list if available and still in lists
    if (_cachedFavoritesList != null) {
      final stillExists = lists.any((list) => list.id == _cachedFavoritesList!.id);
      if (stillExists) {
        return _cachedFavoritesList!;
      }
      _cachedFavoritesList = null; // Clear cache if list was deleted
    }

    // Check if Favorites list already exists in current lists
    final favoritesList = lists.firstWhere(
      (list) => list.name.toLowerCase() == 'favorites' || list.name.toLowerCase() == 'favourite',
      orElse: () => Watchlist(id: -1, name: '', coverUrl: '', totalSeries: 0, createdAt: DateTime.now()),
    );

    if (favoritesList.id != -1) {
      _cachedFavoritesList = favoritesList; // Cache it
      return favoritesList;
    }

    // If not found, reload lists from server in case it exists
    try {
      final decoded = JwtDecoder.decode(token);
      final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
      int? userId;
      if (rawId is int) {
        userId = rawId;
      } else if (rawId is String) {
        userId = int.tryParse(rawId);
      }
      if (userId != null) {
        await loadUserWatchlists(userId);
        final found = lists.firstWhere(
          (list) => list.name.toLowerCase() == 'favorites' || list.name.toLowerCase() == 'favourite',
          orElse: () => Watchlist(id: -1, name: '', coverUrl: '', totalSeries: 0, createdAt: DateTime.now()),
        );
        if (found.id != -1) {
          _cachedFavoritesList = found; // Cache it
          return found;
        }
      }
    } catch (_) {
      // Continue to create if reload fails
    }

    // Create Favorites list if it doesn't exist
    try {
      await createList(
        'Favorites',
        description: 'Your favorite series',
        category: 'Favorites',
      );
      // Find the newly created list
      final created = lists.firstWhere(
        (list) => list.name.toLowerCase() == 'favorites' || list.name.toLowerCase() == 'favourite',
        orElse: () => Watchlist(id: -1, name: '', coverUrl: '', totalSeries: 0, createdAt: DateTime.now()),
      );
      if (created.id != -1) {
        _cachedFavoritesList = created; // Cache it
        return created;
      }
      throw Exception('Failed to create Favorites list');
    } catch (e) {
      // If creation fails, try to find it again (might have been created by another request)
      final authProvider = _authProvider;
      if (authProvider?.token != null) {
        try {
          final decoded = JwtDecoder.decode(authProvider!.token!);
          final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
          int? userId;
          if (rawId is int) {
            userId = rawId;
          } else if (rawId is String) {
            userId = int.tryParse(rawId);
          }
          if (userId != null) {
            await loadUserWatchlists(userId);
            final found = lists.firstWhere(
              (list) => list.name.toLowerCase() == 'favorites' || list.name.toLowerCase() == 'favourite',
              orElse: () => Watchlist(id: -1, name: '', coverUrl: '', totalSeries: 0, createdAt: DateTime.now()),
            );
            if (found.id != -1) {
              _cachedFavoritesList = found; // Cache it
              return found;
            }
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Check if a series is in the Favorites list
  Future<bool> isInFavorites(int seriesId) async {
    try {
      final favoritesList = await getOrCreateFavoritesList();
      if (favoritesList.id == -1) return false;
      
      // Get the collection details to check if series is in it
      final collectionData = await service!.getWatchlistCollection(favoritesList.id, token: _authProvider?.token);
      final watchlists = collectionData['watchlists'] as List?;
      if (watchlists == null) return false;
      
      return watchlists.any((w) {
        if (w is Map<String, dynamic>) {
          final series = w['series'] as Map<String, dynamic>?;
          return series != null && series['id'] == seriesId;
        }
        return false;
      });
    } catch (_) {
      return false;
    }
  }

  /// Toggle series in Favorites list
  Future<void> toggleFavorites(int seriesId) async {
    try {
      // Get favorites list first
      final favoritesList = await getOrCreateFavoritesList();
      
      // Check if already in favorites by checking the collection
      final collectionData = await service!.getWatchlistCollection(favoritesList.id, token: _authProvider?.token);
      final watchlists = collectionData['watchlists'] as List?;
      final isFavorite = watchlists != null && watchlists.any((w) {
        if (w is Map<String, dynamic>) {
          final series = w['series'] as Map<String, dynamic>?;
          return series != null && series['id'] == seriesId;
        }
        return false;
      });
      
      if (isFavorite) {
        await removeSeriesFromList(favoritesList.id, seriesId);
      } else {
        await addSeries(favoritesList.id, seriesId);
      }
      
      // Refresh the lists to update counts
      final authProvider = _authProvider;
      if (authProvider?.token != null) {
        try {
          final decoded = JwtDecoder.decode(authProvider!.token!);
          final rawId = decoded['userId'] ?? decoded['id'] ?? decoded['nameid'] ?? decoded['sub'];
          int? userId;
          if (rawId is int) {
            userId = rawId;
          } else if (rawId is String) {
            userId = int.tryParse(rawId);
          }
          if (userId != null) {
            await loadUserWatchlists(userId);
            // Update cache
            _cachedFavoritesList = lists.firstWhere(
              (list) => list.id == favoritesList.id,
              orElse: () => favoritesList,
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      error = e.toString();
      rethrow;
    }
  }

  Future<void> removeSeriesFromList(int listId, int seriesId) async {
    if (service == null) return;
    
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }
      await service!.removeSeriesFromList(listId, seriesId, token: token);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Get a watchlist collection with its series
  Future<Map<String, dynamic>> getWatchlistCollection(int collectionId) async {
    if (service == null) {
      throw Exception('WatchlistService not available');
    }
    
    final token = _authProvider?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required');
    }
    
    return await service!.getWatchlistCollection(collectionId, token: token);
  }

  /// Finds the "Favorites" list for the current user
  Watchlist? get favoritesList {
    return lists.firstWhere(
      (list) => list.name.toLowerCase() == 'favorites',
      orElse: () => lists.isNotEmpty ? lists.first : Watchlist(
        id: 0,
        name: 'Favorites',
        coverUrl: '',
        totalSeries: 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  // ========== Backward Compatibility Methods (Series Watchlist) ==========

  /// Fetches the user's watchlist series from the API (backward compatibility).
  Future<void> fetchWatchlist(String token) async {
    if (_apiService == null) return;
    
    loading = true;
    notifyListeners();

    try {
      final response = await _apiService!.get('/Watchlist', token: token);
      
      if (response is List) {
        items = <Series>[];
        for (var entry in response) {
          if (entry is Map<String, dynamic>) {
            if (entry.containsKey('series') && entry['series'] != null) {
              try {
                final seriesData = entry['series'] as Map<String, dynamic>;
                items.add(Series.fromJson(seriesData));
              } catch (e) {
                // Skip invalid entries
              }
            }
          }
        }
        error = null;
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Loads the user's watchlist (backward compatibility).
  Future<void> loadWatchlist() async {
    final token = _authProvider?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in.');
    }
    await fetchWatchlist(token);
  }

  /// Adds a series to the watchlist (backward compatibility).
  Future<void> addToWatchlist(int seriesId, {String? token}) async {
    if (_apiService == null) {
      throw Exception('ApiService not available');
    }
    
    // Get token from auth provider if not provided
    final authToken = token ?? _authProvider?.token;
    if (authToken == null || authToken.isEmpty) {
      throw Exception('Authentication required. Please log in.');
    }
    
    try {
      final response = await _apiService!.post(
        '/Watchlist',
        {'seriesId': seriesId},
        token: authToken,
      );
      
      // Check if already in watchlist
      if (response is Map<String, dynamic>) {
        final message = response['message'] as String? ?? '';
        if (message.contains('already in watchlist')) {
          // Reload to ensure state is correct
          await fetchWatchlist(authToken);
          return;
        }
      }
      
      // Reload watchlist after adding
      await fetchWatchlist(authToken);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Removes a series from the watchlist (backward compatibility).
  Future<void> removeFromWatchlist(int seriesId, String token) async {
    if (_apiService == null) return;
    
    try {
      await _apiService!.delete('/Watchlist/$seriesId', token: token);
      
      // Remove from local list immediately
      items.removeWhere((series) => series.id == seriesId);
      notifyListeners();
      
      // Reload to ensure consistency
      await fetchWatchlist(token);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Checks if a series is in the watchlist (backward compatibility).
  bool isInWatchlist(int seriesId) {
    return items.any((series) => series.id == seriesId);
  }
}
