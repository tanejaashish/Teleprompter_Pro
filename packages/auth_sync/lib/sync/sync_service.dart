// ============================================
// packages/auth_sync/lib/sync/sync_service.dart
// ============================================

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

// Sync Models
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int pendingChanges;
  final String? error;
  final double progress;

  SyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.pendingChanges = 0,
    this.error,
    this.progress = 0.0,
  });

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
    isSyncing: json['isSyncing'] ?? false,
    lastSyncTime: json['lastSyncTime'] != null 
      ? DateTime.parse(json['lastSyncTime']) 
      : null,
    pendingChanges: json['pendingChanges'] ?? 0,
    error: json['error'],
    progress: json['progress']?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'isSyncing': isSyncing,
    'lastSyncTime': lastSyncTime?.toIso8601String(),
    'pendingChanges': pendingChanges,
    'error': error,
    'progress': progress,
  };
}

class SyncOperation {
  final String id;
  final String type; // create, update, delete
  final String entityType; // script, recording, settings
  final String entityId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'],
    type: json['type'],
    entityType: json['entityType'],
    entityId: json['entityId'],
    data: json['data'],
    timestamp: DateTime.parse(json['timestamp']),
    retryCount: json['retryCount'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'entityType': entityType,
    'entityId': entityId,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };
}

// Main Sync Service
class SyncService {
  static const String _wsUrl = 'wss://sync.teleprompt.pro/v1';
  static const String _syncBoxName = 'sync_queue';
  static const int _maxRetries = 3;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  
  final AuthService _authService;
  final Connectivity _connectivity;
  
  WebSocketChannel? _channel;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _messageSubscription;
  
  late Box<String> _syncBox;
  final _syncStateController = StreamController<SyncState>.broadcast();
  final _syncQueue = <SyncOperation>[];
  
  Timer? _reconnectTimer;
  Timer? _syncTimer;
  bool _isConnected = false;
  SyncState _currentState = SyncState();
  
  Stream<SyncState> get syncState => _syncStateController.stream;
  bool get isConnected => _isConnected;
  
  SyncService({required AuthService authService})
    : _authService = authService,
      _connectivity = Connectivity() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize local storage
    _syncBox = await Hive.openBox<String>(_syncBoxName);
    
    // Load pending operations
    await _loadPendingOperations();
    
    // Monitor connectivity
    _connectivitySubscription = _connectivity.onConnectivityChanged
      .listen(_handleConnectivityChange);
    
    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await connect();
    }
    
    // Start sync timer
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _processSyncQueue();
    });
  }

  Future<void> connect() async {
    if (_isConnected || _authService.currentUser == null) return;
    
    try {
      final session = await _authService.authenticatedRequest(
        path: '/sync/token',
        method: 'GET',
        parser: (data) => data['token'] as String,
      );
      
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsUrl?token=$session'),
      );
      
      _messageSubscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      _isConnected = true;
      _sendMessage({
        'type': 'connect',
        'deviceId': await _getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _updateSyncState(isSyncing: false, error: null);
      
      // Process pending operations
      await _processSyncQueue();
      
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      
      switch (type) {
        case 'sync':
          _handleSyncMessage(data);
          break;
        case 'conflict':
          _handleConflict(data);
          break;
        case 'ack':
          _handleAcknowledgement(data);
          break;
        case 'error':
          _handleServerError(data);
          break;
        case 'ping':
          _sendMessage({'type': 'pong'});
          break;
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  void _handleSyncMessage(Map<String, dynamic> data) {
    final operation = SyncOperation.fromJson(data['operation']);
    
    // Apply remote change locally
    _applyRemoteOperation(operation);
    
    // Send acknowledgement
    _sendMessage({
      'type': 'ack',
      'operationId': operation.id,
    });
  }

  void _handleConflict(Map<String, dynamic> data) {
    final local = SyncOperation.fromJson(data['local']);
    final remote = SyncOperation.fromJson(data['remote']);
    
    // Resolve conflict (last-write-wins by default)
    final resolved = _resolveConflict(local, remote);
    
    _sendMessage({
      'type': 'resolve',
      'conflictId': data['conflictId'],
      'resolution': resolved.toJson(),
    });
  }

  void _handleAcknowledgement(Map<String, dynamic> data) {
    final operationId = data['operationId'];
    
    // Remove from queue
    _syncQueue.removeWhere((op) => op.id == operationId);
    _syncBox.delete(operationId);
    
    _updateSyncState(pendingChanges: _syncQueue.length);
  }

  void _handleServerError(Map<String, dynamic> data) {
    final error = data['error'] ?? 'Unknown server error';
    _updateSyncState(error: error);
  }

  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _isConnected = false;
    _updateSyncState(error: error.toString());
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _updateSyncState(error: 'Disconnected from sync server');
    _scheduleReconnect();
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (result != ConnectivityResult.none && !_isConnected) {
      connect();
    } else if (result == ConnectivityResult.none && _isConnected) {
      disconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, connect);
  }

  // Sync Operations
  Future<void> syncScript(Script script, String operationType) async {
    final operation = SyncOperation(
      id: _generateOperationId(),
      type: operationType,
      entityType: 'script',
      entityId: script.id,
      data: script.toJson(),
      timestamp: DateTime.now(),
    );
    
    await _queueOperation(operation);
  }

  Future<void> syncRecording(Recording recording, String operationType) async {
    final operation = SyncOperation(
      id: _generateOperationId(),
      type: operationType,
      entityType: 'recording',
      entityId: recording.id,
      data: recording.toJson(),
      timestamp: DateTime.now(),
    );
    
    await _queueOperation(operation);
  }

  Future<void> syncSettings(Map<String, dynamic> settings) async {
    final operation = SyncOperation(
      id: _generateOperationId(),
      type: 'update',
      entityType: 'settings',
      entityId: 'user_settings',
      data: settings,
      timestamp: DateTime.now(),
    );
    
    await _queueOperation(operation);
  }

  Future<void> _queueOperation(SyncOperation operation) async {
    // Add to queue
    _syncQueue.add(operation);
    
    // Persist to local storage
    await _syncBox.put(operation.id, jsonEncode(operation.toJson()));
    
    _updateSyncState(pendingChanges: _syncQueue.length);
    
    // Try to sync immediately if connected
    if (_isConnected) {
      _processSyncQueue();
    }
  }

  Future<void> _processSyncQueue() async {
    if (!_isConnected || _syncQueue.isEmpty) return;
    
    _updateSyncState(isSyncing: true);
    
    final operations = List<SyncOperation>.from(_syncQueue);
    
    for (var i = 0; i < operations.length; i++) {
      final operation = operations[i];
      _updateSyncState(progress: (i + 1) / operations.length);
      
      try {
        _sendMessage({
          'type': 'sync',
          'operation': operation.toJson(),
        });
        
        // Wait for acknowledgement (with timeout)
        await Future.delayed(const Duration(seconds: 2));
        
      } catch (e) {
        // Retry logic
        if (operation.retryCount < _maxRetries) {
          final updatedOp = SyncOperation(
            id: operation.id,
            type: operation.type,
            entityType: operation.entityType,
            entityId: operation.entityId,
            data: operation.data,
            timestamp: operation.timestamp,
            retryCount: operation.retryCount + 1,
          );
          
          final index = _syncQueue.indexWhere((op) => op.id == operation.id);
          if (index != -1) {
            _syncQueue[index] = updatedOp;
          }
        } else {
          // Max retries reached, remove from queue
          _syncQueue.removeWhere((op) => op.id == operation.id);
          _syncBox.delete(operation.id);
        }
      }
    }
    
    _updateSyncState(
      isSyncing: false,
      lastSyncTime: DateTime.now(),
      pendingChanges: _syncQueue.length,
    );
  }

  Future<void> _loadPendingOperations() async {
    final keys = _syncBox.keys;
    
    for (final key in keys) {
      final data = _syncBox.get(key);
      if (data != null) {
        try {
          final operation = SyncOperation.fromJson(jsonDecode(data));
          _syncQueue.add(operation);
        } catch (e) {
          // Invalid operation, remove
          _syncBox.delete(key);
        }
      }
    }
    
    _updateSyncState(pendingChanges: _syncQueue.length);
  }

  void _applyRemoteOperation(SyncOperation operation) {
    // Apply remote changes to local database
    // This would integrate with your local storage
    
    switch (operation.entityType) {
      case 'script':
        // Update local script
        break;
      case 'recording':
        // Update local recording
        break;
      case 'settings':
        // Update local settings
        break;
    }
  }

  SyncOperation _resolveConflict(SyncOperation local, SyncOperation remote) {
    // Simple last-write-wins strategy
    // Can be enhanced with more sophisticated resolution
    
    if (local.timestamp.isAfter(remote.timestamp)) {
      return local;
    } else {
      return remote;
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void _updateSyncState({
    bool? isSyncing,
    DateTime? lastSyncTime,
    int? pendingChanges,
    String? error,
    double? progress,
  }) {
    _currentState = SyncState(
      isSyncing: isSyncing ?? _currentState.isSyncing,
      lastSyncTime: lastSyncTime ?? _currentState.lastSyncTime,
      pendingChanges: pendingChanges ?? _currentState.pendingChanges,
      error: error,
      progress: progress ?? _currentState.progress,
    );
    
    _syncStateController.add(_currentState);
  }

  String _generateOperationId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_authService.currentUser?.id}';
  }

  Future<String> _getDeviceId() async {
    // Implementation depends on platform
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _messageSubscription?.cancel();
    _reconnectTimer?.cancel();
  }

  void dispose() {
    disconnect();
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _syncStateController.close();
    _syncBox.close();
  }
}