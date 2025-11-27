import 'package:flutter/foundation.dart';
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
    notifyListeners();
  }

  /// Logs in a user with email and password
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// 
  /// Returns true if login successful, false otherwise
  /// Updates [token] and [isAuthenticated] on success and notifies listeners
  Future<bool> login(String email, String password) async {
    try {
      await _authService.login(email, password);
      
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

  /// Logs out the current user
  /// 
  /// Deletes the stored token and updates authentication state
  /// Notifies listeners of the state change
  Future<void> logout() async {
    await _authService.deleteToken();
    token = null;
    isAuthenticated = false;
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
      await _authService.updateUser(updateData);
      
      // Reload token from storage (in case it was refreshed)
      token = await _authService.getToken();
      isAuthenticated = token != null && token!.isNotEmpty;
      
      notifyListeners();
      return true;
    } catch (e) {
      // Update failed, notify listeners anyway
      notifyListeners();
      rethrow;
    }
  }
}

