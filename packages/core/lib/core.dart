// Core Package - Main Entry Point
// Central initialization and service management for TelePrompt Pro

library core;

// Export all services
export 'services/websocket_client.dart';
export 'services/sync_service.dart';
export 'database/local_database.dart';
export 'widgets/offline_indicator.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/websocket_client.dart';
import 'services/sync_service.dart';
import 'database/local_database.dart';

/// Global service manager for TelePrompt Pro
///
/// Handles initialization and lifecycle of all core services including:
/// - Local database (Drift/SQLite)
/// - WebSocket client for real-time features
/// - Sync service for offline-first architecture
/// - API client for backend communication
class AppServices {
  static AppServices? _instance;
  static AppServices get instance {
    _instance ??= AppServices._internal();
    return _instance!;
  }

  AppServices._internal();

  // Service instances
  LocalDatabase? _database;
  WebSocketClient? _wsClient;
  SyncService? _syncService;
  Connectivity? _connectivity;

  // Configuration
  String? _baseUrl;
  String? _accessToken;
  bool _initialized = false;

  // Getters
  LocalDatabase get database {
    if (_database == null) {
      throw StateError('AppServices not initialized. Call AppServices.initialize() first');
    }
    return _database!;
  }

  WebSocketClient get wsClient {
    if (_wsClient == null) {
      throw StateError('AppServices not initialized. Call AppServices.initialize() first');
    }
    return _wsClient!;
  }

  SyncService get syncService {
    if (_syncService == null) {
      throw StateError('AppServices not initialized. Call AppServices.initialize() first');
    }
    return _syncService!;
  }

  bool get isInitialized => _initialized;

  /// Initialize all core services
  ///
  /// Must be called once at app startup before using any services.
  ///
  /// Example:
  /// ```dart
  /// await AppServices.initialize(
  ///   baseUrl: 'https://api.teleprompt.pro',
  ///   accessToken: userSession.accessToken,
  /// );
  /// ```
  static Future<void> initialize({
    required String baseUrl,
    String? accessToken,
  }) async {
    final services = AppServices.instance;

    if (services._initialized) {
      print('AppServices already initialized');
      return;
    }

    print('Initializing AppServices...');

    // Initialize local database
    print('• Initializing database...');
    services._database = DatabaseManager.instance;
    await services._database!.clearExpiredCache();
    print('  ✓ Database ready');

    // Initialize connectivity monitoring
    print('• Initializing connectivity monitoring...');
    services._connectivity = Connectivity();
    print('  ✓ Connectivity monitoring ready');

    // Initialize sync service
    print('• Initializing sync service...');
    services._syncService = SyncServiceManager.instance(
      database: services._database!,
      connectivity: services._connectivity!,
    );
    await services._syncService!.initialize();
    print('  ✓ Sync service ready');

    // Initialize WebSocket client if token provided
    if (accessToken != null) {
      print('• Initializing WebSocket client...');
      services._wsClient = WebSocketManager.getInstance(
        baseUrl: baseUrl,
        accessToken: accessToken,
      );
      await services._wsClient!.connect();
      print('  ✓ WebSocket connected');
    } else {
      print('• Skipping WebSocket (no access token)');
    }

    services._baseUrl = baseUrl;
    services._accessToken = accessToken;
    services._initialized = true;

    print('✓ AppServices initialized successfully');
  }

  /// Update access token and reconnect WebSocket
  ///
  /// Call this after user login or token refresh
  Future<void> updateToken(String newToken) async {
    if (!_initialized || _baseUrl == null) {
      throw StateError('AppServices not initialized');
    }

    _accessToken = newToken;

    // Disconnect existing WebSocket
    if (_wsClient != null) {
      await _wsClient!.disconnect();
      WebSocketManager.dispose();
    }

    // Create new WebSocket with new token
    _wsClient = WebSocketManager.getInstance(
      baseUrl: _baseUrl!,
      accessToken: newToken,
    );
    await _wsClient!.connect();

    print('✓ Token updated, WebSocket reconnected');
  }

  /// Trigger manual sync
  ///
  /// Useful for pull-to-refresh or retry after error
  Future<void> syncNow() async {
    if (_syncService == null) {
      throw StateError('Sync service not initialized');
    }

    print('Starting manual sync...');
    final result = await _syncService!.syncAll();

    if (result.success) {
      print('✓ Sync completed: ${result.itemsSynced} items');
    } else {
      print('✗ Sync failed: ${result.errors}');
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    return await _database!.getDatabaseStats();
  }

  /// Clear all local data (use for logout)
  Future<void> clearAllData() async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    print('Clearing all local data...');
    await _database!.clearAllData();
    print('✓ All data cleared');
  }

  /// Dispose all services
  ///
  /// Call this on app termination or logout
  static Future<void> dispose() async {
    final services = AppServices.instance;

    if (!services._initialized) {
      return;
    }

    print('Disposing AppServices...');

    // Disconnect WebSocket
    if (services._wsClient != null) {
      await services._wsClient!.disconnect();
      WebSocketManager.dispose();
    }

    // Stop sync service
    if (services._syncService != null) {
      await services._syncService!.dispose();
      SyncServiceManager.dispose();
    }

    // Close database
    if (services._database != null) {
      DatabaseManager.dispose();
    }

    services._database = null;
    services._wsClient = null;
    services._syncService = null;
    services._connectivity = null;
    services._initialized = false;

    print('✓ AppServices disposed');
  }
}

/// Example usage in main.dart:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Initialize services (after user login)
///   await AppServices.initialize(
///     baseUrl: 'https://api.teleprompt.pro',
///     accessToken: userSession.accessToken,
///   );
///
///   runApp(MyApp());
/// }
///
/// // In your app:
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       home: Scaffold(
///         body: Column(
///           children: [
///             // Show offline indicator
///             OfflineIndicator(),
///
///             // Your content
///             ScriptList(),
///           ],
///         ),
///       ),
///     );
///   }
/// }
///
/// // Access services anywhere:
/// final database = AppServices.instance.database;
/// final wsClient = AppServices.instance.wsClient;
/// final syncService = AppServices.instance.syncService;
///
/// // Logout:
/// await AppServices.instance.clearAllData();
/// await AppServices.dispose();
/// ```
