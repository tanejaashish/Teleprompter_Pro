// packages/core/lib/analytics/analytics_service.dart
class AnalyticsService {
  void trackEvent(String event, Map<String, dynamic> properties);
  void trackScreen(String screenName);
  void trackError(dynamic error, StackTrace? stackTrace);
  void setUserProperties(Map<String, dynamic> properties);
}