// packages/platform_bridge/lib/platform_bridge.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Platform detection and routing
enum PlatformType {
  windows,
  macos,
  linux,
  android,
  ios,
  web,
  unknown,
}

class PlatformBridge {
  static final PlatformBridge _instance = PlatformBridge._internal();
  factory PlatformBridge() => _instance;
  PlatformBridge._internal();

  // Platform channels for native communication
  static const MethodChannel _channel = MethodChannel('teleprompt_pro/platform');
  static const EventChannel _eventChannel = EventChannel('teleprompt_pro/events');
  
  // Named pipe for Windows system tray communication
  StreamController<String>? _pipeController;
  Stream<String>? _pipeStream;
  
  PlatformType get currentPlatform {
    if (kIsWeb) return PlatformType.web;
    if (Platform.isWindows) return PlatformType.windows;
    if (Platform.isMacOS) return PlatformType.macos;
    if (Platform.isLinux) return PlatformType.linux;
    if (Platform.isIOS) return PlatformType.ios;
    if (Platform.isAndroid) return PlatformType.android;
    return PlatformType.unknown;
  }

  Future<void> initialize() async {
    switch (currentPlatform) {
      case PlatformType.windows:
        await _initializeWindows();
        break;
      case PlatformType.macos:
        await _initializeMacOS();
        break;
      case PlatformType.linux:
        await _initializeLinux();
        break;
      case PlatformType.android:
        await _initializeAndroid();
        break;
      case PlatformType.ios:
        await _initializeIOS();
        break;
      case PlatformType.web:
        await _initializeWeb();
        break;
      default:
        break;
    }
    
    // Set up method call handler
    _channel.setMethodCallHandler(_handleMethodCall);
    
    // Listen to native events
    _eventChannel.receiveBroadcastStream().listen(_handleNativeEvent);
  }

  // ============================================
  // Windows Platform
  // ============================================
  
  Future<void> _initializeWindows() async {
    // Connect to system tray via named pipe
    await _connectToSystemTray();
    
    // Register for Windows-specific features
    await _channel.invokeMethod('registerHotkeys');
    await _channel.invokeMethod('enableSystemTray');
    
    // Set up auto-start if enabled
    final autoStart = await getPreference('autoStart') ?? false;
    if (autoStart) {
      await _channel.invokeMethod('setAutoStart', {'enabled': true});
    }
  }

  Future<void> _connectToSystemTray() async {
    try {
      _pipeController = StreamController<String>.broadcast();
      
      // Create named pipe client
      final pipe = await _channel.invokeMethod<String>('connectToPipe', {
        'pipeName': 'TelePromptProPipe',
      });
      
      if (pipe != null) {
        _pipeStream = _pipeController!.stream;
        print('Connected to system tray');
      }
    } catch (e) {
      print('Failed to connect to system tray: $e');
    }
  }

  Future<void> sendToSystemTray(String command, [Map<String, dynamic>? data]) async {
    if (currentPlatform != PlatformType.windows) return;
    
    await _channel.invokeMethod('sendToPipe', {
      'command': command,
      'data': data,
    });
  }

  Future<void> minimizeToTray() async {
    if (currentPlatform == PlatformType.windows) {
      await _channel.invokeMethod('minimizeToTray');
    }
  }

  // ============================================
  // macOS Platform
  // ============================================
  
  Future<void> _initializeMacOS() async {
    // Set up menu bar
    await _channel.invokeMethod('setupMenuBar');
    
    // Register for macOS-specific features
    await _channel.invokeMethod('registerGlobalShortcuts');
    
    // Enable dock features
    await _channel.invokeMethod('configureDock', {
      'badge': '',
      'menu': ['New Script', 'Quick Record', 'Settings'],
    });
  }

  Future<void> setDockBadge(String badge) async {
    if (currentPlatform == PlatformType.macos) {
      await _channel.invokeMethod('setDockBadge', {'badge': badge});
    }
  }

  // ============================================
  // Linux Platform
  // ============================================
  
  Future<void> _initializeLinux() async {
    // Set up app indicator (system tray for Linux)
    await _channel.invokeMethod('setupAppIndicator');
    
    // Register D-Bus service
    await _channel.invokeMethod('registerDBusService');
  }

  // ============================================
  // Android Platform
  // ============================================
  
  Future<void> _initializeAndroid() async {
    // Set up Android-specific features
    await _channel.invokeMethod('setupAndroidFeatures', {
      'enablePictureInPicture': true,
      'enableBackgroundService': true,
      'enableWidget': true,
    });
    
    // Request necessary permissions
    await requestAndroidPermissions();
  }

  Future<void> requestAndroidPermissions() async {
    final permissions = [
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.SYSTEM_ALERT_WINDOW',
    ];
    
    for (final permission in permissions) {
      await _channel.invokeMethod('requestPermission', {'permission': permission});
    }
  }

  Future<void> startForegroundService() async {
    if (currentPlatform == PlatformType.android) {
      await _channel.invokeMethod('startForegroundService', {
        'title': 'TelePrompt Pro',
        'message': 'Running in background',
      });
    }
  }

  Future<void> enterPictureInPicture() async {
    if (currentPlatform == PlatformType.android) {
      await _channel.invokeMethod('enterPIP');
    }
  }

  // ============================================
  // iOS Platform
  // ============================================
  
  Future<void> _initializeIOS() async {
    // Set up iOS-specific features
    await _channel.invokeMethod('setupIOSFeatures', {
      'enableSiriShortcuts': true,
      'enableWidget': true,
      'enableLiveActivity': true,
      'enableShareExtension': true,
    });
    
    // Register for push notifications
    await _channel.invokeMethod('registerForPushNotifications');
    
    // Set up iCloud sync
    await _channel.invokeMethod('setupiCloudSync');
  }

  Future<void> addSiriShortcut(String action, String phrase) async {
    if (currentPlatform == PlatformType.ios) {
      await _channel.invokeMethod('addSiriShortcut', {
        'action': action,
        'phrase': phrase,
      });
    }
  }

  Future<void> startLiveActivity(Map<String, dynamic> data) async {
    if (currentPlatform == PlatformType.ios) {
      await _channel.invokeMethod('startLiveActivity', data);
    }
  }

  // ============================================
  // Web Platform
  // ============================================
  
  Future<void> _initializeWeb() async {
    // Initialize PWA features via JavaScript interop
    await _setupWebFeatures();
  }

  Future<void> _setupWebFeatures() async {
    // This would use dart:html or package:web for web-specific features
    // Simplified for example
    await _channel.invokeMethod('setupPWA');
  }

  // ============================================
  // Cross-Platform Features
  // ============================================
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHotkeyPressed':
        _handleHotkey(call.arguments['hotkey']);
        break;
      case 'onSystemTrayAction':
        _handleSystemTrayAction(call.arguments['action']);
        break;
      case 'onDeepLink':
        _handleDeepLink(call.arguments['url']);
        break;
      case 'onShareReceived':
        _handleShareReceived(call.arguments);
        break;
      case 'onNotificationTapped':
        _handleNotificationTapped(call.arguments);
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Platform method ${call.method} not implemented',
        );
    }
  }

  void _handleNativeEvent(dynamic event) {
    print('Native event received: $event');
    
    if (event is Map) {
      switch (event['type']) {
        case 'sync':
          _handleSyncEvent(event['data']);
          break;
        case 'recording':
          _handleRecordingEvent(event['data']);
          break;
        case 'update':
          _handleUpdateEvent(event['data']);
          break;
      }
    }
  }

  void _handleHotkey(String hotkey) {
    print('Hotkey pressed: $hotkey');
    // Dispatch to appropriate handler
  }

  void _handleSystemTrayAction(String action) {
    print('System tray action: $action');
    // Handle system tray actions
  }

  void _handleDeepLink(String url) {
    print('Deep link: $url');
    // Handle deep link navigation
  }

  void _handleShareReceived(Map<String, dynamic> data) {
    print('Share received: $data');
    // Handle shared content
  }

  void _handleNotificationTapped(Map<String, dynamic> data) {
    print('Notification tapped: $data');
    // Handle notification navigation
  }

  void _handleSyncEvent(Map<String, dynamic> data) {
    // Handle sync events
  }

  void _handleRecordingEvent(Map<String, dynamic> data) {
    // Handle recording events
  }

  void _handleUpdateEvent(Map<String, dynamic> data) {
    // Handle update events
  }

  // ============================================
  // Storage & Preferences
  // ============================================
  
  Future<dynamic> getPreference(String key) async {
    return await _channel.invokeMethod('getPreference', {'key': key});
  }

  Future<void> setPreference(String key, dynamic value) async {
    await _channel.invokeMethod('setPreference', {
      'key': key,
      'value': value,
    });
  }

  // ============================================
  // File System
  // ============================================
  
  Future<String> getDocumentsDirectory() async {
    return await _channel.invokeMethod('getDocumentsDirectory');
  }

  Future<String> getTemporaryDirectory() async {
    return await _channel.invokeMethod('getTemporaryDirectory');
  }

  Future<String> getDownloadsDirectory() async {
    return await _channel.invokeMethod('getDownloadsDirectory');
  }

  Future<String?> pickFile({
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    return await _channel.invokeMethod('pickFile', {
      'allowedExtensions': allowedExtensions,
      'allowMultiple': allowMultiple,
    });
  }

  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
  }) async {
    return await _channel.invokeMethod('saveFile', {
      'fileName': fileName,
      'bytes': bytes,
      'dialogTitle': dialogTitle,
    });
  }

  // ============================================
  // Clipboard
  // ============================================
  
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<String?> pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    return data?.text;
  }

  // ============================================
  // Share
  // ============================================
  
  Future<void> share({
    String? text,
    String? subject,
    List<String>? files,
  }) async {
    await _channel.invokeMethod('share', {
      'text': text,
      'subject': subject,
      'files': files,
    });
  }

  // ============================================
  // URL Launcher
  // ============================================
  
  Future<void> openUrl(String url) async {
    await _channel.invokeMethod('openUrl', {'url': url});
  }

  Future<void> openEmail(String email, {String? subject, String? body}) async {
    final uri = 'mailto:$email?subject=${subject ?? ''}&body=${body ?? ''}';
    await openUrl(uri);
  }

  // ============================================
  // App Info
  // ============================================
  
  Future<Map<String, dynamic>> getAppInfo() async {
    return await _channel.invokeMethod('getAppInfo');
  }

  Future<String> getAppVersion() async {
    final info = await getAppInfo();
    return info['version'] ?? 'Unknown';
  }

  // ============================================
  // Device Info
  // ============================================
  
  Future<Map<String, dynamic>> getDeviceInfo() async {
    return await _channel.invokeMethod('getDeviceInfo');
  }

  Future<bool> isTablet() async {
    final info = await getDeviceInfo();
    return info['isTablet'] ?? false;
  }

  Future<bool> isPhysicalDevice() async {
    final info = await getDeviceInfo();
    return info['isPhysicalDevice'] ?? true;
  }

  void dispose() {
    _pipeController?.close();
  }
}