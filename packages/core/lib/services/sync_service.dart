// Sync Service for Offline-First Architecture
// Handles synchronization between local database and remote server

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/local_database.dart';
import '../api/api_client.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

class SyncResult {
  final bool success;
  final int itemsSynced;
  final List<String> errors;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    required this.itemsSynced,
    required this.errors,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class SyncService {
  final LocalDatabase database;
  final ApiClient apiClient;
  final Connectivity connectivity;

  SyncStatus _status = SyncStatus.idle;
  final _statusController = StreamController<SyncStatus>.broadcast();

  Timer? _periodicSyncTimer;
  StreamSubscription? _connectivitySubscription;

  bool _isOnline = false;
  DateTime? _lastSyncTime;

  // Configuration
  static const Duration syncInterval = Duration(minutes: 5);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 30);

  SyncService({
    required this.database,
    required this.apiClient,
    Connectivity? connectivity,
  }) : connectivity = connectivity ?? Connectivity() {
    _initConnectivityListener();
  }

  // Getters
  SyncStatus get status => _status;
  Stream<SyncStatus> get statusStream => _statusController.stream;
  bool get isOnline => _isOnline;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _status == SyncStatus.syncing;

  // Initialize
  Future<void> initialize() async {
    await _checkConnectivity();
    _startPeriodicSync();

    // Perform initial sync if online
    if (_isOnline) {
      await syncAll();
    }
  }

  // Start periodic synchronization
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(syncInterval, (_) {
      if (_isOnline && _status != SyncStatus.syncing) {
        syncAll();
      }
    });
  }

  // Initialize connectivity listener
  void _initConnectivityListener() {
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        final wasOffline = !_isOnline;
        _isOnline = result != ConnectivityResult.none;

        if (wasOffline && _isOnline) {
          // Just came online, trigger sync
          await syncAll();
        }
      },
    );
  }

  // Check current connectivity
  Future<void> _checkConnectivity() async {
    final result = await connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
  }

  // Sync all data
  Future<SyncResult> syncAll() async {
    if (!_isOnline) {
      return SyncResult(
        success: false,
        itemsSynced: 0,
        errors: ['Device is offline'],
      );
    }

    if (_status == SyncStatus.syncing) {
      return SyncResult(
        success: false,
        itemsSynced: 0,
        errors: ['Sync already in progress'],
      );
    }

    _updateStatus(SyncStatus.syncing);

    int totalSynced = 0;
    final errors = <String>[];

    try {
      // 1. Process sync queue (pending operations)
      final queueResult = await _processSyncQueue();
      totalSynced += queueResult.itemsSynced;
      errors.addAll(queueResult.errors);

      // 2. Sync scripts
      final scriptsResult = await _syncScripts();
      totalSynced += scriptsResult.itemsSynced;
      errors.addAll(scriptsResult.errors);

      // 3. Sync recordings metadata (actual files sync separately)
      final recordingsResult = await _syncRecordings();
      totalSynced += recordingsResult.itemsSynced;
      errors.addAll(recordingsResult.errors);

      // 4. Pull latest data from server
      await _pullServerData();

      // 5. Cleanup
      await database.clearProcessedSyncItems();
      await database.clearExpiredCache();

      _lastSyncTime = DateTime.now();
      _updateStatus(errors.isEmpty ? SyncStatus.success : SyncStatus.error);

      return SyncResult(
        success: errors.isEmpty,
        itemsSynced: totalSynced,
        errors: errors,
      );
    } catch (e) {
      _updateStatus(SyncStatus.error);
      return SyncResult(
        success: false,
        itemsSynced: totalSynced,
        errors: [...errors, 'Sync failed: $e'],
      );
    }
  }

  // Process sync queue
  Future<SyncResult> _processSyncQueue() async {
    final pendingItems = await database.getPendingSyncItems();
    int synced = 0;
    final errors = <String>[];

    for (final item in pendingItems) {
      try {
        // Check retry count
        if (item.retryCount >= maxRetries) {
          errors.add('Max retries exceeded for ${item.entityType}:${item.entityId}');
          await database.markSyncItemAsProcessed(item.id);
          continue;
        }

        // Process based on entity type and operation
        final payload = jsonDecode(item.payload);

        switch (item.entityType) {
          case 'script':
            await _syncQueueScript(item.operation, item.entityId, payload);
            break;
          case 'recording':
            await _syncQueueRecording(item.operation, item.entityId, payload);
            break;
          default:
            errors.add('Unknown entity type: ${item.entityType}');
        }

        await database.markSyncItemAsProcessed(item.id);
        synced++;
      } catch (e) {
        errors.add('Failed to process queue item ${item.id}: $e');
        await database.incrementSyncRetry(item.id);
      }
    }

    return SyncResult(
      success: errors.isEmpty,
      itemsSynced: synced,
      errors: errors,
    );
  }

  // Sync scripts to server
  Future<SyncResult> _syncScripts() async {
    final unsyncedScripts = await database.getUnsyncedScripts();
    int synced = 0;
    final errors = <String>[];

    for (final script in unsyncedScripts) {
      try {
        if (script.isDeleted) {
          // Delete on server
          await apiClient.delete('/api/scripts/${script.id}');
        } else {
          // Check if exists on server
          final checkResponse = await apiClient.get('/api/scripts/${script.id}');

          if (checkResponse.isSuccess) {
            // Update existing
            await apiClient.put('/api/scripts/${script.id}', body: {
              'title': script.title,
              'content': script.content,
              'richContent': script.richContent,
              'category': script.category,
              'tags': script.tags != null ? jsonDecode(script.tags!) : null,
            });
          } else {
            // Create new
            await apiClient.post('/api/scripts', body: {
              'id': script.id,
              'title': script.title,
              'content': script.content,
              'richContent': script.richContent,
              'category': script.category,
              'tags': script.tags != null ? jsonDecode(script.tags!) : null,
            });
          }
        }

        await database.markScriptAsSynced(script.id);
        synced++;
      } catch (e) {
        errors.add('Failed to sync script ${script.id}: $e');
      }
    }

    return SyncResult(
      success: errors.isEmpty,
      itemsSynced: synced,
      errors: errors,
    );
  }

  // Sync recordings to server
  Future<SyncResult> _syncRecordings() async {
    final unsyncedRecordings = await database.getUnsyncedRecordings();
    int synced = 0;
    final errors = <String>[];

    for (final recording in unsyncedRecordings) {
      try {
        // Sync metadata only (actual file upload is separate)
        await apiClient.post('/api/recordings/metadata', body: {
          'id': recording.id,
          'title': recording.title,
          'scriptId': recording.scriptId,
          'duration': recording.duration,
          'fileSize': recording.fileSize,
        });

        await database.updateRecording(
          recording.id,
          RecordingsCompanion(isSynced: const Value(true)),
        );
        synced++;
      } catch (e) {
        errors.add('Failed to sync recording ${recording.id}: $e');
      }
    }

    return SyncResult(
      success: errors.isEmpty,
      itemsSynced: synced,
      errors: errors,
    );
  }

  // Pull latest data from server
  Future<void> _pullServerData() async {
    try {
      // Pull scripts
      final scriptsResponse = await apiClient.get('/api/scripts');
      if (scriptsResponse.isSuccess) {
        final serverScripts = scriptsResponse.data as List;

        for (final scriptData in serverScripts) {
          final script = scriptData as Map<String, dynamic>;

          // Check if exists locally
          final localScript = await database.getScriptById(script['id']);

          if (localScript == null ||
              DateTime.parse(script['updatedAt'])
                  .isAfter(localScript.updatedAt)) {
            // Insert or update
            await database.insertScript(
              ScriptsCompanion.insert(
                id: script['id'],
                title: script['title'],
                content: script['content'],
                richContent: Value(script['richContent']),
                category: Value(script['category']),
                tags: Value(
                  script['tags'] != null ? jsonEncode(script['tags']) : null,
                ),
                wordCount: script['wordCount'] ?? 0,
                estimatedDuration: script['estimatedDuration'] ?? 0,
                createdAt: DateTime.parse(script['createdAt']),
                updatedAt: DateTime.parse(script['updatedAt']),
                isSynced: const Value(true),
                userId: script['userId'],
              ),
            );
          }
        }
      }

      // Pull recordings metadata
      final recordingsResponse = await apiClient.get('/api/recordings');
      if (recordingsResponse.isSuccess) {
        final serverRecordings = recordingsResponse.data as List;

        for (final recordingData in serverRecordings) {
          final recording = recordingData as Map<String, dynamic>;

          await database.insertRecording(
            RecordingsCompanion.insert(
              id: recording['id'],
              title: recording['title'],
              scriptId: Value(recording['scriptId']),
              duration: recording['duration'],
              fileSize: recording['fileSize'],
              cloudUrl: Value(recording['url']),
              thumbnailUrl: Value(recording['thumbnailUrl']),
              status: recording['status'] ?? 'uploaded',
              createdAt: DateTime.parse(recording['createdAt']),
              isSynced: const Value(true),
              userId: recording['userId'],
            ),
          );
        }
      }
    } catch (e) {
      print('Error pulling server data: $e');
    }
  }

  // Helper: Sync queue operations
  Future<void> _syncQueueScript(
    String operation,
    String scriptId,
    Map<String, dynamic> payload,
  ) async {
    switch (operation) {
      case 'create':
        await apiClient.post('/api/scripts', body: payload);
        break;
      case 'update':
        await apiClient.put('/api/scripts/$scriptId', body: payload);
        break;
      case 'delete':
        await apiClient.delete('/api/scripts/$scriptId');
        break;
    }
  }

  Future<void> _syncQueueRecording(
    String operation,
    String recordingId,
    Map<String, dynamic> payload,
  ) async {
    switch (operation) {
      case 'create':
        await apiClient.post('/api/recordings', body: payload);
        break;
      case 'update':
        await apiClient.put('/api/recordings/$recordingId', body: payload);
        break;
      case 'delete':
        await apiClient.delete('/api/recordings/$recordingId');
        break;
    }
  }

  // Queue operation for later sync
  Future<void> queueOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await database.addToSyncQueue(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: jsonEncode(payload),
        createdAt: DateTime.now(),
      ),
    );

    // Try to sync immediately if online
    if (_isOnline && _status != SyncStatus.syncing) {
      syncAll();
    }
  }

  // Force sync now
  Future<SyncResult> forceSyncNow() async {
    await _checkConnectivity();
    return await syncAll();
  }

  // Update status
  void _updateStatus(SyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
    }
  }

  // Dispose
  void dispose() {
    _periodicSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}

// Singleton instance management
class SyncServiceManager {
  static SyncService? _instance;

  static Future<SyncService> getInstance({
    required LocalDatabase database,
    required ApiClient apiClient,
  }) async {
    if (_instance == null) {
      _instance = SyncService(
        database: database,
        apiClient: apiClient,
      );
      await _instance!.initialize();
    }
    return _instance!;
  }

  static SyncService? get instance => _instance;

  static void dispose() {
    _instance?.dispose();
    _instance = null;
  }
}
