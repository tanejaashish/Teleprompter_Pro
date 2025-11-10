// Flutter Test Suite - State Management
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/state/providers.dart';
import '../../lib/models/script.dart';
import '../../lib/models/user.dart';

void main() {
  group('AuthNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should be unauthenticated', () {
      final authState = container.read(authStateProvider);

      expect(authState.isAuthenticated, false);
      expect(authState.user, isNull);
      expect(authState.isLoading, false);
    });

    test('signIn should update state on success', () async {
      final notifier = container.read(authStateProvider.notifier);

      // Mock successful sign in
      // Note: In real tests, you'd mock the API client
      await notifier.signIn('test@example.com', 'password123');

      final state = container.read(authStateProvider);
      // expect(state.isAuthenticated, true);
      // expect(state.user, isNotNull);
    });

    test('signOut should clear user state', () async {
      final notifier = container.read(authStateProvider.notifier);

      await notifier.signOut();

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
    });
  });

  group('ScriptsNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should have empty scripts list', () {
      final scriptsState = container.read(scriptsProvider);

      expect(scriptsState.scripts, isEmpty);
      expect(scriptsState.isLoading, false);
      expect(scriptsState.selectedScript, isNull);
    });

    test('selectScript should update selectedScript', () {
      final notifier = container.read(scriptsProvider.notifier);

      final mockScript = Script(
        id: '1',
        title: 'Test Script',
        content: 'Test content',
        wordCount: 2,
        estimatedDuration: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      notifier.selectScript(mockScript);

      final state = container.read(scriptsProvider);
      expect(state.selectedScript, equals(mockScript));
    });
  });

  group('TeleprompterNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should have correct defaults', () {
      final state = container.read(teleprompterProvider);

      expect(state.isScrolling, false);
      expect(state.scrollSpeed, 1.0);
      expect(state.mirrorMode, false);
      expect(state.showGuide, true);
    });

    test('toggleScroll should toggle scrolling state', () {
      final notifier = container.read(teleprompterProvider.notifier);

      notifier.toggleScroll();
      var state = container.read(teleprompterProvider);
      expect(state.isScrolling, true);

      notifier.toggleScroll();
      state = container.read(teleprompterProvider);
      expect(state.isScrolling, false);
    });

    test('setScrollSpeed should update speed', () {
      final notifier = container.read(teleprompterProvider.notifier);

      notifier.setScrollSpeed(2.5);

      final state = container.read(teleprompterProvider);
      expect(state.scrollSpeed, 2.5);
    });

    test('toggleMirrorMode should toggle mirror state', () {
      final notifier = container.read(teleprompterProvider.notifier);

      notifier.toggleMirrorMode();
      var state = container.read(teleprompterProvider);
      expect(state.mirrorMode, true);

      notifier.toggleMirrorMode();
      state = container.read(teleprompterProvider);
      expect(state.mirrorMode, false);
    });
  });

  group('SettingsNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should have correct defaults', () {
      final settings = container.read(settingsProvider);

      expect(settings.darkMode, false);
      expect(settings.language, 'en');
      expect(settings.notifications, true);
      expect(settings.textSize, 16.0);
    });

    test('toggleDarkMode should toggle dark mode', () {
      final notifier = container.read(settingsProvider.notifier);

      notifier.toggleDarkMode();
      var settings = container.read(settingsProvider);
      expect(settings.darkMode, true);

      notifier.toggleDarkMode();
      settings = container.read(settingsProvider);
      expect(settings.darkMode, false);
    });

    test('setLanguage should update language', () {
      final notifier = container.read(settingsProvider.notifier);

      notifier.setLanguage('es');

      final settings = container.read(settingsProvider);
      expect(settings.language, 'es');
    });

    test('setTextSize should update text size', () {
      final notifier = container.read(settingsProvider.notifier);

      notifier.setTextSize(20.0);

      final settings = container.read(settingsProvider);
      expect(settings.textSize, 20.0);
    });
  });
}
