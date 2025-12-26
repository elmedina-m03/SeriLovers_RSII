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
      print('🔑 AdminActorProvider: Token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminActorProvider: No authentication token available');
        throw Exception('Authentication required');
      }

      // Make API request to get all actors
      final apiPath = '/Actor';
      print('🌐 AdminActorProvider: Making API request to: $apiPath');
      
      final response = await _apiService.get(
        apiPath,
        token: token,
      );

      print('AdminActorProvider: API Response received');
      print('Response type: ${response.runtimeType}');

      // Parse response
      if (response is List) {
        // Direct array response
        print('AdminActorProvider: Processing direct array response with ${response.length} items');
        
        items = response
            .map((item) {
              try {
                return Actor.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                print('AdminActorProvider: Error parsing actor item: $e');
                print('Item data: $item');
                rethrow;
              }
            })
            .toList();

        print('AdminActorProvider: Parsed ${items.length} actors');
      } else if (response is Map<String, dynamic>) {
        // Wrapped response with items array
        final itemsList = response['items'] as List<dynamic>? ?? [];
        print('AdminActorProvider: Processing wrapped response with ${itemsList.length} items');
        
        items = itemsList
            .map((item) {
              try {
                return Actor.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                print('AdminActorProvider: Error parsing actor item: $e');
                print('Item data: $item');
                rethrow;
              }
            })
            .toList();

        print('AdminActorProvider: Parsed ${items.length} actors from wrapped response');
      } else {
        print('AdminActorProvider: Invalid response format. Expected List or Map, got: ${response.runtimeType}');
        throw Exception('Invalid response format from server');
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ AdminActorProvider: Error fetching actors: $e');
      rethrow;
    }
  }

  /// Fetches filtered and sorted actors from the API
  /// 
  /// [search] - Search query for actor name
  /// [age] - Filter by specific age (null for all ages)
  /// [sortBy] - Field to sort by (lastName, age)
  /// [sortOrder] - Sort order (asc, desc)
  /// [page] - Page number (optional, defaults to currentPage)
  /// [pageSize] - Number of items per page (optional, defaults to this.pageSize)
  Future<void> fetchFiltered({
    String? search,
    int? age,
    String sortBy = 'lastName',
    String sortOrder = 'asc',
    int? page,
    int? pageSize,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      print('🔑 AdminActorProvider: Token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminActorProvider: No authentication token available for fetchFiltered');
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
      if (age != null) {
        queryParams['age'] = age.toString();
      }
      queryParams['sortBy'] = sortBy;
      queryParams['sortOrder'] = sortOrder;

      // Build URL with query parameters
      final uri = Uri.parse('/Actor').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final apiPath = uri.toString();
      
      print('🌐 AdminActorProvider: Fetching filtered actors from: $apiPath');
      
      final response = await _apiService.get(apiPath, token: token);
      print('📥 AdminActorProvider: Filtered API response: $response');

      // Parse response
      if (response is Map<String, dynamic>) {
        final itemsList = response['items'] as List<dynamic>? ?? [];
        print('📝 AdminActorProvider: Found ${itemsList.length} filtered actors in items array');
        items = itemsList.map((item) {
          try {
            return Actor.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            print('❌ AdminActorProvider: Error parsing filtered actor from items: $e');
            rethrow;
          }
        }).toList();

        // Extract pagination metadata
        totalItems = response['totalItems'] as int? ?? items.length;
        totalPages = response['totalPages'] as int? ?? 1;
        currentPage = response['currentPage'] as int? ?? currentPage;
        this.pageSize = response['pageSize'] as int? ?? this.pageSize;

        print('✅ AdminActorProvider: Successfully loaded ${items.length} filtered actors from items array');
        print('   Page: $currentPage/$totalPages, Total: $totalItems');
      } else if (response is List) {
        // Fallback for non-paginated API response
        items = response.map((item) {
          print('📝 AdminActorProvider: Parsing filtered actor item (non-paginated): $item');
          try {
            return Actor.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            print('❌ AdminActorProvider: Error parsing filtered actor item (non-paginated): $e');
            rethrow;
          }
        }).toList();
        
        // Client-side pagination
        totalItems = items.length;
        totalPages = (totalItems / this.pageSize).ceil();
        final startIndex = (currentPage - 1) * this.pageSize;
        final endIndex = (startIndex + this.pageSize < totalItems) ? startIndex + this.pageSize : totalItems;
        items = items.sublist(startIndex, endIndex);

        print('✅ AdminActorProvider: Successfully loaded ${items.length} filtered actors (client-side paginated)');
        print('   Page: $currentPage/$totalPages, Total: $totalItems');
      } else {
        print('⚠️ AdminActorProvider: Invalid response format. Expected List or Map, got: ${response.runtimeType}');
        items = [];
      }
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ AdminActorProvider: Error fetching filtered actors: $e');
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
      print('🔑 AdminActorProvider: Creating actor with token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminActorProvider: No authentication token available for create');
        throw Exception('Authentication required');
      }

      // Make API request to create actor
      final apiPath = '/Actor';
      print('🌐 AdminActorProvider: Creating actor at: $apiPath');
      print('Data: $data');
      
      final response = await _apiService.post(
        apiPath,
        data,
        token: token,
      );

      print('AdminActorProvider: Create actor response received');
      
      // Parse the created actor
      final createdActor = Actor.fromJson(response as Map<String, dynamic>);
      
      // Add to local list
      items.add(createdActor);
      notifyListeners();
      
      print('AdminActorProvider: Actor created successfully with ID: ${createdActor.id}');
      return createdActor;
    } catch (e) {
      print('❌ AdminActorProvider: Error creating actor: $e');
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
      print('🔑 AdminActorProvider: Updating actor $id with token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminActorProvider: No authentication token available for update');
        throw Exception('Authentication required');
      }

      // Make API request to update actor
      final apiPath = '/Actor/$id';
      print('🌐 AdminActorProvider: Updating actor at: $apiPath');
      print('Data: $data');
      
      final response = await _apiService.put(
        apiPath,
        data,
        token: token,
      );

      print('AdminActorProvider: Update actor response received');
      print('📸 Update response: $response');
      
      // Parse the updated actor
      final updatedActor = Actor.fromJson(response as Map<String, dynamic>);
      print('📸 Updated actor imageUrl: ${updatedActor.imageUrl}');
      
      // Update the actor in the local list
      final index = items.indexWhere((actor) => actor.id == id);
      if (index != -1) {
        items[index] = updatedActor;
        print('✅ Updated actor in local list at index $index');
      } else {
        print('⚠️ Actor not found in local list, adding it');
        items.add(updatedActor);
      }
      
      notifyListeners();
      
      print('AdminActorProvider: Actor updated successfully with ID: ${updatedActor.id}');
      return updatedActor;
    } catch (e) {
      print('❌ AdminActorProvider: Error updating actor $id: $e');
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
      print('🔑 AdminActorProvider: Deleting actor $id with token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminActorProvider: No authentication token available for delete');
        throw Exception('Authentication required');
      }

      // Make API request to delete actor
      final apiPath = '/Actor/$id';
      print('🌐 AdminActorProvider: Deleting actor at: $apiPath');
      
      await _apiService.delete(
        apiPath,
        token: token,
      );

      print('AdminActorProvider: Delete actor response received');
      
      // Remove from local list
      items.removeWhere((actor) => actor.id == id);
      notifyListeners();
      
      print('AdminActorProvider: Actor deleted successfully with ID: $id');
    } catch (e) {
      print('❌ AdminActorProvider: Error deleting actor $id: $e');
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
