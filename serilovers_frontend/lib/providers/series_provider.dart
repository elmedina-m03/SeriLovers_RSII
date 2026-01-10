import 'package:flutter/foundation.dart';
import '../models/series.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// Provider for managing series data
/// 
/// Uses ChangeNotifier to notify listeners of series state changes.
/// Manages series list, loading state, and pagination.
class SeriesProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// List of series items
  List<Series> items = [];

  /// List of available genres
  List<Genre> genres = [];

  /// Whether genres are currently being loaded
  bool isGenresLoading = false;

  /// Whether data is currently being loaded
  bool isLoading = false;

  /// Total count of series (for pagination)
  int totalCount = 0;

  /// Creates a SeriesProvider instance
  /// 
  /// [apiService] - Service for making API requests
  /// [authProvider] - Provider for authentication (to get token)
  SeriesProvider({
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
    // The token is fetched fresh each time fetchSeries is called
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

  /// Current page number
  int _currentPage = 1;
  
  /// Current page size
  int _currentPageSize = 20;
  
  /// Current search query
  String? _currentSearch;
  
  /// Current genre filter
  int? _currentGenreId;
  
  /// Whether there are more items to load
  bool get hasMore => items.length < totalCount;

  /// Fetches series from the API with optional filtering and pagination
  /// 
  /// [page] - Page number (default: 1)
  /// [pageSize] - Number of items per page (default: 20)
  /// [search] - Optional search keyword to filter by title/description
  /// [genreId] - Optional genre ID to filter by genre
  /// [append] - If true, appends to existing items instead of replacing
  /// 
  /// Updates [items], [totalCount], and [isLoading] state.
  /// Notifies listeners on completion or error.
  Future<void> fetchSeries({
    int page = 1,
    int pageSize = 20,
    String? search,
    int? genreId,
    bool append = false,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      // Get authentication token
      final token = _authProvider.token;
      print('🔑 Token available: ${token != null && token.isNotEmpty}');
      if (token == null || token.isEmpty) {
        print('⚠️ Warning: No authentication token available');
      }

      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (genreId != null) {
        queryParams['genreId'] = genreId.toString();
      }

      // Build query string
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      // Make API request
      final apiPath = '/Series?$queryString';
      print('🌐 Making API request to: $apiPath');
      final response = await _apiService.get(
        apiPath,
        token: token,
      );

      // Debug: Print response
      print('Series API Response: $response');
      print('Response type: ${response.runtimeType}');

      // Parse response
      if (response is Map<String, dynamic>) {
        // Parse items
        final itemsList = response['items'] as List<dynamic>? ?? [];
        print('Items list length: ${itemsList.length}');
        
        final newItems = itemsList
            .map((item) {
              try {
                return Series.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing series item: $e');
                print('Item data: $item');
                rethrow;
              }
            })
            .toList();

        // Append or replace items
        if (append) {
          // Remove duplicates by ID
          final existingIds = items.map((s) => s.id).toSet();
          final uniqueNewItems = newItems.where((s) => !existingIds.contains(s.id)).toList();
          items = [...items, ...uniqueNewItems];
        } else {
          items = newItems;
        }

        // Parse total count
        totalCount = response['totalItems'] as int? ?? 0;
        
        // Store current pagination state
        _currentPage = page;
        _currentPageSize = pageSize;
        _currentSearch = search;
        _currentGenreId = genreId;
        print('Total count: $totalCount');
        print('Parsed ${items.length} series');
      } else {
        print('Invalid response format. Expected Map, got: ${response.runtimeType}');
        throw ApiException('Invalid response format from server');
      }

      isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ ApiException fetching series: ${e.message} (Status: ${e.statusCode})');
      rethrow;
    } catch (e, stackTrace) {
      isLoading = false;
      notifyListeners();
      print('❌ Unexpected error fetching series: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Gets a series by its ID from the current items list
  /// 
  /// [id] - The series ID to find
  /// 
  /// Returns the Series if found, null otherwise.
  /// Note: This only searches the currently loaded items.
  /// For a specific series, consider fetching it directly from the API.
  Series? getById(int id) {
    try {
      return items.firstWhere((series) => series.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Fetches full series detail including seasons and episodes
  /// 
  /// [id] - Series ID to fetch
  /// 
  /// Returns the Series with full details including seasons and episodes
  Future<Series?> fetchSeriesDetail(int id) async {
    try {
      final token = _authProvider.token;
      final response = await _apiService.get(
        '/Series/$id',
        token: token,
      );

      if (response is Map<String, dynamic>) {
        final series = Series.fromJson(response);
        
        // Update or add to items list
        final index = items.indexWhere((s) => s.id == id);
        if (index >= 0) {
          items[index] = series;
        } else {
          items.add(series);
        }
        
        notifyListeners();
        return series;
      }
      
      return null;
    } catch (e) {
      print('Error fetching series detail: $e');
      return null;
    }
  }

  /// Loads more series (next page) for pagination
  /// 
  /// Uses the current filter/search state to load the next page
  Future<void> loadMoreSeries() async {
    if (!hasMore || isLoading) return;
    
    final nextPage = _currentPage + 1;
    await fetchSeries(
      page: nextPage,
      pageSize: _currentPageSize,
      search: _currentSearch,
      genreId: _currentGenreId,
      append: true,
    );
  }

  /// Searches series by query string.
  ///
  /// Convenience wrapper around [fetchSeries] that sets the [search] parameter
  /// and resets to the first page.
  Future<void> searchSeries(String query) async {
    await fetchSeries(
      page: 1,
      pageSize: 20,
      search: query,
    );
  }

  /// Clears search results and resets to show all series
  Future<void> clearSearch() async {
    _currentSearch = null;
    await fetchSeries(
      page: 1,
      pageSize: 20,
      search: null,
      genreId: null,
    );
  }

  /// Fetches all genres from the API
  ///
  /// Populates [genres] list and updates [isGenresLoading].
  Future<void> fetchGenres() async {
    isGenresLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      final response = await _apiService.get(
        '/Genre',
        token: token,
      );

      if (response is List) {
        genres = response
            .whereType<Map<String, dynamic>>()
            .map((json) => Genre.fromJson(json))
            .toList();
      } else {
        genres = [];
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching genres: $e');
      print('Stack trace: $stackTrace');
      genres = [];
    } finally {
      isGenresLoading = false;
      notifyListeners();
    }
  }

  /// Fetches series by genre without mutating [items].
  ///
  /// Useful for category detail screens that need independent data.
  Future<List<Series>> fetchSeriesByGenre(int genreId) async {
    try {
      final token = _authProvider.token;
      final queryString = 'page=1&pageSize=50&genreId=$genreId';
      final apiPath = '/Series?$queryString';
      final response = await _apiService.get(
        apiPath,
        token: token,
      );

      if (response is Map<String, dynamic>) {
        final itemsList = response['items'] as List<dynamic>? ?? [];
        return itemsList
            .whereType<Map<String, dynamic>>()
            .map((item) => Series.fromJson(item))
            .toList();
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching series by genre: $e');
      print('Stack trace: $stackTrace');
    }
    return [];
  }
}

