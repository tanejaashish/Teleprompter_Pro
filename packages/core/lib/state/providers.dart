// Riverpod State Management - Core Providers
// Comprehensive state management for TelePrompt Pro

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/script.dart';
import '../models/recording.dart';
import '../models/user.dart';

// =============================================================================
// API Client Provider
// =============================================================================

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://localhost:3000',
    ),
  );
});

// =============================================================================
// Authentication State
// =============================================================================

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});

class AuthState {
  final User? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Check if user is already logged in (from secure storage)
    // This would integrate with flutter_secure_storage
    state = state.copyWith(isLoading: false);
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final authService = AuthService(_apiClient);
    final response = await authService.signIn(
      email: email,
      password: password,
    );

    if (response.isSuccess) {
      final data = response.data as Map<String, dynamic>;
      final user = User.fromJson(data['user']);

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
      );
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String? displayName) async {
    state = state.copyWith(isLoading: true, error: null);

    final authService = AuthService(_apiClient);
    final response = await authService.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );

    if (response.isSuccess) {
      final data = response.data as Map<String, dynamic>;
      final user = User.fromJson(data['user']);

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    final authService = AuthService(_apiClient);
    await authService.signOut();

    state = AuthState();
  }
}

// =============================================================================
// Scripts State
// =============================================================================

final scriptsProvider = StateNotifierProvider<ScriptsNotifier, ScriptsState>((ref) {
  return ScriptsNotifier(ref.read(apiClientProvider));
});

class ScriptsState {
  final List<Script> scripts;
  final bool isLoading;
  final String? error;
  final Script? selectedScript;

  ScriptsState({
    this.scripts = const [],
    this.isLoading = false,
    this.error,
    this.selectedScript,
  });

  ScriptsState copyWith({
    List<Script>? scripts,
    bool? isLoading,
    String? error,
    Script? selectedScript,
  }) {
    return ScriptsState(
      scripts: scripts ?? this.scripts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedScript: selectedScript ?? this.selectedScript,
    );
  }
}

class ScriptsNotifier extends StateNotifier<ScriptsState> {
  final ApiClient _apiClient;

  ScriptsNotifier(this._apiClient) : super(ScriptsState()) {
    loadScripts();
  }

  Future<void> loadScripts() async {
    state = state.copyWith(isLoading: true, error: null);

    final scriptService = ScriptService(_apiClient);
    final response = await scriptService.getScripts();

    if (response.isSuccess) {
      final scriptsData = response.data as List;
      final scripts = scriptsData.map((json) => Script.fromJson(json)).toList();

      state = state.copyWith(
        scripts: scripts,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
      );
    }
  }

  Future<bool> createScript({
    required String title,
    required String content,
    String? category,
    List<String>? tags,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final scriptService = ScriptService(_apiClient);
    final response = await scriptService.createScript(
      title: title,
      content: content,
      category: category,
      tags: tags,
    );

    if (response.isSuccess) {
      final scriptData = response.data as Map<String, dynamic>;
      final newScript = Script.fromJson(scriptData);

      state = state.copyWith(
        scripts: [...state.scripts, newScript],
        isLoading: false,
      );

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
      );
      return false;
    }
  }

  Future<bool> updateScript(
    String id, {
    String? title,
    String? content,
    String? category,
    List<String>? tags,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final scriptService = ScriptService(_apiClient);
    final response = await scriptService.updateScript(
      id,
      title: title,
      content: content,
      category: category,
      tags: tags,
    );

    if (response.isSuccess) {
      final updatedData = response.data as Map<String, dynamic>;
      final updatedScript = Script.fromJson(updatedData);

      final updatedScripts = state.scripts.map((script) {
        return script.id == id ? updatedScript : script;
      }).toList();

      state = state.copyWith(
        scripts: updatedScripts,
        isLoading: false,
      );

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
      );
      return false;
    }
  }

  Future<bool> deleteScript(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    final scriptService = ScriptService(_apiClient);
    final response = await scriptService.deleteScript(id);

    if (response.isSuccess) {
      final updatedScripts = state.scripts.where((s) => s.id != id).toList();

      state = state.copyWith(
        scripts: updatedScripts,
        isLoading: false,
      );

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
      );
      return false;
    }
  }

  void selectScript(Script script) {
    state = state.copyWith(selectedScript: script);
  }
}

// =============================================================================
// Recordings State
// =============================================================================

final recordingsProvider = StateNotifierProvider<RecordingsNotifier, RecordingsState>((ref) {
  return RecordingsNotifier(ref.read(apiClientProvider));
});

class RecordingsState {
  final List<Recording> recordings;
  final bool isLoading;
  final String? error;
  final bool isRecording;
  final Recording? currentRecording;

  RecordingsState({
    this.recordings = const [],
    this.isLoading = false,
    this.error,
    this.isRecording = false,
    this.currentRecording,
  });

  RecordingsState copyWith({
    List<Recording>? recordings,
    bool? isLoading,
    String? error,
    bool? isRecording,
    Recording? currentRecording,
  }) {
    return RecordingsState(
      recordings: recordings ?? this.recordings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRecording: isRecording ?? this.isRecording,
      currentRecording: currentRecording ?? this.currentRecording,
    );
  }
}

class RecordingsNotifier extends StateNotifier<RecordingsState> {
  final ApiClient _apiClient;

  RecordingsNotifier(this._apiClient) : super(RecordingsState()) {
    loadRecordings();
  }

  Future<void> loadRecordings() async {
    state = state.copyWith(isLoading: true, error: null);

    final recordingService = RecordingService(_apiClient);
    final response = await recordingService.getRecordings();

    if (response.isSuccess) {
      final recordingsData = response.data as List;
      final recordings = recordingsData.map((json) => Recording.fromJson(json)).toList();

      state = state.copyWith(
        recordings: recordings,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
      );
    }
  }

  void startRecording() {
    state = state.copyWith(isRecording: true);
  }

  void stopRecording() {
    state = state.copyWith(isRecording: false);
  }
}

// =============================================================================
// Teleprompter State
// =============================================================================

final teleprompterProvider = StateNotifierProvider<TeleprompterNotifier, TeleprompterState>((ref) {
  return TeleprompterNotifier();
});

class TeleprompterState {
  final bool isScrolling;
  final double scrollSpeed;
  final int currentPosition;
  final bool mirrorMode;
  final bool showGuide;
  final double guidePosition;

  TeleprompterState({
    this.isScrolling = false,
    this.scrollSpeed = 1.0,
    this.currentPosition = 0,
    this.mirrorMode = false,
    this.showGuide = true,
    this.guidePosition = 0.3,
  });

  TeleprompterState copyWith({
    bool? isScrolling,
    double? scrollSpeed,
    int? currentPosition,
    bool? mirrorMode,
    bool? showGuide,
    double? guidePosition,
  }) {
    return TeleprompterState(
      isScrolling: isScrolling ?? this.isScrolling,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      currentPosition: currentPosition ?? this.currentPosition,
      mirrorMode: mirrorMode ?? this.mirrorMode,
      showGuide: showGuide ?? this.showGuide,
      guidePosition: guidePosition ?? this.guidePosition,
    );
  }
}

class TeleprompterNotifier extends StateNotifier<TeleprompterState> {
  TeleprompterNotifier() : super(TeleprompterState());

  void toggleScroll() {
    state = state.copyWith(isScrolling: !state.isScrolling);
  }

  void setScrollSpeed(double speed) {
    state = state.copyWith(scrollSpeed: speed);
  }

  void setPosition(int position) {
    state = state.copyWith(currentPosition: position);
  }

  void toggleMirrorMode() {
    state = state.copyWith(mirrorMode: !state.mirrorMode);
  }

  void toggleGuide() {
    state = state.copyWith(showGuide: !state.showGuide);
  }

  void setGuidePosition(double position) {
    state = state.copyWith(guidePosition: position);
  }
}

// =============================================================================
// App Settings State
// =============================================================================

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class AppSettings {
  final bool darkMode;
  final String language;
  final bool notifications;
  final double textSize;
  final String fontFamily;

  AppSettings({
    this.darkMode = false,
    this.language = 'en',
    this.notifications = true,
    this.textSize = 16.0,
    this.fontFamily = 'Roboto',
  });

  AppSettings copyWith({
    bool? darkMode,
    String? language,
    bool? notifications,
    double? textSize,
    String? fontFamily,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      notifications: notifications ?? this.notifications,
      textSize: textSize ?? this.textSize,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings());

  void toggleDarkMode() {
    state = state.copyWith(darkMode: !state.darkMode);
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }

  void toggleNotifications() {
    state = state.copyWith(notifications: !state.notifications);
  }

  void setTextSize(double size) {
    state = state.copyWith(textSize: size);
  }

  void setFontFamily(String font) {
    state = state.copyWith(fontFamily: font);
  }
}
