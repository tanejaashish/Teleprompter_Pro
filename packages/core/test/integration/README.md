# Integration Test Suite

Complete integration tests for TelePrompt Pro API endpoints.

## Overview

These tests verify end-to-end functionality against a running backend server, including:
- Authentication flows (signup, signin, OAuth, token refresh)
- Script CRUD operations
- Recording management
- Error handling and edge cases
- Performance benchmarks

## Prerequisites

### 1. Backend Server Running

The integration tests require the backend API server to be running locally.

```bash
# Terminal 1: Start PostgreSQL and Redis
docker-compose up postgres redis

# Terminal 2: Run migrations
cd backend
npx prisma migrate dev

# Terminal 3: Start API gateway
cd backend/api-gateway
npm run dev
```

The server should be running at `http://localhost:3000`

### 2. Test Database Setup

Use a separate test database to avoid conflicts:

```bash
# Create test database
createdb teleprompt_test

# Set test environment variables
export TEST_DATABASE_URL="postgresql://user:password@localhost:5432/teleprompt_test?schema=public"

# Run migrations for test DB
cd backend
DATABASE_URL=$TEST_DATABASE_URL npx prisma migrate deploy
```

### 3. Environment Configuration

Create `packages/core/test/integration/.env.test`:

```env
TEST_API_URL=http://localhost:3000
TEST_EMAIL=test@example.com
TEST_PASSWORD=TestPassword123!
INTEGRATION_TESTS=true
```

## Running Tests

### Run All Integration Tests

```bash
cd packages/core
flutter test test/integration --dart-define=INTEGRATION_TESTS=true
```

### Run Specific Test File

```bash
flutter test test/integration/api_integration_test.dart --dart-define=INTEGRATION_TESTS=true
```

### Run with Verbose Output

```bash
flutter test test/integration --dart-define=INTEGRATION_TESTS=true --verbose
```

### Run in Watch Mode

```bash
flutter test test/integration --dart-define=INTEGRATION_TESTS=true --watch
```

## Test Structure

### api_integration_test.dart

Main integration test suite covering:

**Authentication Tests:**
- ✓ Sign up with email/password
- ✓ Sign in with credentials
- ✓ Token refresh mechanism
- ✓ Sign out
- ✓ Invalid credentials handling

**Script Tests:**
- ✓ Get all scripts (empty state)
- ✓ Create new script
- ✓ Get all scripts (with data)
- ✓ Update script
- ✓ Get script by ID
- ✓ Delete script

**Recording Tests:**
- ✓ Create recording
- ✓ Get recordings
- ✓ Upload recording file
- ✓ Update recording status

**Error Handling:**
- ✓ 404 Not Found
- ✓ 401 Unauthorized
- ✓ 400 Bad Request
- ✓ Network errors
- ✓ Timeout handling

**Performance Tests:**
- ✓ Response time < 500ms for GET requests
- ✓ Response time < 1s for POST requests
- ✓ Concurrent requests handling

## Test Data Management

### Cleanup Between Tests

Tests automatically clean up created data:

```dart
tearDown(() async {
  // Delete test user and associated data
  await cleanupTestData();
});
```

### Test User Accounts

Each test run creates a unique test user:

```dart
final testEmail = 'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
```

This prevents conflicts between test runs.

## CI/CD Integration

### GitHub Actions

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  integration-tests:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install backend dependencies
        run: |
          cd backend/api-gateway
          npm install

      - name: Run migrations
        run: |
          cd backend
          npx prisma migrate deploy

      - name: Start backend server
        run: |
          cd backend/api-gateway
          npm run dev &
          sleep 5

      - name: Run integration tests
        run: |
          cd packages/core
          flutter pub get
          flutter test test/integration --dart-define=INTEGRATION_TESTS=true
```

## Troubleshooting

### Server Not Running

**Error:** `Connection refused to localhost:3000`

**Solution:**
```bash
cd backend/api-gateway
npm run dev
```

### Database Connection Error

**Error:** `Can't reach database server`

**Solution:**
```bash
# Check PostgreSQL is running
docker-compose up -d postgres

# Verify connection
psql $DATABASE_URL -c "SELECT 1;"
```

### Redis Connection Error

**Error:** `Could not connect to Redis`

**Solution:**
```bash
# Start Redis
docker-compose up -d redis

# Verify connection
redis-cli ping
```

### Test Timeout

**Error:** `Test exceeded timeout`

**Solution:** Increase timeout in test:
```dart
test('API call', () async {
  // ...
}, timeout: Timeout(Duration(seconds: 30)));
```

### Port Already in Use

**Error:** `EADDRINUSE: address already in use :::3000`

**Solution:**
```bash
# Find process using port 3000
lsof -ti:3000

# Kill the process
kill -9 <PID>
```

## Writing New Integration Tests

### Template

```dart
group('Feature Name', () {
  late ApiClient apiClient;
  late String accessToken;

  setUpAll(() async {
    apiClient = ApiClient(baseUrl: testBaseUrl);

    // Sign in to get token
    final authResponse = await apiClient.signIn(
      email: testEmail,
      password: testPassword,
    );

    accessToken = authResponse.data['session']['accessToken'];
    apiClient.setToken(accessToken);
  });

  test('should do something', () async {
    final response = await apiClient.someEndpoint();

    expect(response.isSuccess, isTrue);
    expect(response.data, isNotNull);
    // More assertions...
  });

  tearDownAll(() async {
    await cleanupTestData();
  });
});
```

### Best Practices

1. **Use unique identifiers** for test data to avoid conflicts
2. **Clean up after tests** to keep database clean
3. **Test both success and failure cases**
4. **Use realistic test data** that matches production scenarios
5. **Check response times** to catch performance regressions
6. **Verify error messages** are user-friendly
7. **Test edge cases** (empty strings, very long inputs, special characters)

## Performance Benchmarks

Expected response times:

| Endpoint | Expected Time | Max Acceptable |
|----------|---------------|----------------|
| GET /api/scripts | < 200ms | 500ms |
| POST /api/scripts | < 300ms | 1s |
| PUT /api/scripts/:id | < 300ms | 1s |
| DELETE /api/scripts/:id | < 200ms | 500ms |
| GET /api/recordings | < 250ms | 500ms |
| POST /api/auth/signin | < 400ms | 1s |

Tests will fail if response times exceed max acceptable thresholds.

## Code Coverage

Run tests with coverage:

```bash
flutter test test/integration --dart-define=INTEGRATION_TESTS=true --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

Target coverage: > 80% for integration tests

## Additional Resources

- [API Documentation](http://localhost:3000/api-docs)
- [Backend Setup Guide](../../../backend/README.md)
- [Database Schema](../../../backend/prisma/schema.prisma)
- [Testing Best Practices](../../docs/testing.md)
