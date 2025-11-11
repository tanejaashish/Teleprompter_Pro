// Comprehensive API Error Handling Utility
// Provides consistent error handling, retry logic, and user-friendly messages

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// API Error Types
enum ApiErrorType {
  networkError,
  timeoutError,
  serverError,
  authenticationError,
  authorizationError,
  validationError,
  notFoundError,
  rateLimitError,
  unknown,
}

/// API Error with detailed information
class ApiError implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final String? details;
  final dynamic originalError;

  const ApiError({
    required this.type,
    required this.message,
    this.statusCode,
    this.details,
    this.originalError,
  });

  /// User-friendly error message
  String get userMessage {
    switch (type) {
      case ApiErrorType.networkError:
        return 'No internet connection. Please check your network and try again.';
      case ApiErrorType.timeoutError:
        return 'Request timed out. Please try again.';
      case ApiErrorType.serverError:
        return 'Server error occurred. Please try again later.';
      case ApiErrorType.authenticationError:
        return 'Authentication failed. Please sign in again.';
      case ApiErrorType.authorizationError:
        return 'You don\'t have permission to perform this action.';
      case ApiErrorType.validationError:
        return details ?? 'Invalid input. Please check your data.';
      case ApiErrorType.notFoundError:
        return 'The requested resource was not found.';
      case ApiErrorType.rateLimitError:
        return 'Too many requests. Please wait a moment and try again.';
      case ApiErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Whether this error should trigger a retry
  bool get isRetryable {
    return type == ApiErrorType.networkError ||
        type == ApiErrorType.timeoutError ||
        type == ApiErrorType.serverError ||
        type == ApiErrorType.rateLimitError;
  }

  /// Whether this error should trigger logout
  bool get requiresReauth {
    return type == ApiErrorType.authenticationError;
  }

  @override
  String toString() => 'ApiError($type): $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// API Error Handler with retry logic
class ApiErrorHandler {
  /// Parse HTTP response into ApiError
  static ApiError fromResponse(http.Response response) {
    final statusCode = response.statusCode;

    // Parse error details from response body
    String? details;
    try {
      final Map<String, dynamic> body = response.body.isNotEmpty
          ? {} // Would normally parse JSON here
          : {};
      details = body['error']?['message'] ?? body['message'];
    } catch (_) {
      // Ignore parsing errors
    }

    // Determine error type based on status code
    ApiErrorType type;
    String message;

    switch (statusCode) {
      case 400:
        type = ApiErrorType.validationError;
        message = 'Invalid request';
        break;
      case 401:
        type = ApiErrorType.authenticationError;
        message = 'Authentication required';
        break;
      case 403:
        type = ApiErrorType.authorizationError;
        message = 'Permission denied';
        break;
      case 404:
        type = ApiErrorType.notFoundError;
        message = 'Resource not found';
        break;
      case 429:
        type = ApiErrorType.rateLimitError;
        message = 'Rate limit exceeded';
        break;
      case >= 500:
        type = ApiErrorType.serverError;
        message = 'Server error';
        break;
      default:
        type = ApiErrorType.unknown;
        message = 'Unexpected error';
    }

    return ApiError(
      type: type,
      message: message,
      statusCode: statusCode,
      details: details,
    );
  }

  /// Parse exception into ApiError
  static ApiError fromException(dynamic error) {
    if (error is SocketException) {
      return const ApiError(
        type: ApiErrorType.networkError,
        message: 'Network connection failed',
        originalError: null,
      );
    }

    if (error is TimeoutException) {
      return const ApiError(
        type: ApiErrorType.timeoutError,
        message: 'Request timed out',
        originalError: null,
      );
    }

    if (error is HttpException) {
      return ApiError(
        type: ApiErrorType.serverError,
        message: 'HTTP error: ${error.message}',
        originalError: error,
      );
    }

    return ApiError(
      type: ApiErrorType.unknown,
      message: 'Unexpected error: ${error.toString()}',
      originalError: error,
    );
  }

  /// Execute request with retry logic
  ///
  /// Automatically retries failed requests with exponential backoff
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() request,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    bool Function(ApiError)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      attempt++;

      try {
        return await request();
      } catch (error) {
        // Convert to ApiError if not already
        final apiError = error is ApiError
            ? error
            : (error is http.Response
                ? fromResponse(error)
                : fromException(error));

        // Check if we should retry
        final canRetry = attempt < maxRetries &&
            (shouldRetry?.call(apiError) ?? apiError.isRetryable);

        if (!canRetry) {
          throw apiError;
        }

        // Wait before retry
        print('Request failed (attempt $attempt/$maxRetries): ${apiError.message}');
        print('Retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);

        // Increase delay for next attempt (exponential backoff)
        delay *= backoffMultiplier.toInt();
      }
    }
  }

  /// Execute request with timeout
  static Future<T> executeWithTimeout<T>({
    required Future<T> Function() request,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiError(
        type: ApiErrorType.timeoutError,
        message: 'Request timed out',
      );
    } catch (error) {
      if (error is ApiError) rethrow;
      throw fromException(error);
    }
  }

  /// Execute request with both timeout and retry
  static Future<T> executeWithTimeoutAndRetry<T>({
    required Future<T> Function() request,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    return executeWithRetry<T>(
      request: () => executeWithTimeout<T>(
        request: request,
        timeout: timeout,
      ),
      maxRetries: maxRetries,
      initialDelay: initialDelay,
    );
  }
}

/// Example usage:
///
/// ```dart
/// try {
///   final result = await ApiErrorHandler.executeWithTimeoutAndRetry(
///     request: () => apiClient.getScripts(),
///     timeout: Duration(seconds: 10),
///     maxRetries: 3,
///   );
///   // Use result
/// } on ApiError catch (error) {
///   // Show user-friendly error message
///   showSnackBar(error.userMessage);
///
///   // Require re-authentication if needed
///   if (error.requiresReauth) {
///     navigateToLogin();
///   }
///
///   // Log for debugging
///   print('API Error: $error');
/// }
/// ```
