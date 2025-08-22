class AppConfig {
  // API Keys (store securely in production)
  static const String openAiApiKey = 'YOUR_OPENAI_API_KEY';
  static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID';
  static const String microsoftClientId = 'YOUR_MICROSOFT_CLIENT_ID';
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
  
  // API Endpoints
  static const String apiBaseUrl = 'https://api.teleprompt.pro';
  static const String websocketUrl = 'wss://ws.teleprompt.pro';
  
  // Feature Flags
  static const bool enableAiAnalysis = true;
  static const bool enableCloudSync = true;
  static const bool enableSystemTray = true;
  
  // Storage Paths
  static const String recordingsPath = 'TelePromptPro/Recordings';
  static const String scriptsPath = 'TelePromptPro/Scripts';
  static const String analyticsPath = 'TelePromptPro/Analytics';
}