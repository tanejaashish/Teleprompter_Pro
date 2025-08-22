// ============================================
// Monitoring & Analytics
// ============================================

// packages/monitoring/lib/monitoring_service.dart

class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();
  
  // Performance Monitoring
  void trackPerformance(String metric, double value) {
    // Send to monitoring service
    _sendMetric({
      'type': 'performance',
      'metric': metric,
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
      'device': _getDeviceInfo(),
    });
  }
  
  // Error Tracking
  void trackError(dynamic error, StackTrace? stackTrace) {
    // Send to error tracking service
    _sendError({
      'error': error.toString(),
      'stackTrace': stackTrace?.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'device': _getDeviceInfo(),
      'context': _getContext(),
    });
  }
  
  // User Analytics
  void trackEvent(String event, Map<String, dynamic>? properties) {
    // Send to analytics service
    _sendEvent({
      'event': event,
      'properties': properties,
      'timestamp': DateTime.now().toIso8601String(),
      'userId': _getUserId(),
      'sessionId': _getSessionId(),
    });
  }
  
  // Custom Metrics
  void trackCustomMetric(String name, dynamic value, Map<String, String>? tags) {
    _sendMetric({
      'type': 'custom',
      'name': name,
      'value': value,
      'tags': tags,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  // Health Checks
  Future<HealthStatus> checkHealth() async {
    final checks = await Future.wait([
      _checkAPI(),
      _checkDatabase(),
      _checkStorage(),
      _checkCache(),
      _checkWebSocket(),
    ]);
    
    return HealthStatus(
      healthy: checks.every((c) => c),
      timestamp: DateTime.now(),
      details: {
        'api': checks[0],
        'database': checks[1],
        'storage': checks[2],
        'cache': checks[3],
        'websocket': checks[4],
      },
    );
  }
  
  // Performance Profiling
  T profile<T>(String name, T Function() operation) {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = operation();
      stopwatch.stop();
      
      trackPerformance(name, stopwatch.elapsedMilliseconds.toDouble());
      
      return result;
    } catch (e, s) {
      stopwatch.stop();
      trackError(e, s);
      rethrow;
    }
  }
  
  // Memory Monitoring
  void monitorMemory() {
    Timer.periodic(const Duration(minutes: 1), (_) {
      final memoryInfo = ProcessInfo.currentRss;
      trackPerformance('memory_usage', memoryInfo / 1024 / 1024); // MB
      
      if (memoryInfo > 500 * 1024 * 1024) { // 500MB threshold
        trackEvent('high_memory_usage', {
          'memory_mb': memoryInfo / 1024 / 1024,
        });
      }
    });
  }
  
  // Network Monitoring
  void monitorNetwork() {
    // Monitor API response times
    HttpOverrides.global = MonitoringHttpOverrides();
  }
  
  // Crash Reporting
  void setupCrashReporting() {
    FlutterError.onError = (FlutterErrorDetails details) {
      trackError(details.exception, details.stack);
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      trackError(error, stack);
      return true;
    };
  }
  
  // Business Metrics
  void trackBusinessMetric(BusinessMetric metric) {
    _sendMetric({
      'type': 'business',
      'metric': metric.name,
      'value': metric.value,
      'currency': metric.currency,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  // A/B Testing
  String getExperimentVariant(String experimentName) {
    // Get variant from remote config
    final variant = _remoteConfig.getString('experiment_$experimentName');
    
    trackEvent('experiment_exposure', {
      'experiment': experimentName,
      'variant': variant,
    });
    
    return variant;
  }
  
  // Session Recording (for debugging)
  void startSessionRecording() {
    if (!kDebugMode) return;
    
    // Record user interactions for debugging
    _sessionRecorder.start();
  }
  
  Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
    };
  }
  
  Map<String, dynamic> _getContext() {
    return {
      'screen': _currentScreen,
      'user_id': _userId,
      'session_id': _sessionId,
      'app_version': _appVersion,
    };
  }
  
  Future<void> _sendMetric(Map<String, dynamic> metric) async {
    // Send to monitoring service (DataDog, New Relic, etc.)
    await http.post(
      Uri.parse('https://metrics.teleprompt.pro/v1/metrics'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(metric),
    );
  }
  
  Future<void> _sendError(Map<String, dynamic> error) async {
    // Send to error tracking service (Sentry, Bugsnag, etc.)
    await http.post(
      Uri.parse('https://errors.teleprompt.pro/v1/errors'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(error),
    );
  }
  
  Future<void> _sendEvent(Map<String, dynamic> event) async {
    // Send to analytics service (Mixpanel, Amplitude, etc.)
    await http.post(
      Uri.parse('https://analytics.teleprompt.pro/v1/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(event),
    );
  }
}

class HealthStatus {
  final bool healthy;
  final DateTime timestamp;
  final Map<String, bool> details;
  
  HealthStatus({
    required this.healthy,
    required this.timestamp,
    required this.details,
  });
}

class BusinessMetric {
  final String name;
  final double value;
  final String? currency;
  
  BusinessMetric({
    required this.name,
    required this.value,
    this.currency,
  });
}