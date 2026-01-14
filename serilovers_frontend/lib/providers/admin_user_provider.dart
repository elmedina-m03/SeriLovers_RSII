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
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }
      final response = await _apiService.get('/Users', token: token);
      if (response is List) {
        users = response.map((item) {
          try {
            return ApplicationUser.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            rethrow;
          }
        }).toList();
      } else if (response is Map && response.containsKey('items')) {
        final itemsList = response['items'] as List<dynamic>? ?? [];
        users = itemsList.map((item) {
          try {
            return ApplicationUser.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            rethrow;
          }
        }).toList();
      } else {
        users = [];
      }
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
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
      final response = await _apiService.get(apiPath, token: token);
      // Parse response
      if (response is Map<String, dynamic>) {
        final itemsList = response['items'] as List<dynamic>? ?? [];
        users = itemsList.map((item) {
          try {
            return ApplicationUser.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            rethrow;
          }
        }).toList();

        // Extract pagination metadata
        totalItems = response['totalItems'] as int? ?? users.length;
        totalPages = response['totalPages'] as int? ?? 1;
        currentPage = response['currentPage'] as int? ?? currentPage;
        pageSize = response['pageSize'] as int? ?? pageSize;
      } else if (response is List) {
        // Fallback: client-side pagination if backend doesn't support it
        final allUsers = response.map((item) {
          try {
            return ApplicationUser.fromJson(item as Map<String, dynamic>);
          } catch (e) {
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
      } else {
        users = [];
        totalItems = 0;
        totalPages = 1;
      }
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
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
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Prepare update data (only include non-null values)
      final updateData = <String, dynamic>{};
      if (email != null) updateData['email'] = email;
      if (role != null) updateData['role'] = role;
      if (isActive != null) updateData['isActive'] = isActive;
      final response = await _apiService.put(
        '/Users/$userId',
        updateData,
        token: token,
      );
      // Parse the updated user
      final updatedUser = ApplicationUser.fromJson(response as Map<String, dynamic>);
      
      // Update in local list
      final index = users.indexWhere((user) => user.id == userId);
      if (index != -1) {
        users[index] = updatedUser;
        notifyListeners();
      } else {
      }
      return updatedUser;
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a user
  /// 
  /// [userId] - ID of the user to delete
  Future<void> deleteUser(int userId) async {
    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }
      await _apiService.delete(
        '/Users/$userId',
        token: token,
      );
      users.removeWhere((user) => user.id == userId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Disables/enables a user (legacy method for backward compatibility)
  Future<void> toggleUserStatus(ApplicationUser user) async {
    try {
      await updateUser(
        user.id,
        isActive: !user.isActive,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a new user
  /// 
  /// [email] - User email (required)
  /// [password] - User password (required)
  /// [name] - User full name (optional)
  /// [phone] - User phone number (optional)
  /// [country] - User country (optional)
  /// [role] - User role (optional, defaults to 'User')
  Future<ApplicationUser> createUser({
    required String email,
    required String password,
    String? name,
    String? phone,
    String? country,
    String? role,
  }) async {
    try {
      final token = _authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Prepare create data
      final createData = <String, dynamic>{
        'email': email,
        'password': password,
      };
      
      // Add optional fields if provided
      if (name != null && name.isNotEmpty) {
        createData['name'] = name;
      }
      if (phone != null && phone.isNotEmpty) {
        createData['phone'] = phone;
      }
      if (country != null && country.isNotEmpty) {
        createData['country'] = country;
      }
      if (role != null && role.isNotEmpty) {
        createData['role'] = role;
      }
      // Use register endpoint (may need admin-specific endpoint for role assignment)
      final response = await _apiService.post(
        '/Auth/register',
        createData,
        token: token,
      );
      // After creation, fetch the user list to get the new user
      await fetchFiltered();
      
      // Find the newly created user by email
      final newUser = users.firstWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('User created but not found in list'),
      );
      
      // If role was specified and different from default, update it
      if (role != null && role.isNotEmpty && role != 'User') {
        try {
          await updateUser(newUser.id, role: role);
          return getUserById(newUser.id) ?? newUser;
        } catch (e) {
        }
      }
      return newUser;
    } catch (e) {
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
      return null;
    }
  }
}

