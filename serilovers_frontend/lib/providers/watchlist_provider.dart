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

  /// Tracks series that are currently being deleted to prevent duplicate requests.
  /// Key format: "listId:seriesId"
  final Set<String> _deletingSeries = <String>{};

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

  DateTime? _lastLoadUserWatchlistsTime;
  int? _lastLoadUserWatchlistsUserId;
  static const _loadUserWatchlistsCacheTimeout = Duration(seconds: 2); // Cache for 2 seconds

  Future<void> loadUserWatchlists(int userId) async {
    if (service == null) {
      loading = false;
      notifyListeners();
      return;
    }
    
    // Prevent duplicate calls within cache timeout for the same user
    final now = DateTime.now();
    if (_lastLoadUserWatchlistsTime != null && 
        _lastLoadUserWatchlistsUserId == userId &&
        now.difference(_lastLoadUserWatchlistsTime!) < _loadUserWatchlistsCacheTimeout &&
        lists.isNotEmpty) {
      // Return cached data if available and not expired
      loading = false;
      notifyListeners();
      return;
    }
    
    loading = true;
    notifyListeners();

    try {
      _lastLoadUserWatchlistsTime = now;
      _lastLoadUserWatchlistsUserId = userId;
      final token = _authProvider?.token;
      lists = await service!.getWatchlistsForUser(userId, token: token);
      
      // Clean up duplicate Favorites folders - keep only the first one
      await _cleanupDuplicateFavorites(token);
      
      // Ensure default Favorites folder exists (create if missing)
      // BUT don't call getOrCreateFavoritesList here as it might cause infinite loop
      // Just check if it exists, and if not, it will be created when needed
      final hasFavorites = lists.any((list) {
        final name = list.name.toLowerCase();
        return name == 'favorites' || name == 'favourite';
      });
      
      // Don't auto-create here to prevent loops - let it be created on-demand
      
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Remove duplicate Favorites folders, keeping only the first one
  Future<void> _cleanupDuplicateFavorites(String? token) async {
    if (token == null || token.isEmpty || service == null) return;
    
    final favoritesLists = lists.where((list) {
      final name = list.name.toLowerCase();
      return name == 'favorites' || name == 'favourite';
    }).toList();
    
    // If there's more than one Favorites folder, delete the duplicates
    if (favoritesLists.length > 1) {
      // Keep the first one (oldest or first in list)
      final keepList = favoritesLists.first;
      
      // Delete all others
      for (var duplicate in favoritesLists.skip(1)) {
        try {
          await service!.deleteWatchlistCollection(duplicate.id, token: token);
          lists.removeWhere((list) => list.id == duplicate.id);
        } catch (e) {
          // Log error but continue with other deletions
          print('Error deleting duplicate Favorites folder: $e');
        }
      }
      
      // Update cache to the kept list
      _cachedFavoritesList = keepList;
    } else if (favoritesLists.length == 1) {
      // Update cache to the single Favorites list
      _cachedFavoritesList = favoritesLists.first;
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

      // Prevent creating duplicate Favorites folders
      final nameLower = name.toLowerCase();
      if (nameLower == 'favorites' || nameLower == 'favourite') {
        // Check if Favorites already exists
        final existingFavorites = lists.firstWhere(
          (list) {
            final listName = list.name.toLowerCase();
            return listName == 'favorites' || listName == 'favourite';
          },
          orElse: () => Watchlist(id: -1, name: '', coverUrl: '', totalSeries: 0, createdAt: DateTime.now()),
        );
        
        if (existingFavorites.id != -1) {
          throw Exception('A Favorites folder already exists. You cannot create duplicate Favorites folders.');
        }
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
      
      // Update favorites cache if a new favorites list was created
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
    
    loading = true;
    notifyListeners();
    
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }
      final response = await service!.addSeriesToList(listId, seriesId, token: token);
      
      // Check if series is already in the collection
      if (response != null && response['message'] != null) {
        final message = response['message'] as String?;
        if (message != null && message.toLowerCase().contains('already')) {
          // Throw a user-friendly exception that will be caught and displayed nicely
          throw Exception('Series already in this collection');
        }
      }
      
      error = null;
      
      // Always refresh all lists to get accurate counts from backend
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
            // Reload all lists to get accurate counts from backend
            await loadUserWatchlists(userId);
          }
        } catch (_) {
          // If refresh fails, try to update the specific list manually
          final index = lists.indexWhere((list) => list.id == listId);
          if (index != -1) {
            lists[index] = Watchlist(
              id: lists[index].id,
              name: lists[index].name,
              coverUrl: lists[index].coverUrl,
              totalSeries: lists[index].totalSeries + 1,
              createdAt: lists[index].createdAt,
            );
            notifyListeners();
          }
        }
      }
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
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
    // First, check again if it was created by another request
    try {
      final authProvider = _authProvider;
      if (authProvider?.token != null) {
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
          // Check again if Favorites exists
          final existing = lists.firstWhere(
            (list) => list.name.toLowerCase() == 'favorites' || list.name.toLowerCase() == 'favourite',
            orElse: () => Watchlist(id: -1, name: '', coverUrl: '', totalSeries: 0, createdAt: DateTime.now()),
          );
          if (existing.id != -1) {
            _cachedFavoritesList = existing;
            return existing;
          }
        }
      }
    } catch (_) {
      // Continue to create
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

  /// Check if a series is currently being deleted
  bool isDeletingSeries(int listId, int seriesId) {
    return _deletingSeries.contains('$listId:$seriesId');
  }

  Future<void> removeSeriesFromList(int listId, int seriesId) async {
    if (service == null) return;
    
    // Guard: Prevent duplicate delete requests
    final deleteKey = '$listId:$seriesId';
    if (_deletingSeries.contains(deleteKey)) {
      return; // Already deleting, ignore duplicate request
    }
    
    final token = _authProvider?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required');
    }
    
    // Optimistically update UI: Remove from local state immediately
    final listIndex = lists.indexWhere((list) => list.id == listId);
    if (listIndex != -1) {
      lists[listIndex] = Watchlist(
        id: lists[listIndex].id,
        name: lists[listIndex].name,
        coverUrl: lists[listIndex].coverUrl,
        totalSeries: (lists[listIndex].totalSeries - 1).clamp(0, double.infinity).toInt(),
        createdAt: lists[listIndex].createdAt,
      );
    }
    
    // Mark as deleting and notify listeners
    _deletingSeries.add(deleteKey);
    loading = true;
    notifyListeners();
    
    try {
      // Make API call
      await service!.removeSeriesFromList(listId, seriesId, token: token);
      error = null;
      
      // Refresh all lists to get accurate counts from backend
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
            // Reload all lists to get accurate counts from backend
            await loadUserWatchlists(userId);
          }
        } catch (_) {
          // If refresh fails, the optimistic update already handled the UI
        }
      }
    } catch (e) {
      error = e.toString();
      // Rollback optimistic update on error
      if (listIndex != -1) {
        lists[listIndex] = Watchlist(
          id: lists[listIndex].id,
          name: lists[listIndex].name,
          coverUrl: lists[listIndex].coverUrl,
          totalSeries: (lists[listIndex].totalSeries + 1).clamp(0, double.infinity).toInt(),
          createdAt: lists[listIndex].createdAt,
        );
      }
      rethrow;
    } finally {
      _deletingSeries.remove(deleteKey);
      loading = false;
      notifyListeners();
    }
  }

  /// Delete a watchlist collection
  Future<void> deleteList(int listId) async {
    if (service == null) return;

    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Check if this is the Favorites list - prevent deletion
      final listToDelete = lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => Watchlist(id: -1, name: '', coverUrl: '', totalSeries: 0, createdAt: DateTime.now()),
      );

      if (listToDelete.id == -1) {
        throw Exception('List not found');
      }

      final nameLower = listToDelete.name.toLowerCase();
      if (nameLower == 'favorites' || nameLower == 'favourite') {
        throw Exception('The default Favorites folder cannot be deleted.');
      }

      await service!.deleteWatchlistCollection(listId, token: token);
      lists.removeWhere((list) => list.id == listId);
      _cachedFavoritesList = null; // Clear cache if needed
      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
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
  /// Uses caching to prevent duplicate calls.
  DateTime? _lastFetchTime;
  static const _fetchCacheTimeout = Duration(seconds: 2); // Cache for 2 seconds
  
  Future<void> fetchWatchlist(String token) async {
    if (_apiService == null) {
      loading = false;
      notifyListeners();
      return;
    }
    
    // Prevent duplicate calls within cache timeout (but only if we have data)
    final now = DateTime.now();
    if (_lastFetchTime != null && 
        now.difference(_lastFetchTime!) < _fetchCacheTimeout &&
        items.isNotEmpty) {
      // Return cached data if available and not expired
      loading = false;
      notifyListeners();
      return;
    }
    
    loading = true;
    notifyListeners();

    try {
      _lastFetchTime = now;
      final response = await _apiService!.get('/Watchlist', token: token);
      
      if (response is List) {
        items = <Series>[];
        final seenSeriesIds = <int>{};
        
        for (var entry in response) {
          if (entry is Map<String, dynamic>) {
            // Check for 'series' property (WatchlistDto format)
            if (entry.containsKey('series') && entry['series'] != null) {
              try {
                final seriesData = entry['series'] as Map<String, dynamic>;
                final seriesId = seriesData['id'] as int?;
                
                // Only add if we haven't seen this series ID before (prevent duplicates)
                if (seriesId != null && !seenSeriesIds.contains(seriesId)) {
                  seenSeriesIds.add(seriesId);
                  
                  // Validate series data has required fields
                  if (seriesData.containsKey('title') && seriesData['title'] != null) {
                    items.add(Series.fromJson(seriesData));
                  }
                }
              } catch (e) {
                // Skip invalid entries - don't show error to user
                continue;
              }
            }
            // Also handle case where entry might be a SeriesDto directly (fallback)
            else if (entry.containsKey('id') && entry.containsKey('title')) {
              try {
                final seriesId = entry['id'] as int?;
                if (seriesId != null && !seenSeriesIds.contains(seriesId)) {
                  seenSeriesIds.add(seriesId);
                  items.add(Series.fromJson(entry));
                }
              } catch (e) {
                continue;
              }
            }
          }
        }
        error = null;
      } else {
        // If response is not a list, it might be an error or different format
        items = <Series>[];
        error = null; // Don't set error, just show empty list
      }
    } catch (e) {
      error = 'Failed to load watchlist: ${e.toString()}';
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
