// packages/core/lib/storage/unified_storage.dart
abstract class UnifiedStorage {
  Future<void> save(String key, dynamic value);
  Future<T?> get<T>(String key);
  Future<void> delete(String key);
  Future<void> clear();
  Stream<StorageChange> watch(String key);
}