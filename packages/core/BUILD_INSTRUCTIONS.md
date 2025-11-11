# Build Instructions for Core Package

## Prerequisites

Ensure you have Flutter SDK installed and configured:
```bash
flutter doctor
```

## First-Time Setup

### 1. Install Dependencies

```bash
cd packages/core
flutter pub get
```

### 2. Generate Required Files

The Drift database and Riverpod providers require code generation:

```bash
# Generate all code (database, serialization, riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# Or watch for changes during development
flutter pub run build_runner watch --delete-conflicting-outputs
```

This will generate:
- `lib/database/local_database.g.dart` - Drift database implementation
- Other `*.g.dart` files for JSON serialization and Riverpod providers

### 3. Verify Build

```bash
# Analyze code
flutter analyze

# Run tests
flutter test

# Run integration tests (requires backend running)
flutter test test/integration --dart-define=INTEGRATION_TESTS=true
```

## Common Issues

### Issue: "Part file doesn't exist"

**Error**: `lib/database/local_database.g.dart` doesn't exist

**Solution**:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: Build runner conflicts

**Error**: Conflicts during code generation

**Solution**:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: Integration tests fail

**Error**: Connection refused to localhost:3000

**Solution**: Start the backend server first:
```bash
cd backend/api-gateway
npm run dev
```

## Development Workflow

1. Make code changes
2. Run build_runner if you modified:
   - Database schemas (Drift tables)
   - JSON serializable classes
   - Riverpod providers with annotations
3. Test your changes
4. Commit (generated files are gitignored)

## CI/CD

The CI pipeline will automatically run:
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

## Notes

- Generated files (*.g.dart) are **gitignored**
- Always run `build_runner` after pulling changes that affect schemas
- Use `watch` mode during active development for auto-regeneration
