import 'package:flutter/foundation.dart';
import '../../models/series.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

/// Provider for managing admin series operations
/// 
/// Uses ChangeNotifier to notify listeners of series state changes.
/// Provides CRUD operations for series management in admin interface.
class AdminSeriesProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// List of series items
  List<Series> items = [];

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Current page number (1-based)
  int currentPage = 1;

  /// Page size
  int pageSize = 10;

  /// Total number of items
  int totalItems = 0;

  /// Total number of pages
  int totalPages = 0;

  /// Creates an AdminSeriesProvider instance
  /// 
  /// [apiService] - Service for making API requests
  /// [authProvider] - Provider for authentication (to get token)
  AdminSeriesProvider({
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

  /// Fetches all series from the API
  /// 
  /// Updates [items] and [isLoading] state.
  /// Notifies listeners on completion or error.
  Future<void> fetchAll() async {
    isLoading = true;
    notifyListeners();

    try {
      // Get authentication token
      final token = _authProvider.token;
      print('🔑 AdminSeriesProvider: Token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminSeriesProvider: No authentication token available');
        throw Exception('Authentication required');
      }

      // Make API request to get all series (admin endpoint might have different pagination)
      final apiPath = '/Series?pageSize=1000'; // Large page size to get all series
      print('🌐 AdminSeriesProvider: Making API request to: $apiPath');
      
      final response = await _apiService.get(
        apiPath,
        token: token,
      );

      print('AdminSeriesProvider: API Response received');
      print('Response type: ${response.runtimeType}');

      // Parse response
      if (response is Map<String, dynamic>) {
        // Parse items
        final itemsList = response['items'] as List<dynamic>? ?? [];
        print('AdminSeriesProvider: Items list length: ${itemsList.length}');
        
        items = itemsList
            .map((item) {
              try {
                return Series.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                print('AdminSeriesProvider: Error parsing series item: $e');
                print('Item data: $item');
                rethrow;
              }
            })
            .toList();

        print('AdminSeriesProvider: Parsed ${items.length} series');
      } else {
        print('AdminSeriesProvider: Invalid response format. Expected Map, got: ${response.runtimeType}');
        throw Exception('Invalid response format from server');
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ AdminSeriesProvider: Error fetching series: $e');
      rethrow;
    }
  }

  /// Fetches filtered and sorted series from the API
  /// 
  /// [search] - Search query for title, description, or actor names
  /// [genre] - Genre filter (null for all genres)
  /// [year] - Release year filter (null for all years)
  /// [sortBy] - Field to sort by (title, year, rating)
  /// [sortOrder] - Sort order (asc, desc)
  /// [page] - Page number (1-based, optional, uses currentPage if not provided)
  /// [pageSize] - Number of items per page (optional, uses this.pageSize if not provided)
  Future<void> fetchFiltered({
    String? search,
    String? genre,
    int? year,
    String sortBy = 'title',
    String sortOrder = 'asc',
    int? page,
    int? pageSize,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      print('🔑 AdminSeriesProvider: Token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminSeriesProvider: No authentication token available for fetchFiltered');
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
      final queryParams = <String, String>{};
      queryParams['page'] = currentPage.toString();
      queryParams['pageSize'] = this.pageSize.toString();
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (genre != null && genre.isNotEmpty) {
        queryParams['genre'] = genre;
      }
      if (year != null) {
        queryParams['year'] = year.toString();
      }
      queryParams['sortBy'] = sortBy;
      queryParams['sortOrder'] = sortOrder;

      // Build URL with query parameters
      final uri = Uri.parse('/Series').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final apiPath = uri.toString();
      
      print('🌐 AdminSeriesProvider: Fetching filtered series from: $apiPath');
      
      final response = await _apiService.get(apiPath, token: token);
      print('📥 AdminSeriesProvider: Filtered API response: $response');

      // Parse response
      if (response is Map<String, dynamic>) {
        final itemsList = response['items'] as List<dynamic>? ?? [];
        print('📝 AdminSeriesProvider: Items list length: ${itemsList.length}');
        
        items = itemsList
            .map((item) {
              try {
                return Series.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                print('AdminSeriesProvider: Error parsing series item: $e');
                print('Item data: $item');
                rethrow;
              }
            })
            .toList();

        // Extract pagination metadata
        totalItems = response['totalItems'] as int? ?? items.length;
        totalPages = response['totalPages'] as int? ?? 1;
        currentPage = response['currentPage'] as int? ?? currentPage;
        pageSize = response['pageSize'] as int? ?? pageSize;

        print('✅ AdminSeriesProvider: Parsed ${items.length} filtered series');
        print('   Page: $currentPage/$totalPages, Total: $totalItems');
      } else if (response is List) {
        items = response
            .map((item) => Series.fromJson(item as Map<String, dynamic>))
            .toList();
        totalItems = items.length;
        totalPages = 1;
        print('✅ AdminSeriesProvider: Parsed ${items.length} filtered series from list');
      } else {
        print('⚠️ AdminSeriesProvider: Invalid response format. Expected Map or List, got: ${response.runtimeType}');
        throw Exception('Invalid response format from server');
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ AdminSeriesProvider: Error fetching filtered series: $e');
      rethrow;
    }
  }

  /// Creates a new series
  /// 
  /// [data] - Series data as a Map
  /// 
  /// Returns the created series or throws an exception on error.
  /// Updates the local items list and notifies listeners.
  Future<Series> createSeries(Map<String, dynamic> data) async {
    try {
      // Get authentication token
      final token = _authProvider.token;
      print('🔑 AdminSeriesProvider: Creating series with token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminSeriesProvider: No authentication token available for create');
        throw Exception('Authentication required');
      }

      // Make API request to create series
      final apiPath = '/Series';
      print('🌐 AdminSeriesProvider: Creating series at: $apiPath');
      print('Data: $data');
      
      final response = await _apiService.post(
        apiPath,
        data,
        token: token,
      );

      print('AdminSeriesProvider: Create series response received');
      
      // Parse the created series
      final createdSeries = Series.fromJson(response as Map<String, dynamic>);
      
      // Add to local list
      items.add(createdSeries);
      notifyListeners();
      
      print('AdminSeriesProvider: Series created successfully with ID: ${createdSeries.id}');
      return createdSeries;
    } catch (e) {
      print('❌ AdminSeriesProvider: Error creating series: $e');
      rethrow;
    }
  }

  /// Updates an existing series
  /// 
  /// [id] - ID of the series to update
  /// [data] - Updated series data as a Map
  /// 
  /// Returns the updated series or throws an exception on error.
  /// Updates the local items list and notifies listeners.
  Future<Series> updateSeries(int id, Map<String, dynamic> data) async {
    try {
      // Get authentication token
      final token = _authProvider.token;
      print('🔑 AdminSeriesProvider: Updating series $id with token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminSeriesProvider: No authentication token available for update');
        throw Exception('Authentication required');
      }

      // Make API request to update series
      final apiPath = '/Series/$id';
      print('🌐 AdminSeriesProvider: Updating series at: $apiPath');
      print('Data: $data');
      
      final response = await _apiService.put('/Series/$id', data, token: _authProvider.token);

      print('AdminSeriesProvider: Update series response received');
      
      // Parse the updated series
      final updatedSeries = Series.fromJson(response as Map<String, dynamic>);
      
      // Refresh the entire list to ensure consistency
      await fetchAll();
      notifyListeners();
      
      print('AdminSeriesProvider: Series updated successfully with ID: ${updatedSeries.id}');
      return updatedSeries;
    } catch (e) {
      print('❌ AdminSeriesProvider: Error updating series $id: $e');
      rethrow;
    }
  }

  /// Deletes a series
  /// 
  /// [id] - ID of the series to delete
  /// 
  /// Throws an exception on error.
  /// Removes the series from the local items list and notifies listeners.
  Future<void> deleteSeries(int id) async {
    try {
      // Get authentication token
      final token = _authProvider.token;
      print('🔑 AdminSeriesProvider: Deleting series $id with token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminSeriesProvider: No authentication token available for delete');
        throw Exception('Authentication required');
      }

      // Make API request to delete series
      final apiPath = '/Series/$id';
      print('🌐 AdminSeriesProvider: Deleting series at: $apiPath');
      
      await _apiService.delete(
        apiPath,
        token: token,
      );

      print('AdminSeriesProvider: Delete series response received');
      
      // Remove from local list
      items.removeWhere((series) => series.id == id);
      notifyListeners();
      
      print('AdminSeriesProvider: Series deleted successfully with ID: $id');
    } catch (e) {
      print('❌ AdminSeriesProvider: Error deleting series $id: $e');
      rethrow;
    }
  }

  /// Gets a series by its ID from the current items list
  /// 
  /// [id] - The series ID to find
  /// 
  /// Returns the Series if found, null otherwise.
  /// Note: This only searches the currently loaded items.
  Series? getById(int id) {
    try {
      return items.firstWhere((series) => series.id == id);
    } catch (e) {
      return null;
    }
  }
}
