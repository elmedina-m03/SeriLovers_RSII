import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

// Type alias for ApplicationUser to match backend model naming
typedef ApplicationUser = User;

/// Provider for managing admin user data
class AdminUserProvider extends ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  /// List of users (ApplicationUser)
  List<ApplicationUser> users = [];

  /// Legacy getter for backward compatibility
  List<ApplicationUser> get items => users;

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

  /// Creates an AdminUserProvider instance
  AdminUserProvider({
    required ApiService apiService,
    required AuthProvider authProvider,
  })  : _apiService = apiService,
        _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  /// Called when AuthProvider changes
  void _onAuthChanged() {
    // Token might have changed
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Updates the auth provider reference
  void updateAuthProvider(AuthProvider authProvider) {
    if (_authProvider != authProvider) {
      _authProvider.removeListener(_onAuthChanged);
      _authProvider = authProvider;
      _authProvider.addListener(_onAuthChanged);
    }
  }

  /// Fetches all users from the API
  Future<void> fetchUsers() async {
    isLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      print('🔑 AdminUserProvider: Token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminUserProvider: No authentication token available');
        throw Exception('Authentication required');
      }

      print('📡 AdminUserProvider: Fetching users from /Users endpoint...');
      final response = await _apiService.get('/Users', token: token);
      
      print('📥 AdminUserProvider: Users API response received');
      print('Response type: ${response.runtimeType}');
      print('Response data: $response');
      
      if (response is List) {
        users = response.map((item) {
          print('📝 AdminUserProvider: Parsing user item: $item');
          try {
            return ApplicationUser.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            print('❌ AdminUserProvider: Error parsing user item: $e');
            rethrow;
          }
        }).toList();
        print('✅ AdminUserProvider: Successfully loaded ${users.length} users');
      } else if (response is Map && response.containsKey('items')) {
        final itemsList = response['items'] as List<dynamic>? ?? [];
        print('📝 AdminUserProvider: Found ${itemsList.length} users in items array');
        users = itemsList.map((item) {
          try {
            return ApplicationUser.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            print('❌ AdminUserProvider: Error parsing user from items: $e');
            rethrow;
          }
        }).toList();
        print('✅ AdminUserProvider: Successfully loaded ${users.length} users from items array');
      } else {
        print('⚠️ AdminUserProvider: Unexpected response format: ${response.runtimeType}');
        users = [];
      }
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ AdminUserProvider: Error fetching users: $e');
      rethrow;
    }
  }

  /// Fetches filtered and sorted users from the API
  /// 
  /// [search] - Search query for name/email/phone
  /// [status] - Status filter (Active/Inactive, null for all)
  /// [sortBy] - Field to sort by (name, dateCreated)
  /// [sortOrder] - Sort order (asc, desc)
  /// [page] - Page number (1-based, optional, uses currentPage if not provided)
  /// [pageSize] - Number of items per page (optional, uses this.pageSize if not provided)
  Future<void> fetchFiltered({
    String? search,
    String? status,
    String sortBy = 'dateCreated',
    String sortOrder = 'desc',
    int? page,
    int? pageSize,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final token = _authProvider.token;
      print('🔑 AdminUserProvider: Token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminUserProvider: No authentication token available for fetchFiltered');
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
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      queryParams['sortBy'] = sortBy;
      queryParams['sortOrder'] = sortOrder;

      // Build URL with query parameters
      final uri = Uri.parse('/Users').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final apiPath = uri.toString();
      
      print('🌐 AdminUserProvider: Fetching filtered users from: $apiPath');
      
      final response = await _apiService.get(apiPath, token: token);
      print('📥 AdminUserProvider: Filtered API response: $response');

      // Parse response
      if (response is Map<String, dynamic>) {
        final itemsList = response['items'] as List<dynamic>? ?? [];
        print('📝 AdminUserProvider: Items list length: ${itemsList.length}');
        
        users = itemsList.map((item) {
          try {
            return ApplicationUser.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            print('❌ AdminUserProvider: Error parsing filtered user item: $e');
            rethrow;
          }
        }).toList();

        // Extract pagination metadata
        totalItems = response['totalItems'] as int? ?? users.length;
        totalPages = response['totalPages'] as int? ?? 1;
        currentPage = response['currentPage'] as int? ?? currentPage;
        pageSize = response['pageSize'] as int? ?? pageSize;

        print('✅ AdminUserProvider: Parsed ${users.length} filtered users');
        print('   Page: $currentPage/$totalPages, Total: $totalItems');
      } else if (response is List) {
        // Fallback: client-side pagination if backend doesn't support it
        final allUsers = response.map((item) {
          print('📝 AdminUserProvider: Parsing filtered user item: $item');
          try {
            return ApplicationUser.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            print('❌ AdminUserProvider: Error parsing filtered user item: $e');
            rethrow;
          }
        }).toList();
        
        // Client-side pagination
        totalItems = allUsers.length;
        totalPages = (totalItems / this.pageSize).ceil();
        if (totalPages == 0) totalPages = 1;
        
        final startIndex = (currentPage - 1) * this.pageSize;
        final endIndex = startIndex + this.pageSize;
        users = allUsers.sublist(
          startIndex.clamp(0, allUsers.length),
          endIndex.clamp(0, allUsers.length),
        );
        
        print('✅ AdminUserProvider: Successfully loaded ${users.length} filtered users (client-side pagination)');
        print('   Page: $currentPage/$totalPages, Total: $totalItems');
      } else {
        print('⚠️ AdminUserProvider: Invalid response format. Expected Map or List, got: ${response.runtimeType}');
        users = [];
        totalItems = 0;
        totalPages = 1;
      }
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      print('❌ AdminUserProvider: Error fetching filtered users: $e');
      rethrow;
    }
  }

  /// Updates a user with optional parameters
  /// 
  /// [userId] - ID of the user to update
  /// [email] - Optional new email
  /// [role] - Optional new role
  /// [isActive] - Optional new active status
  Future<ApplicationUser> updateUser(
    int userId, {
    String? email,
    String? role,
    bool? isActive,
  }) async {
    try {
      final token = _authProvider.token;
      print('🔑 AdminUserProvider: Updating user $userId with token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminUserProvider: No authentication token available for update');
        throw Exception('Authentication required');
      }

      // Prepare update data (only include non-null values)
      final updateData = <String, dynamic>{};
      if (email != null) updateData['email'] = email;
      if (role != null) updateData['role'] = role;
      if (isActive != null) updateData['isActive'] = isActive;
      
      print('📡 AdminUserProvider: Updating user $userId with data: $updateData');
      
      final response = await _apiService.put(
        '/Users/$userId',
        updateData,
        token: token,
      );

      print('📥 AdminUserProvider: Update user response received');
      print('Response: $response');
      
      // Parse the updated user
      final updatedUser = ApplicationUser.fromJson(response as Map<String, dynamic>);
      
      // Update in local list
      final index = users.indexWhere((user) => user.id == userId);
      if (index != -1) {
        users[index] = updatedUser;
        notifyListeners();
        print('✅ AdminUserProvider: User updated successfully in local list');
      } else {
        print('⚠️ AdminUserProvider: User $userId not found in local list');
      }
      
      print('✅ AdminUserProvider: User updated successfully with ID: ${updatedUser.id}');
      return updatedUser;
    } catch (e) {
      print('❌ AdminUserProvider: Error updating user $userId: $e');
      rethrow;
    }
  }

  /// Deletes a user
  /// 
  /// [userId] - ID of the user to delete
  Future<void> deleteUser(int userId) async {
    try {
      final token = _authProvider.token;
      print('🔑 AdminUserProvider: Deleting user $userId with token available: ${token != null && token.isNotEmpty}');
      
      if (token == null || token.isEmpty) {
        print('⚠️ AdminUserProvider: No authentication token available for delete');
        throw Exception('Authentication required');
      }

      print('📡 AdminUserProvider: Deleting user at: /Users/$userId');
      
      await _apiService.delete(
        '/Users/$userId',
        token: token,
      );

      print('📥 AdminUserProvider: Delete user response received');
      
      // Remove from local list
      users.removeWhere((user) => user.id == userId);
      notifyListeners();
      
      print('✅ AdminUserProvider: User deleted successfully with ID: $userId');
    } catch (e) {
      print('❌ AdminUserProvider: Error deleting user $userId: $e');
      rethrow;
    }
  }

  /// Disables/enables a user (legacy method for backward compatibility)
  Future<void> toggleUserStatus(ApplicationUser user) async {
    try {
      print('🔄 AdminUserProvider: Toggling status for user ${user.id} (current: ${user.isActive})');
      
      await updateUser(
        user.id,
        isActive: !user.isActive,
      );
      
      print('✅ AdminUserProvider: User status toggled successfully');
    } catch (e) {
      print('❌ AdminUserProvider: Error toggling user status: $e');
      rethrow;
    }
  }

  /// Gets a user by ID from the current users list
  /// 
  /// [userId] - The user ID to find
  /// 
  /// Returns the ApplicationUser if found, null otherwise.
  ApplicationUser? getUserById(int userId) {
    try {
      return users.firstWhere((user) => user.id == userId);
    } catch (e) {
      print('⚠️ AdminUserProvider: User with ID $userId not found');
      return null;
    }
  }
}

