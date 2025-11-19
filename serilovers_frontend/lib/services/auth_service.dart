import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

/// Service for handling authentication operations
/// 
/// Manages:
/// - User login (email/password and Google)
/// - Secure token storage and retrieval
/// - Token lifecycle management
class AuthService {
  final ApiService _apiService;
  final FlutterSecureStorage _storage;
  
  // Key for storing the authentication token
  static const String _tokenKey = 'auth_token';

  /// Creates an instance of AuthService
  /// 
  /// [apiService] - Service for making API requests
  /// [storage] - Optional secure storage instance (creates default if not provided)
  AuthService({
    required ApiService apiService,
    FlutterSecureStorage? storage,
  })  : _apiService = apiService,
        _storage = storage ?? const FlutterSecureStorage();

  /// Saves the authentication token securely
  /// 
  /// [token] - The JWT token to store
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Retrieves the stored authentication token
  /// 
  /// Returns the token if found, null otherwise
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Deletes the stored authentication token
  /// 
  /// Use this for logout operations
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Logs in a user with email and password
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// 
  /// Returns a Map containing the API response
  /// Automatically saves the token if the response contains one
  /// 
  /// Throws [ApiException] or [AuthException] on failure
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiService.post(
        '/Auth/login',
        {
          'email': email,
          'password': password,
        },
      );

      // Ensure response is a Map
      if (response is! Map<String, dynamic>) {
        throw AuthException('Invalid response format from server');
      }

      // Extract and save token if present
      // Token might be in 'token', 'accessToken', 'access_token', or 'jwt' field
      final token = response['token'] ?? 
                   response['accessToken'] ?? 
                   response['access_token'] ?? 
                   response['jwt'];

      if (token != null && token is String) {
        await saveToken(token);
      }

      return response;
    } on ApiException catch (e) {
      // Convert API exceptions to user-friendly auth exceptions
      throw AuthException(
        _getFriendlyErrorMessage(e.statusCode, e.message),
        e.statusCode,
      );
    } catch (e) {
      throw AuthException('Login failed: ${e.toString()}');
    }
  }

  /// Logs in a user with Google OAuth
  /// 
  /// [accessToken] - Google OAuth access token
  /// 
  /// Returns a Map containing the API response
  /// Automatically saves the token if the response contains one
  /// 
  /// Throws [ApiException] or [AuthException] on failure
  Future<Map<String, dynamic>> loginWithGoogle(String accessToken) async {
    try {
      final response = await _apiService.post(
        '/Auth/external/google',
        {
          'accessToken': accessToken,
        },
      );

      // Ensure response is a Map
      if (response is! Map<String, dynamic>) {
        throw AuthException('Invalid response format from server');
      }

      // Extract and save token if present
      final token = response['token'] ?? 
                   response['accessToken'] ?? 
                   response['access_token'] ?? 
                   response['jwt'];

      if (token != null && token is String) {
        await saveToken(token);
      }

      return response;
    } on ApiException catch (e) {
      // Convert API exceptions to user-friendly auth exceptions
      throw AuthException(
        _getFriendlyErrorMessage(e.statusCode, e.message),
        e.statusCode,
      );
    } catch (e) {
      throw AuthException('Google login failed: ${e.toString()}');
    }
  }

  /// Converts API error codes to user-friendly messages
  String _getFriendlyErrorMessage(int? statusCode, String originalMessage) {
    switch (statusCode) {
      case 400:
        return 'Invalid email or password. Please check your credentials and try again.';
      case 401:
        return 'Authentication failed. Please check your credentials.';
      case 403:
        return 'Access denied. You do not have permission to perform this action.';
      case 404:
        return 'Authentication endpoint not found. Please contact support.';
      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        // Try to extract a friendly message from the original message
        if (originalMessage.toLowerCase().contains('invalid') ||
            originalMessage.toLowerCase().contains('incorrect')) {
          return 'Invalid credentials. Please check your email and password.';
        }
        return originalMessage;
    }
  }
}

/// Custom exception for authentication errors
/// 
/// Provides user-friendly error messages
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

