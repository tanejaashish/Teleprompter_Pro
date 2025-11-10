// API Client for Flutter Frontend
// Comprehensive HTTP client with error handling, authentication, and retry logic

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final Duration timeout;
  String? _accessToken;
  String? _refreshToken;

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
  });

  // Set authentication tokens
  void setTokens(String accessToken, String refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  // Clear tokens on logout
  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  // GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _request<T>(
      'GET',
      path,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
    );
  }

  // POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    return _request<T>(
      'POST',
      path,
      body: body,
      requiresAuth: requiresAuth,
    );
  }

  // PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    return _request<T>(
      'PUT',
      path,
      body: body,
      requiresAuth: requiresAuth,
    );
  }

  // DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    bool requiresAuth = true,
  }) async {
    return _request<T>(
      'DELETE',
      path,
      requiresAuth: requiresAuth,
    );
  }

  // Core request method
  Future<ApiResponse<T>> _request<T>(
    String method,
    String path, {
    Map<String, String>? queryParams,
    dynamic body,
    bool requiresAuth = true,
    int retryCount = 0,
  }) async {
    try {
      // Build URL
      final uri = _buildUri(path, queryParams);

      // Build headers
      final headers = await _buildHeaders(requiresAuth);

      // Create request
      final request = http.Request(method, uri);
      request.headers.addAll(headers);

      if (body != null) {
        request.body = json.encode(body);
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      // Handle token expiration
      if (response.statusCode == 401 && requiresAuth && retryCount == 0) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          // Retry request with new token
          return _request<T>(
            method,
            path,
            queryParams: queryParams,
            body: body,
            requiresAuth: requiresAuth,
            retryCount: retryCount + 1,
          );
        }
      }

      // Parse response
      return _parseResponse<T>(response);
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Server error occurred');
    } on FormatException {
      return ApiResponse.error('Invalid response format');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred: $e');
    }
  }

  // Build URI with query parameters
  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final uri = Uri.parse('$baseUrl$path');

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }

    return uri;
  }

  // Build request headers
  Future<Map<String, String>> _buildHeaders(bool requiresAuth) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  // Refresh access token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['accessToken'];
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Parse HTTP response
  ApiResponse<T> _parseResponse<T>(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      try {
        final data = json.decode(response.body);
        return ApiResponse.success(data as T, statusCode);
      } catch (e) {
        return ApiResponse.error('Failed to parse response');
      }
    } else {
      try {
        final error = json.decode(response.body);
        final message = error['error']?['message'] ??
            error['message'] ??
            'Request failed';
        return ApiResponse.error(message, statusCode);
      } catch (e) {
        return ApiResponse.error('Request failed', statusCode);
      }
    }
  }

  // Upload file
  Future<ApiResponse<T>> uploadFile<T>(
    String path,
    File file, {
    Map<String, String>? fields,
    String fileField = 'file',
  }) async {
    try {
      final uri = _buildUri(path, null);
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _buildHeaders(true);
      request.headers.addAll(headers);

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(fileField, file.path),
      );

      // Add fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Send request
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _parseResponse<T>(response);
    } catch (e) {
      return ApiResponse.error('File upload failed: $e');
    }
  }
}

// API Response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool isSuccess;

  ApiResponse._({
    this.data,
    this.error,
    this.statusCode,
    required this.isSuccess,
  });

  factory ApiResponse.success(T data, [int statusCode = 200]) {
    return ApiResponse._(
      data: data,
      statusCode: statusCode,
      isSuccess: true,
    );
  }

  factory ApiResponse.error(String error, [int? statusCode]) {
    return ApiResponse._(
      error: error,
      statusCode: statusCode,
      isSuccess: false,
    );
  }
}

// API Service classes for different endpoints
class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<ApiResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _client.post('/api/auth/signup', body: {
      'email': email,
      'password': password,
      if (displayName != null) 'displayName': displayName,
    }, requiresAuth: false);
  }

  Future<ApiResponse> signIn({
    required String email,
    required String password,
    String? deviceId,
    String? deviceName,
  }) async {
    final response = await _client.post('/api/auth/signin', body: {
      'email': email,
      'password': password,
      if (deviceId != null) 'deviceId': deviceId,
      if (deviceName != null) 'deviceName': deviceName,
    }, requiresAuth: false);

    if (response.isSuccess) {
      final data = response.data as Map<String, dynamic>;
      _client.setTokens(
        data['session']['accessToken'],
        data['session']['refreshToken'],
      );
    }

    return response;
  }

  Future<ApiResponse> signOut() async {
    final response = await _client.post('/api/auth/signout', body: {});
    _client.clearTokens();
    return response;
  }
}

class ScriptService {
  final ApiClient _client;

  ScriptService(this._client);

  Future<ApiResponse> getScripts() async {
    return _client.get('/api/scripts');
  }

  Future<ApiResponse> createScript({
    required String title,
    required String content,
    String? richContent,
    String? category,
    List<String>? tags,
  }) async {
    return _client.post('/api/scripts', body: {
      'title': title,
      'content': content,
      if (richContent != null) 'richContent': richContent,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
    });
  }

  Future<ApiResponse> updateScript(
    String id, {
    String? title,
    String? content,
    String? richContent,
    String? category,
    List<String>? tags,
  }) async {
    return _client.put('/api/scripts/$id', body: {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (richContent != null) 'richContent': richContent,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
    });
  }

  Future<ApiResponse> deleteScript(String id) async {
    return _client.delete('/api/scripts/$id');
  }
}

class RecordingService {
  final ApiClient _client;

  RecordingService(this._client);

  Future<ApiResponse> getRecordings() async {
    return _client.get('/api/recordings');
  }

  Future<ApiResponse> uploadRecording({
    required File file,
    required String title,
    String? scriptId,
    int? duration,
  }) async {
    return _client.uploadFile(
      '/api/recordings/upload',
      file,
      fields: {
        'title': title,
        if (scriptId != null) 'scriptId': scriptId,
        if (duration != null) 'duration': duration.toString(),
      },
    );
  }
}
