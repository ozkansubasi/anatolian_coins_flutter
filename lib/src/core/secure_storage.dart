import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _storage = FlutterSecureStorage();

  static Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  static Future<String?> read(String key) => _storage.read(key: key);
  static Future<void> delete(String key) => _storage.delete(key: key);
}
