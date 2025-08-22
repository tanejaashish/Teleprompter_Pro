// packages/core/lib/security/encryption_service.dart
class EncryptionService {
  Future<String> encryptData(String plainText);
  Future<String> decryptData(String encryptedText);
  Future<KeyPair> generateKeyPair();
  Future<void> storeSecureKey(String key, String value);
}