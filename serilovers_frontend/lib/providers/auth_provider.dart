import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/auth_service.dart';

/// Provider for managing authentication state
/// 
/// Uses ChangeNotifier to notify listeners of authentication state changes.
/// Manages token storage and provides authentication methods.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  /// Current authentication token
  String? token;

  /// Whether the user is currently authenticated
  bool isAuthenticated = false;

  /// Cached user info from the backend (if provided in responses).
  /// This allows the UI to reflect updated name/email/avatar immediately,
  /// even if the JWT token does not contain all updated claims.
  Map<String, dynamic>? currentUser;

  /// Creates an AuthProvider instance
  /// 
  /// [authService] - Service for authentication operations
  /// 
  /// Note: Call [initialize] after construction to load the stored token,
  /// or use [create] factory method for automatic initialization
  AuthProvider({required AuthService authService}) : _authService = authService;

  /// Factory constructor that creates and initializes AuthProvider
  /// 
  /// [authService] - Service for authentication operations
  /// 
  /// Returns an initialized AuthProvider with token loaded from storage
  static Future<AuthProvider> create({required AuthService authService}) async {
    final provider = AuthProvider(authService: authService);
    await provider.initialize();
    return provider;
  }

  /// Initializes the provider by loading the stored token
  /// 
  /// Should be called after construction to restore authentication state
  Future<void> initialize() async {
    token = await _authService.getToken();
    isAuthenticated = token != null && token!.isNotEmpty;
    // Note: we don't attempt to decode the token here to populate [currentUser].
    // User-specific fields will be populated from backend responses (e.g. profile update).
    notifyListeners();
  }

  /// Logs in a user with email and password
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// [platform] - Platform type: "desktop" or "mobile" (optional)
  /// 
  /// Returns true if login successful, false otherwise
  /// Updates [token] and [isAuthenticated] on success and notifies listeners
  Future<bool> login(String email, String password, {String? platform}) async {
    try {
      await _authService.login(email, password, platform: platform);
      
      // Reload token from storage (AuthService saves it automatically)
      token = await _authService.getToken();
      isAuthenticated = token != null && token!.isNotEmpty;
      
      notifyListeners();
      return true;
    } catch (e) {
      // Login failed, ensure state is cleared
      token = null;
      isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Logs in a user with Google OAuth
  /// 
  /// [accessToken] - Google OAuth access token
  /// 
  /// Returns true if login successful, false otherwise
  /// Updates [token] and [isAuthenticated] on success and notifies listeners
  Future<bool> loginWithGoogle(String accessToken) async {
    try {
      await _authService.loginWithGoogle(accessToken);
      
      // Reload token from storage (AuthService saves it automatically)
      token = await _authService.getToken();
      isAuthenticated = token != null && token!.isNotEmpty;
      
      notifyListeners();
      return true;
    } catch (e) {
      // Login failed, ensure state is cleared
      token = null;
      isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Registers a new user with email and password
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// [confirmPassword] - Password confirmation
  /// 
  /// Returns true if registration successful, false otherwise
  /// Note: Registration doesn't automatically log in the user
  Future<bool> register(String email, String password, String confirmPassword) async {
    try {
      await _authService.register(email, password, confirmPassword);
      return true;
    } catch (e) {
      print('Registration failed: $e');
      return false;
    }
  }

  /// Logs out the current user
  /// 
  /// Deletes the stored token and updates authentication state
  /// Notifies listeners of the state change
  Future<void> logout() async {
    await _authService.deleteToken();
    token = null;
    isAuthenticated = false;
    currentUser = null;
    notifyListeners();
  }

  /// Returns authorization header for API requests
  /// 
  /// Returns a Map with 'Authorization' header if token is present,
  /// otherwise returns an empty Map
  Map<String, String> get authHeader {
    if (token != null && token!.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  /// Updates the current user's profile
  /// 
  /// [updateData] - Map containing fields to update (name, email, currentPassword, newPassword, avatar, avatarFileName)
  /// 
  /// Returns true if update successful, false otherwise
  /// Notifies listeners on success
  Future<bool> updateUser(Map<String, dynamic> updateData) async {
    try {
      final response = await _authService.updateUser(updateData);
      
      // Check if response contains a new token and save it
      if (response is Map<String, dynamic>) {
        print('📥 Profile update response: $response');
        
        // Cache updated user info FIRST if backend returns it
        // This is the single source of truth for name/email/avatar after updates.
        final userData = response['user'];
        if (userData is Map<String, dynamic>) {
          print('✅ User data in response: $userData');
          print('✅ Name in response: ${userData['name']}');
          currentUser = Map<String, dynamic>.from(userData);
          print('✅ Updated currentUser: $currentUser');
          print('✅ currentUser name: ${currentUser?['name']}');
        } else {
          print('⚠️ No user data in response, will try token decode');
        }

        // Try multiple possible token field names
        final newToken = response['token'] as String? ?? 
                        response['Token'] as String? ??
                        response['accessToken'] as String? ?? 
                        response['access_token'] as String? ?? 
                        response['jwt'] as String?;
        
        if (newToken != null && newToken.isNotEmpty) {
          // Save the new token (which includes updated user info)
          await _authService.saveToken(newToken);
          token = newToken;
          isAuthenticated = true;
          
          // If userData was not in response, decode from token as fallback
          if (userData == null || userData is! Map<String, dynamic>) {
            try {
              final decoded = JwtDecoder.decode(token!);
              currentUser = {
                'email': decoded['email'] ?? '',
                'name': decoded['name'] ?? '',
                'avatarUrl': decoded['avatarUrl'],
              };
              print('✅ Decoded user from token: $currentUser');
            } catch (e) {
              print('❌ Token decode failed: $e');
            }
          }
        } else {
          // If no token in response, reload from storage
          token = await _authService.getToken();
          isAuthenticated = token != null && token!.isNotEmpty;
        }
        
        print('🔄 Notifying listeners with currentUser: $currentUser');
        // Force notify listeners to update all UI components
        notifyListeners();
        return true;
      } else {
        // Invalid response format
        throw Exception('Invalid response format from server');
      }
    } catch (e) {
      // Update failed - don't notify listeners to avoid showing stale data
      print('❌ Error updating user: $e');
      rethrow;
    }
  }
}

