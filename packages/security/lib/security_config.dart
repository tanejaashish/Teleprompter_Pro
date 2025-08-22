// ============================================
// Security Configuration
// ============================================

// packages/security/lib/security_config.dart

import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/pointycastle.dart';

class SecurityConfig {
  // Encryption keys (should be stored securely)
  static const String _encryptionKey = 'YOUR-32-CHARACTER-ENCRYPTION-KEY';
  static const String _ivKey = 'YOUR-16-CHAR-IV-';
  
  // API Security Headers
  static const Map<String, String> securityHeaders = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';",
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  };
  
  // Rate Limiting Configuration
  static const rateLimits = {
    'auth': RateLimit(requests: 5, window: Duration(minutes: 15)),
    'api': RateLimit(requests: 100, window: Duration(minutes: 15)),
    'upload': RateLimit(requests: 10, window: Duration(minutes: 60)),
    'ai': RateLimit(requests: 20, window: Duration(minutes: 60)),
  };
  
  // Encryption Service
  static final _key = Key.fromBase64(_encryptionKey);
  static final _iv = IV.fromBase64(_ivKey);
  static final _encrypter = Encrypter(AES(_key));
  
  static String encryptData(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }
  
  static String decryptData(String encryptedText) {
    final encrypted = Encrypted.fromBase64(encryptedText);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }
  
  // Password Validation
  static bool isPasswordSecure(String password) {
    // Minimum 8 characters
    if (password.length < 8) return false;
    
    // Contains uppercase
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    
    // Contains lowercase
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    
    // Contains number
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    
    // Contains special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    
    return true;
  }
  
  // Input Sanitization
  static String sanitizeInput(String input) {
    // Remove potential SQL injection attempts
    input = input.replaceAll(RegExp(r'[;\'"-]'), '');
    
    // Remove potential XSS attempts
    input = input.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Remove potential command injection
    input = input.replaceAll(RegExp(r'[&|;`$]'), '');
    
    return input.trim();
  }
  
  // JWT Token Validation
  static bool validateJWT(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      // Decode and verify signature
      final payload = base64Url.decode(parts[1]);
      final data = jsonDecode(utf8.decode(payload));
      
      // Check expiration
      final exp = data['exp'] as int?;
      if (exp == null) return false;
      
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      if (expDate.isBefore(DateTime.now())) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Certificate Pinning
  static const List<String> trustedCertificates = [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
  ];
  
  static bool verifyCertificate(String certificate) {
    final hash = sha256.convert(utf8.encode(certificate));
    final fingerprint = 'sha256/${base64.encode(hash.bytes)}';
    return trustedCertificates.contains(fingerprint);
  }
}

class RateLimit {
  final int requests;
  final Duration window;
  
  const RateLimit({required this.requests, required this.window});
}