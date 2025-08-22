// packages/auth_sync/lib/auth/auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

// User Model
class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final SubscriptionTier subscriptionTier;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final UserPreferences preferences;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.subscriptionTier,
    required this.createdAt,
    this.metadata,
    required this.preferences,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    email: json['email'],
    displayName: json['displayName'],
    photoUrl: json['photoUrl'],
    subscriptionTier: SubscriptionTier.fromString(json['subscriptionTier']),
    createdAt: DateTime.parse(json['createdAt']),
    metadata: json['metadata'],
    preferences: UserPreferences.fromJson(json['preferences']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'subscriptionTier': subscriptionTier.name,
    'createdAt': createdAt.toIso8601String(),
    'metadata': metadata,
    'preferences': preferences.toJson(),
  };
}

enum SubscriptionTier {
  free('Free'),
  creator('Creator'),
  professional('Professional'),
  enterprise('Enterprise');

  final String displayName;
  const SubscriptionTier(this.displayName);

  static SubscriptionTier fromString(String value) {
    return SubscriptionTier.values.firstWhere(
      (tier) => tier.name == value,
      orElse: () => SubscriptionTier.free,
    );
  }
}

class UserPreferences {
  final bool enableSync;
  final bool enableNotifications;
  final bool enableAnalytics;
  final String theme;
  final String language;

  UserPreferences({
    this.enableSync = true,
    this.enableNotifications = true,
    this.enableAnalytics = true,
    this.theme = 'system',
    this.language = 'en',
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
    enableSync: json['enableSync'] ?? true,
    enableNotifications: json['enableNotifications'] ?? true,
    enableAnalytics: json['enableAnalytics'] ?? true,
    theme: json['theme'] ?? 'system',
    language: json['language'] ?? 'en',
  );

  Map<String, dynamic> toJson() => {
    'enableSync': enableSync,
    'enableNotifications': enableNotifications,
    'enableAnalytics': enableAnalytics,
    'theme': theme,
    'language': language,
  };
}

// Authentication State
abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {
  final String? message;
  AuthUnauthenticated([this.message]);
}
class AuthError extends AuthState {
  final String error;
  AuthError(this.error);
}

// Session Model
class Session {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String deviceId;
  final String? deviceName;

  Session({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.deviceId,
    this.deviceName,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    accessToken: json['accessToken'],
    refreshToken: json['refreshToken'],
    expiresAt: DateTime.parse(json['expiresAt']),
    deviceId: json['deviceId'],
    deviceName: json['deviceName'],
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'deviceId': deviceId,
    'deviceName': deviceName,
  };
}

// Main Authentication Service
class AuthService {
  static const String _baseUrl = 'https://api.teleprompt.pro/v1';
  static const String _storageKeyToken = 'auth_token';
  static const String _storageKeyUser = 'auth_user';
  static const String _storageKeySession = 'auth_session';
  
  final FlutterSecureStorage _secureStorage;
  final GoogleSignIn _googleSignIn;
  final _authStateController = StreamController<AuthState>.broadcast();
  
  User? _currentUser;
  Session? _currentSession;
  Timer? _refreshTimer;
  
  Stream<AuthState> get authState => _authStateController.stream;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _currentSession != null;
  
  AuthService()
    : _secureStorage = const FlutterSecureStorage(),
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: 'YOUR_GOOGLE_CLIENT_ID',
      ) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // Check for stored session
      final storedSession = await _secureStorage.read(key: _storageKeySession);
      final storedUser = await _secureStorage.read(key: _storageKeyUser);
      
      if (storedSession != null && storedUser != null) {
        _currentSession = Session.fromJson(jsonDecode(storedSession));
        _currentUser = User.fromJson(jsonDecode(storedUser));
        
        if (_currentSession!.isExpired) {
          await _refreshSession();
        } else {
          _authStateController.add(AuthAuthenticated(_currentUser!));
          _scheduleTokenRefresh();
        }
      } else {
        _authStateController.add(AuthUnauthenticated());
      }
    } catch (e) {
      _authStateController.add(AuthError('Failed to initialize auth: $e'));
    }
  }

  // Email/Password Authentication
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _authStateController.add(AuthLoading());
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'deviceId': await _getDeviceId(),
          'deviceName': await _getDeviceName(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        _currentSession = Session.fromJson(data['session']);
        
        await _saveAuthData();
        _scheduleTokenRefresh();
        _authStateController.add(AuthAuthenticated(_currentUser!));
        
        return _currentUser!;
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Sign in failed';
        _authStateController.add(AuthUnauthenticated(error));
        throw AuthException(error);
      }
    } catch (e) {
      _authStateController.add(AuthError(e.toString()));
      throw AuthException(e.toString());
    }
  }

  Future<User> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _authStateController.add(AuthLoading());
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'displayName': displayName,
          'deviceId': await _getDeviceId(),
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        _currentSession = Session.fromJson(data['session']);
        
        await _saveAuthData();
        _scheduleTokenRefresh();
        _authStateController.add(AuthAuthenticated(_currentUser!));
        
        return _currentUser!;
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Sign up failed';
        _authStateController.add(AuthUnauthenticated(error));
        throw AuthException(error);
      }
    } catch (e) {
      _authStateController.add(AuthError(e.toString()));
      throw AuthException(e.toString());
    }
  }

  // OAuth Authentication
  Future<User> signInWithGoogle() async {
    try {
      _authStateController.add(AuthLoading());
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _authStateController.add(AuthUnauthenticated('Google sign in cancelled'));
        throw AuthException('Google sign in cancelled');
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/oauth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': googleAuth.idToken,
          'accessToken': googleAuth.accessToken,
          'deviceId': await _getDeviceId(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        _currentSession = Session.fromJson(data['session']);
        
        await _saveAuthData();
        _scheduleTokenRefresh();
        _authStateController.add(AuthAuthenticated(_currentUser!));
        
        return _currentUser!;
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Google sign in failed';
        _authStateController.add(AuthUnauthenticated(error));
        throw AuthException(error);
      }
    } catch (e) {
      _authStateController.add(AuthError(e.toString()));
      throw AuthException(e.toString());
    }
  }

  Future<User> signInWithApple() async {
    try {
      _authStateController.add(AuthLoading());
      
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _generateNonce(),
      );
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/oauth/apple'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identityToken': credential.identityToken,
          'authorizationCode': credential.authorizationCode,
          'email': credential.email,
          'fullName': credential.givenName != null 
            ? '${credential.givenName} ${credential.familyName}' 
            : null,
          'deviceId': await _getDeviceId(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        _currentSession = Session.fromJson(data['session']);
        
        await _saveAuthData();
        _scheduleTokenRefresh();
        _authStateController.add(AuthAuthenticated(_currentUser!));
        
        return _currentUser!;
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Apple sign in failed';
        _authStateController.add(AuthUnauthenticated(error));
        throw AuthException(error);
      }
    } catch (e) {
      _authStateController.add(AuthError(e.toString()));
      throw AuthException(e.toString());
    }
  }

  // Session Management
  Future<void> _refreshSession() async {
    if (_currentSession == null) return;
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_currentSession!.refreshToken}',
        },
        body: jsonEncode({
          'deviceId': await _getDeviceId(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentSession = Session.fromJson(data['session']);
        
        // Update user data if provided
        if (data['user'] != null) {
          _currentUser = User.fromJson(data['user']);
        }
        
        await _saveAuthData();
        _scheduleTokenRefresh();
        
        if (_currentUser != null) {
          _authStateController.add(AuthAuthenticated(_currentUser!));
        }
      } else {
        // Refresh failed, sign out
        await signOut();
      }
    } catch (e) {
      // Network error, keep current session
      print('Token refresh error: $e');
    }
  }

  void _scheduleTokenRefresh() {
    _refreshTimer?.cancel();
    
    if (_currentSession != null) {
      final timeUntilExpiry = _currentSession!.expiresAt
          .subtract(const Duration(minutes: 5))
          .difference(DateTime.now());
      
      if (timeUntilExpiry.isNegative) {
        _refreshSession();
      } else {
        _refreshTimer = Timer(timeUntilExpiry, _refreshSession);
      }
    }
  }

  Future<void> signOut() async {
    try {
      // Notify server about sign out
      if (_currentSession != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/signout'),
          headers: {
            'Authorization': 'Bearer ${_currentSession!.accessToken}',
          },
        );
      }
    } catch (e) {
      // Continue with local sign out even if server call fails
    }
    
    // Clear local data
    _currentUser = null;
    _currentSession = null;
    _refreshTimer?.cancel();
    
    await _secureStorage.delete(key: _storageKeyToken);
    await _secureStorage.delete(key: _storageKeyUser);
    await _secureStorage.delete(key: _storageKeySession);
    
    await _googleSignIn.signOut();
    
    _authStateController.add(AuthUnauthenticated());
  }

  // Helper Methods
  Future<void> _saveAuthData() async {
    if (_currentSession != null) {
      await _secureStorage.write(
        key: _storageKeySession,
        value: jsonEncode(_currentSession!.toJson()),
      );
    }
    
    if (_currentUser != null) {
      await _secureStorage.write(
        key: _storageKeyUser,
        value: jsonEncode(_currentUser!.toJson()),
      );
    }
  }

  Future<String> _getDeviceId() async {
    // Implementation depends on platform
    // Use device_info_plus package
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _getDeviceName() async {
    // Implementation depends on platform
    return 'TelePrompt Pro Device';
  }

  String _generateNonce() {
    final random = List<int>.generate(32, (i) => 
      DateTime.now().millisecondsSinceEpoch % 256);
    return base64Url.encode(sha256.convert(random).bytes);
  }

  // API Request Helper
  Future<T> authenticatedRequest<T>({
    required String path,
    required String method,
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    if (_currentSession == null) {
      throw AuthException('Not authenticated');
    }
    
    if (_currentSession!.isExpired) {
      await _refreshSession();
    }
    
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_currentSession!.accessToken}',
    };
    
    http.Response response;
    
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw AuthException('Unsupported HTTP method: $method');
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parser(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      // Token expired, try refresh
      await _refreshSession();
      // Retry request
      return authenticatedRequest(
        path: path,
        method: method,
        body: body,
        parser: parser,
      );
    } else {
      throw AuthException('Request failed: ${response.statusCode}');
    }
  }

  void dispose() {
    _refreshTimer?.cancel();
    _authStateController.close();
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => message;
}