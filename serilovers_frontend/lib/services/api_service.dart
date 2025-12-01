import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Service class for making HTTP requests to the API
/// 
/// This service handles:
/// - Base URL configuration from environment variables
/// - Authentication token management
/// - Standard HTTP methods (GET, POST, PUT, DELETE)
/// - Error handling for non-2xx responses
class ApiService {
  // Base URL loaded from environment variables
  String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';

  /// Builds headers for API requests
  /// 
  /// Always includes Content-Type: application/json
  /// Adds Authorization header if token is provided
  Map<String, String> _buildHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Handles HTTP response and throws ApiException for non-2xx status codes
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success: return parsed JSON or empty string
      if (response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    } else {
      // Error: throw exception with status code and message
      throw ApiException(
        'Request failed: ${response.body.isNotEmpty ? response.body : response.reasonPhrase ?? "Unknown error"}',
        response.statusCode,
      );
    }
  }

  /// Performs a GET request
  /// 
  /// [path] - API endpoint path (relative to baseUrl)
  /// [token] - Optional authentication token
  Future<dynamic> get(String path, {String? token}) async {
    final fullUrl = '$baseUrl$path';
    final uri = Uri.parse(fullUrl);
    print('📡 API GET Request:');
    print('   Base URL: $baseUrl');
    print('   Path: $path');
    print('   Full URL: $fullUrl');
    print('   Has Token: ${token != null && token.isNotEmpty}');
    
    final response = await http.get(
      uri,
      headers: _buildHeaders(token: token),
    );

    print('📥 API Response Status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('   Response Body: ${response.body}');
    }

    return _handleResponse(response);
  }

  /// Performs a POST request
  /// 
  /// [path] - API endpoint path (relative to baseUrl)
  /// [body] - Request body as a Map (will be JSON encoded)
  /// [token] - Optional authentication token
  Future<dynamic> post(String path, Map<String, dynamic> body, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.post(
      uri,
      headers: _buildHeaders(token: token),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  /// Performs a PUT request
  /// 
  /// [path] - API endpoint path (relative to baseUrl)
  /// [body] - Request body as a Map (will be JSON encoded)
  /// [token] - Optional authentication token
  Future<dynamic> put(String path, Map<String, dynamic> body, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.put(
      uri,
      headers: _buildHeaders(token: token),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  /// Performs a DELETE request
  /// 
  /// [path] - API endpoint path (relative to baseUrl)
  /// [token] - Optional authentication token
  Future<dynamic> delete(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.delete(
      uri,
      headers: _buildHeaders(token: token),
    );

    return _handleResponse(response);
  }

  /// Uploads a file to the server
  /// 
  /// [path] - API endpoint path (relative to baseUrl)
  /// [file] - The file to upload (File object)
  /// [folder] - Folder name for organizing uploads (series, actors, avatars)
  /// [token] - Optional authentication token
  /// Returns the response containing the imageUrl
  Future<dynamic> uploadFile(String path, File file, {String folder = 'general', String? token}) async {
    final uri = Uri.parse('$baseUrl$path?folder=$folder');
    
    // Build multipart request
    final request = http.MultipartRequest('POST', uri);
    
    // Add authorization header
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    // Get file extension and determine content type
    final fileName = file.path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();
    final contentType = _getContentType(extension);
    
    // Add file to request
    final fileStream = file.openRead();
    final fileLength = await file.length();
    final multipartFile = http.MultipartFile(
      'file',
      fileStream,
      fileLength,
      filename: fileName,
      contentType: contentType,
    );
    
    request.files.add(multipartFile);
    
    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }

  /// Uploads a file from bytes (for web platform)
  /// 
  /// [path] - API endpoint path (relative to baseUrl)
  /// [bytes] - File bytes
  /// [fileName] - Name of the file
  /// [folder] - Folder name for organizing uploads
  /// [token] - Optional authentication token
  Future<dynamic> uploadFileFromBytes(
    String path,
    List<int> bytes,
    String fileName, {
    String folder = 'general',
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path?folder=$folder');
    
    // Build multipart request
    final request = http.MultipartRequest('POST', uri);
    
    // Add authorization header
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    // Get content type from file extension
    final extension = fileName.split('.').last.toLowerCase();
    final contentType = _getContentType(extension);
    
    // Add file to request
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
      contentType: contentType,
    );
    
    request.files.add(multipartFile);
    
    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }

  /// Gets the MediaType for a file extension
  MediaType _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'jpeg');
    }
  }
}

