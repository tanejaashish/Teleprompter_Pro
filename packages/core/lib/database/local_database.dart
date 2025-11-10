// Local Database with Drift
// Provides offline-first architecture with local storage and sync capabilities

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_database.g.dart';

// Table Definitions

class Scripts extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get richContent => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get tags => text().nullable()(); // JSON array as string
  IntColumn get wordCount => integer()();
  IntColumn get estimatedDuration => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get userId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Recordings extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get scriptId => text().nullable()();
  IntColumn get duration => integer()();
  IntColumn get fileSize => integer()();
  TextColumn get localPath => text().nullable()();
  TextColumn get cloudUrl => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get status => text()(); // uploading, uploaded, failed
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get userId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // script, recording, user
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // create, update, delete
  TextColumn get payload => text()(); // JSON payload
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  BoolColumn get isProcessed => boolean().withDefault(const Constant(false))();
}

class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

class UserSettings extends Table {
  TextColumn get userId => text()();
  BoolColumn get darkMode => boolean().withDefault(const Constant(false))();
  TextColumn get language => text().withDefault(const Constant('en'))();
  BoolColumn get notifications => boolean().withDefault(const Constant(true))();
  RealColumn get textSize => real().withDefault(const Constant(16.0))();
  TextColumn get customSettings => text().nullable()(); // JSON for extensibility

  @override
  Set<Column> get primaryKey => {userId};
}

// Database Class
@DriftDatabase(tables: [
  Scripts,
  Recordings,
  SyncQueue,
  CacheEntries,
  UserSettings,
])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Handle migrations here
          if (from < 2) {
            // Example: await m.addColumn(scripts, scripts.newColumn);
          }
        },
      );

  // Script Operations
  Future<List<Script>> getAllScripts({bool includeSynced = true}) {
    return (select(scripts)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .get();
  }

  Future<Script?> getScriptById(String id) {
    return (select(scripts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertScript(ScriptsCompanion script) {
    return into(scripts).insert(script);
  }

  Future<bool> updateScript(String id, ScriptsCompanion script) {
    return (update(scripts)..where((tbl) => tbl.id.equals(id))).write(script);
  }

  Future<int> deleteScript(String id) {
    return (update(scripts)..where((tbl) => tbl.id.equals(id)))
        .write(const ScriptsCompanion(isDeleted: Value(true)));
  }

  Future<List<Script>> getUnsyncedScripts() {
    return (select(scripts)
          ..where((tbl) => tbl.isSynced.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.updatedAt),
          ]))
        .get();
  }

  Future<void> markScriptAsSynced(String id) {
    return (update(scripts)..where((tbl) => tbl.id.equals(id)))
        .write(const ScriptsCompanion(isSynced: Value(true)));
  }

  // Recording Operations
  Future<List<Recording>> getAllRecordings() {
    return (select(recordings)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .get();
  }

  Future<Recording?> getRecordingById(String id) {
    return (select(recordings)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertRecording(RecordingsCompanion recording) {
    return into(recordings).insert(recording);
  }

  Future<bool> updateRecording(String id, RecordingsCompanion recording) {
    return (update(recordings)..where((tbl) => tbl.id.equals(id))).write(recording);
  }

  Future<List<Recording>> getUnsyncedRecordings() {
    return (select(recordings)
          ..where((tbl) => tbl.isSynced.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.createdAt),
          ]))
        .get();
  }

  // Sync Queue Operations
  Future<int> addToSyncQueue(SyncQueueCompanion entry) {
    return into(syncQueue).insert(entry);
  }

  Future<List<SyncQueueData>> getPendingSyncItems() {
    return (select(syncQueue)
          ..where((tbl) => tbl.isProcessed.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.createdAt),
          ]))
        .get();
  }

  Future<void> markSyncItemAsProcessed(int id) {
    return (update(syncQueue)..where((tbl) => tbl.id.equals(id)))
        .write(const SyncQueueCompanion(isProcessed: Value(true)));
  }

  Future<void> incrementSyncRetry(int id) {
    return customUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_attempt_at = ? WHERE id = ?',
      updates: {syncQueue},
      variables: [Variable.withDateTime(DateTime.now()), Variable.withInt(id)],
    );
  }

  Future<void> clearProcessedSyncItems() {
    return (delete(syncQueue)..where((tbl) => tbl.isProcessed.equals(true))).go();
  }

  // Cache Operations
  Future<void> setCache(String key, String value, Duration ttl) {
    final expiresAt = DateTime.now().add(ttl);
    return into(cacheEntries).insert(
      CacheEntriesCompanion(
        key: Value(key),
        value: Value(value),
        expiresAt: Value(expiresAt),
        createdAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<String?> getCache(String key) async {
    final entry = await (select(cacheEntries)..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();

    if (entry == null) return null;

    // Check if expired
    if (entry.expiresAt.isBefore(DateTime.now())) {
      await (delete(cacheEntries)..where((tbl) => tbl.key.equals(key))).go();
      return null;
    }

    return entry.value;
  }

  Future<void> clearExpiredCache() {
    return (delete(cacheEntries)
          ..where((tbl) => tbl.expiresAt.isSmallerThanValue(DateTime.now())))
        .go();
  }

  Future<void> clearAllCache() {
    return delete(cacheEntries).go();
  }

  // User Settings Operations
  Future<UserSetting?> getUserSettings(String userId) {
    return (select(userSettings)..where((tbl) => tbl.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<void> saveUserSettings(UserSettingsCompanion settings) {
    return into(userSettings).insert(
      settings,
      mode: InsertMode.insertOrReplace,
    );
  }

  // Maintenance Operations
  Future<void> cleanupDeletedItems() async {
    // Remove items marked as deleted and synced older than 30 days
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    await (delete(scripts)
          ..where((tbl) =>
              tbl.isDeleted.equals(true) &
              tbl.isSynced.equals(true) &
              tbl.updatedAt.isSmallerThanValue(cutoff)))
        .go();

    await (delete(recordings)
          ..where((tbl) =>
              tbl.isDeleted.equals(true) &
              tbl.isSynced.equals(true) &
              tbl.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> clearAllData() async {
    await delete(scripts).go();
    await delete(recordings).go();
    await delete(syncQueue).go();
    await delete(cacheEntries).go();
    await delete(userSettings).go();
  }

  // Database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final scriptCount = await (select(scripts)
          ..where((tbl) => tbl.isDeleted.equals(false)))
        .get()
        .then((list) => list.length);

    final recordingCount = await (select(recordings)
          ..where((tbl) => tbl.isDeleted.equals(false)))
        .get()
        .then((list) => list.length);

    final pendingSyncCount = await (select(syncQueue)
          ..where((tbl) => tbl.isProcessed.equals(false)))
        .get()
        .then((list) => list.length);

    final cacheEntryCount = await select(cacheEntries).get().then((list) => list.length);

    return {
      'scripts': scriptCount,
      'recordings': recordingCount,
      'pendingSync': pendingSyncCount,
      'cacheEntries': cacheEntryCount,
    };
  }
}

// Helper function to open connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'teleprompter.sqlite'));

    return NativeDatabase.createInBackground(file);
  });
}

// Singleton instance
class DatabaseManager {
  static LocalDatabase? _instance;

  static LocalDatabase get instance {
    _instance ??= LocalDatabase();
    return _instance!;
  }

  static void dispose() {
    _instance?.close();
    _instance = null;
  }
}
