import 'package:flutter/foundation.dart';
import '../../models/series.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

/// Provider for managing admin actor operations
/// 
/// Uses ChangeNotifier to notify listeners of actor state changes.
/// Provides CRUD operations for actor management in admin interface.
class AdminActorProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// List of actors
  List<Actor> items = [];

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Current page number (1-based)
  int currentPage = 1;

  /// Number of items per page
  int pageSize = 10;

  /// Total number of items available
  int totalItems = 0;

  /// Total number of pages available
  int totalPages = 0;

  /// Creates an AdminActorProvider instance
  /// 
  /// [apiService] - Service for making API requests
  /// [authProvider] - Provider for authentication (to get token)
  AdminActorProvider({
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
    // The token is fetched fresh each time methods are called
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

  /// Fetches all actors from the API
  /// 
  /// Updates [items] and [isLoading] state.
  /// Notifies listeners on completion or error.
  Future<void> fetchAllActors() async {
    isLoading = true;
    notifyListeners();

    try {
      // Get authentication token
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Make API request to get all actors
      final apiPath = '/Actor';
      final response = await _apiService.get(
        apiPath,
        token: token,
      );
      // Parse response
      if (response is List) {
        // Direct array response
        items = response
            .map((item) {
              try {
                return Actor.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                rethrow;
              }
            })
            .toList();
      } else if (response is Map<String, dynamic>) {
        // Wrapped response with items array
        final itemsList = response['items'] as List<dynamic>? ?? [];
        items = itemsList
            .map((item) {
              try {
                return Actor.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                rethrow;
              }
            })
            .toList();
      } else {
        throw Exception('Invalid response format from server');
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Fetches filtered and sorted actors from the API
  /// 
  /// [search] - Search query for actor name
  /// [minAge] - Minimum age for filtering (null for no minimum)
  /// [maxAge] - Maximum age for filtering (null for no maximum)
  /// [sortBy] - Field to sort by (lastName, age)
  /// [sortOrder] - Sort order (asc, desc)
  /// [page] - Page number (optional, defaults to currentPage)
  /// [pageSize] - Number of items per page (optional, defaults to this.pageSize)
  Future<void> fetchFiltered({
    String? search,
    int? minAge,
    int? maxAge,
    String sortBy = 'lastName',
    String sortOrder = 'asc',
    int? page,
    int? pageSize,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Update pagination state
      if (page != null) {
        currentPage = page;
      }
      if (pageSize != null) {
        this.pageSize = pageSize;
      }

      // Build query parameters
      final queryParams = <String, String>{
        'page': currentPage.toString(),
        'pageSize': this.pageSize.toString(),
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (minAge != null) {
        queryParams['minAge'] = minAge.toString();
      }
      if (maxAge != null) {
        queryParams['maxAge'] = maxAge.toString();
      }
      queryParams['sortBy'] = sortBy;
      queryParams['sortOrder'] = sortOrder;

      // Build URL with query parameters
      final uri = Uri.parse('/Actor').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final apiPath = uri.toString();
      final response = await _apiService.get(apiPath, token: token);
      // Parse response
      if (response is Map<String, dynamic>) {
        final itemsList = response['items'] as List<dynamic>? ?? [];
        items = itemsList.map((item) {
          try {
            return Actor.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            rethrow;
          }
        }).toList();

        // Extract pagination metadata
        totalItems = response['totalItems'] as int? ?? items.length;
        totalPages = response['totalPages'] as int? ?? 1;
        currentPage = response['currentPage'] as int? ?? currentPage;
        this.pageSize = response['pageSize'] as int? ?? this.pageSize;
      } else if (response is List) {
        // Fallback for non-paginated API response
        items = response.map((item) {
          try {
            return Actor.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            rethrow;
          }
        }).toList();
        
        // Client-side pagination
        totalItems = items.length;
        totalPages = (totalItems / this.pageSize).ceil();
        final startIndex = (currentPage - 1) * this.pageSize;
        final endIndex = (startIndex + this.pageSize < totalItems) ? startIndex + this.pageSize : totalItems;
        items = items.sublist(startIndex, endIndex);
      } else {
        items = [];
      }
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Creates a new actor
  /// 
  /// [data] - Actor data as a Map
  /// 
  /// Returns the created actor or throws an exception on error.
  /// Updates the local items list and notifies listeners.
  Future<Actor> createActor(Map<String, dynamic> data) async {
    try {
      // Get authentication token
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Make API request to create actor
      final apiPath = '/Actor';
      final response = await _apiService.post(
        apiPath,
        data,
        token: token,
      );
      // Parse the created actor
      final createdActor = Actor.fromJson(response as Map<String, dynamic>);
      
      // Add to local list
      items.add(createdActor);
      notifyListeners();
      return createdActor;
    } catch (e) {
      rethrow;
    }
  }

  /// Updates an existing actor
  /// 
  /// [id] - ID of the actor to update
  /// [data] - Updated actor data as a Map
  /// 
  /// Returns the updated actor or throws an exception on error.
  /// Updates the local items list and notifies listeners.
  Future<Actor> updateActor(int id, Map<String, dynamic> data) async {
    try {
      // Get authentication token
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Make API request to update actor
      final apiPath = '/Actor/$id';
      final response = await _apiService.put(
        apiPath,
        data,
        token: token,
      );
      // Parse the updated actor
      final updatedActor = Actor.fromJson(response as Map<String, dynamic>);
      // Update the actor in the local list
      final index = items.indexWhere((actor) => actor.id == id);
      if (index != -1) {
        items[index] = updatedActor;
      } else {
        items.add(updatedActor);
      }
      
      notifyListeners();
      return updatedActor;
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes an actor
  /// 
  /// [id] - ID of the actor to delete
  /// 
  /// Throws an exception on error.
  /// Removes the actor from the local items list and notifies listeners.
  Future<void> deleteActor(int id) async {
    try {
      // Get authentication token
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Make API request to delete actor
      final apiPath = '/Actor/$id';
      await _apiService.delete(
        apiPath,
        token: token,
      );
      items.removeWhere((actor) => actor.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets an actor by its ID from the current items list
  /// 
  /// [id] - The actor ID to find
  /// 
  /// Returns the Actor if found, null otherwise.
  /// Note: This only searches the currently loaded items.
  Actor? getById(int id) {
    try {
      return items.firstWhere((actor) => actor.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Gets actors by name (partial match, case insensitive)
  /// 
  /// [name] - The name to search for
  /// 
  /// Returns a list of actors whose full name contains the search term.
  List<Actor> searchByName(String name) {
    if (name.isEmpty) return items;
    
    final searchTerm = name.toLowerCase();
    return items.where((actor) => 
      actor.fullName.toLowerCase().contains(searchTerm) ||
      actor.firstName.toLowerCase().contains(searchTerm) ||
      actor.lastName.toLowerCase().contains(searchTerm)
    ).toList();
  }

  /// Gets the total count of actors
  int get totalCount => items.length;

  /// Checks if an actor exists by ID
  bool hasActor(int id) => items.any((actor) => actor.id == id);
}
