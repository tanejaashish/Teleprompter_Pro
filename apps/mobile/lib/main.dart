// apps/mobile/lib/main_mobile.dart

import 'package:flutter/material.dart';
import 'dart:async';  // ADD THIS LINE
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';

// Mobile-specific services
class MobilePlatformService {
  static final MobilePlatformService _instance = MobilePlatformService._internal();
  factory MobilePlatformService() => _instance;
  MobilePlatformService._internal();

  late List<CameraDescription> cameras;
  CameraController? _cameraController;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  // Biometric authentication
  bool _biometricAvailable = false;
  
  Future<void> initialize() async {
    await _initializeFirebase();
    await _initializeCameras();
    await _initializeNotifications();
    await _checkBiometricAvailability();
    await _setupInAppPurchases();
    await _requestPermissions();
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    
    // Configure FCM
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    // Get FCM token
    final token = await _messaging.getToken();
    print('FCM Token: $token');
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'recording',
        'Recording',
        description: 'Notifications for recording status',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'sync',
        'Sync',
        description: 'Notifications for sync status',
        importance: Importance.low,
      ),
      AndroidNotificationChannel(
        'updates',
        'Updates',
        description: 'App updates and announcements',
        importance: Importance.defaultImportance,
      ),
    ];
    
    for (final channel in channels) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final localAuth = LocalAuthentication();
      _biometricAvailable = await localAuth.canCheckBiometrics;
      
      if (_biometricAvailable) {
        final availableBiometrics = await localAuth.getAvailableBiometrics();
        print('Available biometrics: $availableBiometrics');
      }
    } catch (e) {
      print('Biometric check failed: $e');
    }
  }

  Future<void> _setupInAppPurchases() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      print('In-app purchases not available');
      return;
    }
    
    // Load products
    const productIds = <String>{
      'creator_monthly',
      'creator_yearly',
      'professional_monthly',
      'professional_yearly',
      'enterprise_monthly',
    };
    
    final response = await InAppPurchase.instance.queryProductDetails(productIds);
    if (response.error != null) {
      print('Error loading products: ${response.error}');
      return;
    }
    
    // Listen to purchase updates
    InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: (error) => print('Purchase stream error: $error'),
    );
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.notification,
    ];
    
    if (Platform.isIOS) {
      permissions.add(Permission.photos);
      permissions.add(Permission.mediaLibrary);
    }
    
    final statuses = await permissions.request();
    
    for (final entry in statuses.entries) {
      if (!entry.value.isGranted) {
        print('Permission ${entry.key} not granted: ${entry.value}');
      }
    }
  }

  // Camera Service
  Future<void> startCamera({
    CameraLensDirection direction = CameraLensDirection.back,
    ResolutionPreset resolution = ResolutionPreset.high,
  }) async {
    if (cameras.isEmpty) {
      throw Exception('No cameras available');
    }
    
    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == direction,
      orElse: () => cameras.first,
    );
    
    _cameraController = CameraController(
      camera,
      resolution,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    
    await _cameraController!.initialize();
    await _cameraController!.prepareForVideoRecording();
  }

  Future<String> startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    
    await _cameraController!.startVideoRecording();
    
    // Show recording notification
    await _showRecordingNotification();
    
    return 'Recording started';
  }

  Future<XFile> stopRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) {
      throw Exception('Not recording');
    }
    
    final file = await _cameraController!.stopVideoRecording();
    
    // Cancel recording notification
    await _notifications.cancel(1);
    
    // Show completion notification
    await _showNotification(
      title: 'Recording Complete',
      body: 'Your video has been saved',
      channelId: 'recording',
    );
    
    return file;
  }

  Future<void> _showRecordingNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'recording',
      'Recording',
      channelDescription: 'Recording in progress',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      indeterminate: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      1,
      'Recording',
      'TelePrompt Pro is recording',
      details,
    );
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required String channelId,
    Map<String, dynamic>? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload?.toString(),
    );
  }

  // Biometric Authentication
  Future<bool> authenticateWithBiometrics() async {
    if (!_biometricAvailable) {
      return false;
    }
    
    try {
      final localAuth = LocalAuthentication();
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to access TelePrompt Pro',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      return authenticated;
    } catch (e) {
      print('Biometric authentication failed: $e');
      return false;
    }
  }

  // In-App Purchase handlers
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        // Verify and deliver the purchase
        _verifyAndDeliverPurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        // Handle error
        print('Purchase error: ${purchase.error}');
      }
      
      // Complete the purchase
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchase) async {
    // Verify purchase with backend
    // Update user subscription status
    print('Purchase verified: ${purchase.productID}');
  }

  // Device Info
  Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> info = {};
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      info = {
        'platform': 'android',
        'model': androidInfo.model,
        'version': androidInfo.version.release,
        'manufacturer': androidInfo.manufacturer,
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
        'deviceId': androidInfo.id,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      info = {
        'platform': 'ios',
        'model': iosInfo.model,
        'version': iosInfo.systemVersion,
        'name': iosInfo.name,
        'isPhysicalDevice': iosInfo.isPhysicalDevice,
        'deviceId': iosInfo.identifierForVendor,
      };
    }
    
    return info;
  }

  void dispose() {
    _cameraController?.dispose();
  }
}

// Background message handler
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
  
  // Process background message
  if (message.data['type'] == 'sync') {
    // Trigger background sync
  } else if (message.data['type'] == 'update') {
    // Handle app update
  }
}

void _handleForegroundMessage(RemoteMessage message) {
  print('Foreground message: ${message.messageId}');
  
  // Show local notification
  MobilePlatformService()._showNotification(
    title: message.notification?.title ?? 'TelePrompt Pro',
    body: message.notification?.body ?? '',
    channelId: 'updates',
    payload: message.data,
  );
}

void _handleNotificationTap(RemoteMessage message) {
  print('Notification tapped: ${message.messageId}');
  
  // Navigate based on message data
  if (message.data['screen'] != null) {
    // Navigate to specific screen
  }
}

void _onNotificationTap(NotificationResponse response) {
  print('Local notification tapped: ${response.payload}');
  
  // Handle navigation
}

// ============================================
// Mobile App Main Entry Point
// ============================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Initialize mobile platform
  final platform = MobilePlatformService();
  await platform.initialize();
  
  runApp(
    ProviderScope(
      child: TelePromptProMobile(),
    ),
  );
}

class TelePromptProMobile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'TelePrompt Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: MobileMainScreen(),
    );
  }
}

class MobileMainScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MobileMainScreen> createState() => _MobileMainScreenState();
}

class _MobileMainScreenState extends ConsumerState<MobileMainScreen> {
  int _currentIndex = 0;
  
  final _pages = [
    MobileTeleprompterScreen(),
    MobileScriptsScreen(),
    MobileRecordScreen(),
    MobileProfileScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speaker_notes_outlined),
            selectedIcon: Icon(Icons.speaker_notes),
            label: 'Teleprompter',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Scripts',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================
// Mobile Screen Implementations
// ============================================

class MobileTeleprompterScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MobileTeleprompterScreen> createState() => _MobileTeleprompterScreenState();
}

class _MobileTeleprompterScreenState extends ConsumerState<MobileTeleprompterScreen> {
  bool _isPlaying = false;
  double _scrollSpeed = 2.0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teleprompter'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Show teleprompter settings
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main teleprompter display
          Container(
            color: Colors.black,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Your script text will appear here...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          
          // Control overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: Colors.white),
                    onPressed: () {},
                  ),
                  // Speed control
                  Row(
                    children: [
                      Icon(Icons.speed, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '${_scrollSpeed.toStringAsFixed(1)}x',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileScriptsScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MobileScriptsScreen> createState() => _MobileScriptsScreenState();
}

class _MobileScriptsScreenState extends ConsumerState<MobileScriptsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scripts'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              // Add new script
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.description),
              title: Text('Script ${index + 1}'),
              subtitle: Text('Last edited 2 hours ago'),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Text('Edit'),
                    value: 'edit',
                  ),
                  PopupMenuItem(
                    child: Text('Delete'),
                    value: 'delete',
                  ),
                  PopupMenuItem(
                    child: Text('Share'),
                    value: 'share',
                  ),
                ],
              ),
              onTap: () {
                // Open script
              },
            ),
          );
        },
      ),
    );
  }
}

class MobileRecordScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MobileRecordScreen> createState() => _MobileRecordScreenState();
}

class _MobileRecordScreenState extends ConsumerState<MobileRecordScreen> {
  final MobilePlatformService _platform = MobilePlatformService();
  bool _isRecording = false;
  bool _cameraInitialized = false;
  bool _showAnalytics = false;

  String _currentTranscription = 'Listening...';
  
  // Real-time metrics
  double _pitch = 150.0;
  double _volume = -20.0;
  double _pace = 150.0;
  String _emotion = 'Neutral';
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      await _platform.startCamera();
      setState(() {
        _cameraInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera initialization failed')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview with transcription
            if (_cameraInitialized)
              Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Icon(Icons.videocam, size: 64, color: Colors.white30),
                        ),
                      ),
                    ),
                  ),
                  // Live transcription overlay
                  if (_isRecording)
                    Positioned(
                      top: 100,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Live Transcription', 
                              style: TextStyle(color: Colors.white70, fontSize: 10)),
                            SizedBox(height: 4),
                            Text(
                              _currentTranscription,
                              style: TextStyle(color: Colors.white, fontSize: 14),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              Center(
                child: CircularProgressIndicator(),
              ),
            
            // Top controls
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (_isRecording)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('REC', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.flip_camera_ios, color: Colors.white),
                    onPressed: () {
                      // Flip camera
                    },
                  ),
                ],
              ),
            ),
            
            // Bottom controls
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Analytics toggle
                  if (_isRecording)
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAnalytics = !_showAnalytics;
                          });
                        },
                        icon: Icon(Icons.analytics, color: Colors.white),
                        label: Text(
                          _showAnalytics ? 'Hide Analytics' : 'Show Analytics',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  
                  // Record button
                  Center(
                    child: GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isRecording ? Colors.red : Colors.transparent,
                        ),
                        child: _isRecording
                            ? Icon(Icons.stop, color: Colors.white, size: 32)
                            : Container(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Analytics overlay
            if (_showAnalytics && _isRecording)
              Positioned(
                left: 16,
                right: 16,
                bottom: 140,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-time Analysis',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildMetric('Pitch', '${_pitch.round()} Hz'),
                      _buildMetric('Volume', '${_volume.round()} dB'),
                      _buildMetric('Pace', '${_pace.round()} WPM'),
                      _buildMetric('Emotion', _emotion),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetric(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
  
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      try {
        final file = await _platform.stopRecording();
        setState(() {
          _isRecording = false;
        });
        // Show completion dialog
        _showRecordingComplete(file.path);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording')),
        );
      }
    } else {
      try {
        await _platform.startRecording();
        setState(() {
          _isRecording = true;
        });
        _startRealtimeAnalysis();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording')),
        );
      }
    }
  }
  
  void _startRealtimeAnalysis() {
    // Simulate real-time updates
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _pitch = 120 + (30 * (DateTime.now().millisecondsSinceEpoch % 10) / 10);
        _volume = -30 + (20 * (DateTime.now().millisecondsSinceEpoch % 8) / 8);
        _pace = 140 + (40 * (DateTime.now().millisecondsSinceEpoch % 6) / 6);
        
        final emotions = ['Neutral', 'Happy', 'Confident', 'Focused'];
        _emotion = emotions[(DateTime.now().second ~/ 5) % emotions.length];
      
        // Add transcription simulation
        final phrases = [
          'Welcome to my presentation...',
          'Today we will discuss...',
          'This is an important point...',
          'Let me explain further...',
        ];
        _currentTranscription = phrases[DateTime.now().second % phrases.length];
      });
    });
  }
  
  void _showRecordingComplete(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recording Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text('Your recording has been saved'),
            SizedBox(height: 8),
            Text(
              'Path: ${path.split('/').last}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // View recording
            },
            child: Text('View'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Share recording
            },
            child: Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }
}

class MobileProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MobileSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // Profile header
          Container(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.person, size: 50),
                ),
                SizedBox(height: 16),
                Text(
                  'User Name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('user@example.com'),
                SizedBox(height: 16),
                // Subscription status
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Pro Plan',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          
          Divider(),
          
          // Menu items
          ListTile(
            leading: Icon(Icons.cloud),
            title: Text('Cloud Storage'),
            subtitle: Text('2.5 GB used of 10 GB'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.analytics),
            title: Text('Analytics'),
            subtitle: Text('View your performance'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.payment),
            title: Text('Subscription'),
            subtitle: Text('Manage your plan'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Sign Out'),
            onTap: () {
              // Sign out
            },
          ),
        ],
      ),
    );
  }
}

class MobileSettingsScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MobileSettingsScreen> createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends ConsumerState<MobileSettingsScreen> {
  String _selectedCamera = 'Back Camera';
  String _selectedMicrophone = 'Device Microphone';
  String _videoQuality = '1080p';
  String _exportLocation = '/storage/emulated/0/TelePromptPro/';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          // Recording Settings
          Card(
            margin: EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  title: Text('Recording Settings', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  title: Text('Camera'),
                  subtitle: Text(_selectedCamera),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () => _showCameraSelection(),
                ),
                ListTile(
                  title: Text('Microphone'),
                  subtitle: Text(_selectedMicrophone),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () => _showMicrophoneSelection(),
                ),
                ListTile(
                  title: Text('Video Quality'),
                  subtitle: Text(_videoQuality),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () => _showQualitySelection(),
                ),
              ],
            ),
          ),
          
          // Export Settings
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  title: Text('Export Settings',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  title: Text('Default Export Location'),
                  subtitle: Text(_exportLocation),
                  trailing: Icon(Icons.folder),
                  onTap: () => _selectExportLocation(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showCameraSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: ['Back Camera', 'Front Camera', 'External Camera']
            .map((camera) => ListTile(
                  title: Text(camera),
                  onTap: () {
                    setState(() => _selectedCamera = camera);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
  
  void _showMicrophoneSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: ['Device Microphone', 'Bluetooth Headset', 'Wired Headset']
            .map((mic) => ListTile(
                  title: Text(mic),
                  onTap: () {
                    setState(() => _selectedMicrophone = mic);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
  
  void _showQualitySelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: ['720p', '1080p', '4K']
            .map((quality) => ListTile(
                  title: Text(quality),
                  onTap: () {
                    setState(() => _videoQuality = quality);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
  
  void _selectExportLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder picker would open here')),
    );
  }
}