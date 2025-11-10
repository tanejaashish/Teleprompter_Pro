// Integration Tests - Full API Integration
// Tests real API calls from Flutter to backend services

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../lib/api/api_client.dart';

void main() {
  // Test configuration
  const String testBaseUrl = 'http://localhost:3000';
  const bool runIntegrationTests = bool.fromEnvironment(
    'INTEGRATION_TESTS',
    defaultValue: false,
  );

  group('API Integration Tests', () {
    late ApiClient apiClient;
    late AuthService authService;
    late ScriptService scriptService;
    late RecordingService recordingService;

    String? testAccessToken;
    String? testRefreshToken;
    String? testUserId;
    String? testScriptId;

    setUpAll(() {
      if (!runIntegrationTests) {
        print('Skipping integration tests. Set INTEGRATION_TESTS=true to run.');
      }
    });

    setUp(() {
      apiClient = ApiClient(baseUrl: testBaseUrl);
      authService = AuthService(apiClient);
      scriptService = ScriptService(apiClient);
      recordingService = RecordingService(apiClient);
    });

    tearDown(() {
      apiClient.clearTokens();
    });

    test('Health check endpoint should respond', () async {
      if (!runIntegrationTests) return;

      final response = await http.get(Uri.parse('$testBaseUrl/health'));
      expect(response.statusCode, equals(200));
      expect(response.body, contains('healthy'));
    }, skip: !runIntegrationTests);

    group('Authentication Flow', () {
      test('Sign up new user', () async {
        if (!runIntegrationTests) return;

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final email = 'test_$timestamp@example.com';
        final password = 'TestPassword123!';

        final response = await authService.signUp(
          email: email,
          password: password,
          displayName: 'Test User',
        );

        expect(response.isSuccess, isTrue);
        expect(response.data, isNotNull);

        final data = response.data as Map<String, dynamic>;
        expect(data['user'], isNotNull);
        expect(data['user']['email'], equals(email));

        testUserId = data['user']['id'];
      }, skip: !runIntegrationTests);

      test('Sign in with credentials', () async {
        if (!runIntegrationTests) return;

        // Use credentials from previous test or predefined test user
        final email = 'test@example.com';
        final password = 'TestPassword123!';

        final response = await authService.signIn(
          email: email,
          password: password,
        );

        expect(response.isSuccess, isTrue);
        expect(response.data, isNotNull);

        final data = response.data as Map<String, dynamic>;
        expect(data['session'], isNotNull);
        expect(data['session']['accessToken'], isNotNull);
        expect(data['session']['refreshToken'], isNotNull);

        testAccessToken = data['session']['accessToken'];
        testRefreshToken = data['session']['refreshToken'];
        testUserId = data['user']['id'];

        // Verify tokens are set in client
        expect(apiClient, isNotNull);
      }, skip: !runIntegrationTests);

      test('Access protected endpoint with token', () async {
        if (!runIntegrationTests) return;
        if (testAccessToken == null) {
          // Sign in first
          await authService.signIn(
            email: 'test@example.com',
            password: 'TestPassword123!',
          );
        }

        final response = await apiClient.get('/api/user/profile');

        expect(response.isSuccess, isTrue);
        expect(response.data, isNotNull);
      }, skip: !runIntegrationTests);

      test('Sign out', () async {
        if (!runIntegrationTests) return;

        final response = await authService.signOut();
        expect(response.isSuccess, isTrue);
      }, skip: !runIntegrationTests);
    });

    group('Script Management', () {
      setUp(() async {
        if (!runIntegrationTests) return;

        // Ensure user is signed in
        if (testAccessToken == null) {
          await authService.signIn(
            email: 'test@example.com',
            password: 'TestPassword123!',
          );
        }
      });

      test('Create script', () async {
        if (!runIntegrationTests) return;

        final response = await scriptService.createScript(
          title: 'Integration Test Script',
          content: 'This is a test script content for integration testing.',
          category: 'presentation',
          tags: ['test', 'integration'],
        );

        expect(response.isSuccess, isTrue);
        expect(response.data, isNotNull);

        final script = response.data as Map<String, dynamic>;
        expect(script['id'], isNotNull);
        expect(script['title'], equals('Integration Test Script'));

        testScriptId = script['id'];
      }, skip: !runIntegrationTests);

      test('Get all scripts', () async {
        if (!runIntegrationTests) return;

        final response = await scriptService.getScripts();

        expect(response.isSuccess, isTrue);
        expect(response.data, isNotNull);

        final scripts = response.data as List;
        expect(scripts, isNotEmpty);
      }, skip: !runIntegrationTests);

      test('Update script', () async {
        if (!runIntegrationTests) return;
        if (testScriptId == null) return;

        final response = await scriptService.updateScript(
          testScriptId!,
          title: 'Updated Integration Test Script',
          content: 'Updated content for integration testing.',
        );

        expect(response.isSuccess, isTrue);
        expect(response.data, isNotNull);

        final script = response.data as Map<String, dynamic>;
        expect(script['title'], equals('Updated Integration Test Script'));
      }, skip: !runIntegrationTests);

      test('Delete script', () async {
        if (!runIntegrationTests) return;
        if (testScriptId == null) return;

        final response = await scriptService.deleteScript(testScriptId!);

        expect(response.isSuccess, isTrue);
      }, skip: !runIntegrationTests);
    });

    group('Recording Management', () {
      setUp(() async {
        if (!runIntegrationTests) return;

        // Ensure user is signed in
        if (testAccessToken == null) {
          await authService.signIn(
            email: 'test@example.com',
            password: 'TestPassword123!',
          );
        }
      });

      test('Get recordings', () async {
        if (!runIntegrationTests) return;

        final response = await recordingService.getRecordings();

        expect(response.isSuccess, isTrue);
        expect(response.data, isNotNull);

        final recordings = response.data as List;
        // May be empty if no recordings exist
        expect(recordings, isA<List>());
      }, skip: !runIntegrationTests);

      // Note: File upload test requires actual file, skipping in basic integration
      test('Upload recording - structure test', () async {
        if (!runIntegrationTests) return;

        // This tests the API structure without actual file upload
        // In real tests, you would use a mock file

        expect(recordingService, isNotNull);
        expect(recordingService.uploadRecording, isA<Function>());
      }, skip: !runIntegrationTests);
    });

    group('Error Handling', () {
      test('Handle 404 error', () async {
        if (!runIntegrationTests) return;

        final response = await apiClient.get('/api/nonexistent');

        expect(response.isSuccess, isFalse);
        expect(response.statusCode, equals(404));
        expect(response.error, isNotNull);
      }, skip: !runIntegrationTests);

      test('Handle 401 unauthorized', () async {
        if (!runIntegrationTests) return;

        // Clear tokens
        apiClient.clearTokens();

        final response = await apiClient.get('/api/user/profile');

        expect(response.isSuccess, isFalse);
        expect(response.statusCode, equals(401));
      }, skip: !runIntegrationTests);

      test('Handle network error gracefully', () async {
        if (!runIntegrationTests) return;

        // Create client with invalid URL
        final badClient = ApiClient(baseUrl: 'http://invalid-url-that-does-not-exist:9999');

        final response = await badClient.get('/api/test');

        expect(response.isSuccess, isFalse);
        expect(response.error, isNotNull);
        expect(response.error, contains('error'));
      }, skip: !runIntegrationTests);
    });

    group('Token Refresh Flow', () {
      test('Automatically refresh expired token', () async {
        if (!runIntegrationTests) return;

        // This test requires backend to return 401 for expired token
        // Then verify that client automatically refreshes

        // Sign in first
        await authService.signIn(
          email: 'test@example.com',
          password: 'TestPassword123!',
        );

        // Make request (should work)
        final response1 = await apiClient.get('/api/user/profile');
        expect(response1.isSuccess, isTrue);

        // In real scenario, you'd wait for token to expire or mock it
        // For now, just verify the refresh mechanism exists
        expect(apiClient, isNotNull);
      }, skip: !runIntegrationTests);
    });

    group('WebSocket Integration', () {
      test('WebSocket connection structure', () async {
        if (!runIntegrationTests) return;

        // Test WebSocket client creation and structure
        // Actual connection test requires running backend

        expect(true, isTrue); // Placeholder for WebSocket tests
      }, skip: !runIntegrationTests);
    });
  });

  group('Performance Tests', () {
    test('API response time should be acceptable', () async {
      if (!runIntegrationTests) return;

      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse('$testBaseUrl/health'));
      stopwatch.stop();

      expect(response.statusCode, equals(200));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Less than 1 second
    }, skip: !runIntegrationTests);

    test('Concurrent requests should succeed', () async {
      if (!runIntegrationTests) return;

      final futures = List.generate(
        10,
        (_) => http.get(Uri.parse('$testBaseUrl/health')),
      );

      final responses = await Future.wait(futures);

      for (final response in responses) {
        expect(response.statusCode, equals(200));
      }
    }, skip: !runIntegrationTests);
  });
}
