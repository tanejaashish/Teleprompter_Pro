// WebSocket Client for Real-Time Features
// Handles real-time collaboration, notifications, and voice scrolling

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

enum WebSocketState {
  connecting,
  connected,
  disconnected,
  reconnecting,
  error,
}

enum MessageType {
  // Collaboration
  joinScript,
  leaveScript,
  operation,
  cursorUpdate,
  userJoined,
  userLeft,

  // Voice Scrolling
  voiceScrollStart,
  voiceScrollUpdate,
  voiceScrollStop,

  // Notifications
  notification,

  // System
  ping,
  pong,
  error,
}

class WebSocketMessage {
  final MessageType type;
  final Map<String, dynamic> data;
  final String? id;
  final DateTime timestamp;

  WebSocketMessage({
    required this.type,
    required this.data,
    this.id,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.toString().split('.').last,
        'data': data,
        'id': id,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = MessageType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => MessageType.error,
    );

    return WebSocketMessage(
      type: type,
      data: json['data'] as Map<String, dynamic>,
      id: json['id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class WebSocketClient {
  final String baseUrl;
  final String accessToken;

  WebSocketChannel? _channel;
  WebSocketState _state = WebSocketState.disconnected;

  final _stateController = StreamController<WebSocketState>.broadcast();
  final _messageController = StreamController<WebSocketMessage>.broadcast();

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const Duration pingInterval = Duration(seconds: 30);

  // Event handlers by message type
  final Map<MessageType, List<Function(WebSocketMessage)>> _handlers = {};

  WebSocketClient({
    required this.baseUrl,
    required this.accessToken,
  });

  // Getters
  WebSocketState get state => _state;
  Stream<WebSocketState> get stateStream => _stateController.stream;
  Stream<WebSocketMessage> get messageStream => _messageController.stream;
  bool get isConnected => _state == WebSocketState.connected;

  // Connect to WebSocket server
  Future<void> connect() async {
    if (_state == WebSocketState.connected || _state == WebSocketState.connecting) {
      return;
    }

    _updateState(WebSocketState.connecting);

    try {
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/ws?token=$accessToken');

      _channel = IOWebSocketChannel.connect(uri);

      await _channel!.ready;
      _updateState(WebSocketState.connected);
      _reconnectAttempts = 0;

      // Start listening to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      // Start ping timer
      _startPingTimer();
    } catch (e) {
      _updateState(WebSocketState.error);
      _scheduleReconnect();
    }
  }

  // Disconnect from WebSocket server
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _updateState(WebSocketState.disconnected);
  }

  // Send message
  void send(WebSocketMessage message) {
    if (!isConnected) {
      throw StateError('WebSocket is not connected');
    }

    final json = jsonEncode(message.toJson());
    _channel!.sink.add(json);
  }

  // Register handler for specific message type
  void on(MessageType type, Function(WebSocketMessage) handler) {
    if (!_handlers.containsKey(type)) {
      _handlers[type] = [];
    }
    _handlers[type]!.add(handler);
  }

  // Remove handler
  void off(MessageType type, Function(WebSocketMessage) handler) {
    _handlers[type]?.remove(handler);
  }

  // Collaboration methods
  void joinScript(String scriptId) {
    send(WebSocketMessage(
      type: MessageType.joinScript,
      data: {'scriptId': scriptId},
    ));
  }

  void leaveScript(String scriptId) {
    send(WebSocketMessage(
      type: MessageType.leaveScript,
      data: {'scriptId': scriptId},
    ));
  }

  void sendOperation(String scriptId, Map<String, dynamic> operation) {
    send(WebSocketMessage(
      type: MessageType.operation,
      data: {
        'scriptId': scriptId,
        'operation': operation,
      },
    ));
  }

  void updateCursor(String scriptId, int position, {int? selectionStart, int? selectionEnd}) {
    send(WebSocketMessage(
      type: MessageType.cursorUpdate,
      data: {
        'scriptId': scriptId,
        'position': position,
        if (selectionStart != null) 'selectionStart': selectionStart,
        if (selectionEnd != null) 'selectionEnd': selectionEnd,
      },
    ));
  }

  // Voice scrolling methods
  void startVoiceScrolling(String scriptId, String scriptContent) {
    send(WebSocketMessage(
      type: MessageType.voiceScrollStart,
      data: {
        'scriptId': scriptId,
        'scriptContent': scriptContent,
      },
    ));
  }

  void sendVoiceUpdate(List<int> audioChunk) {
    send(WebSocketMessage(
      type: MessageType.voiceScrollUpdate,
      data: {
        'audioChunk': base64Encode(audioChunk),
      },
    ));
  }

  void stopVoiceScrolling() {
    send(WebSocketMessage(
      type: MessageType.voiceScrollStop,
      data: {},
    ));
  }

  // Private methods
  void _handleMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final wsMessage = WebSocketMessage.fromJson(json);

      // Add to message stream
      _messageController.add(wsMessage);

      // Handle pong
      if (wsMessage.type == MessageType.pong) {
        // Server is alive
        return;
      }

      // Call registered handlers
      final handlers = _handlers[wsMessage.type];
      if (handlers != null) {
        for (final handler in handlers) {
          handler(wsMessage);
        }
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _updateState(WebSocketState.error);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    print('WebSocket disconnected');
    _updateState(WebSocketState.disconnected);
    _pingTimer?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('Max reconnect attempts reached');
      return;
    }

    _reconnectAttempts++;
    _updateState(WebSocketState.reconnecting);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      reconnectDelay * _reconnectAttempts,
      () => connect(),
    );
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (isConnected) {
        send(WebSocketMessage(
          type: MessageType.ping,
          data: {},
        ));
      }
    });
  }

  void _updateState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  // Cleanup
  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _stateController.close();
    _messageController.close();
    disconnect();
  }
}

// Singleton instance management
class WebSocketManager {
  static WebSocketClient? _instance;

  static WebSocketClient getInstance({
    required String baseUrl,
    required String accessToken,
  }) {
    _instance ??= WebSocketClient(
      baseUrl: baseUrl,
      accessToken: accessToken,
    );
    return _instance!;
  }

  static void dispose() {
    _instance?.dispose();
    _instance = null;
  }

  static WebSocketClient? get instance => _instance;
}
