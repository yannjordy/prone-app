import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class SecurityService {
  static final SecurityService _instance = SecurityService._();
  factory SecurityService() => _instance;
  SecurityService._();

  static const _key = 'Prone2024SecureKey!';
  static const _iv = 'ProneIV2024!';

  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    final keyBytes = utf8.encode(_key);
    final ivBytes = utf8.encode(_iv);
    final textBytes = utf8.encode(plainText);
    final encrypted = Uint8List(textBytes.length);
    for (var i = 0; i < textBytes.length; i++) {
      encrypted[i] = textBytes[i] ^ keyBytes[i % keyBytes.length] ^ ivBytes[i % ivBytes.length];
    }
    return base64.encode(encrypted);
  }

  String decrypt(String cipherText) {
    if (cipherText.isEmpty) return '';
    try {
      final keyBytes = utf8.encode(_key);
      final ivBytes = utf8.encode(_iv);
      final encrypted = base64.decode(cipherText);
      final decrypted = Uint8List(encrypted.length);
      for (var i = 0; i < encrypted.length; i++) {
        decrypted[i] = encrypted[i] ^ keyBytes[i % keyBytes.length] ^ ivBytes[i % ivBytes.length];
      }
      return utf8.decode(decrypted);
    } catch (e) {
      return cipherText;
    }
  }

  String hashPassword(String password) {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final saltHex = salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    var hash = 0;
    for (var i = 0; i < password.length; i++) {
      hash = ((hash << 5) - hash + password.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    final hashHex = (hash & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return '$saltHex:$hashHex';
  }

  bool verifyPassword(String password, String stored) {
    return hashPassword(password) == stored;
  }

  String generateApiKey() {
    final random = Random.secure();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final prefix = 'cf_';
    final key = List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
    return '$prefix$key';
  }

  String generateWebhookSecret() {
    final random = Random.secure();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final prefix = 'whsec_';
    final secret = List.generate(40, (_) => chars[random.nextInt(chars.length)]).join();
    return '$prefix$secret';
  }
}
