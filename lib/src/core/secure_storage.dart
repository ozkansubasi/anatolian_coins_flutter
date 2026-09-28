import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _storage = FlutterSecureStorage();

  static Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  static Future<void> delete(String key) => _storage.delete(key: key);

  /// Android otomatik yedeği şifreli değerleri yeni kuruluma geri yükler, ama onları çözen
  /// Keystore anahtarı kaldırmayla silinmiştir → BAD_DECRYPT (Redmi, 2026-09-28: açılışta oturum
  /// yüklemesi patlıyor, giriş düğmesi dönüp duruyordu). Bu değerler kurtarılamaz: depo temizlenir,
  /// kullanıcı yeniden giriş yapar. Şifreleme dışı hatalar olduğu gibi fırlatılır.
  static Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      final detail = '${e.message} ${e.details}';
      if (!detail.contains('javax.crypto') && !detail.contains('BAD_DECRYPT')) rethrow;
      debugPrint('[SecureStore] unreadable (restored backup?), resetting: ${e.message}');
      await _storage.deleteAll();
      return null;
    }
  }
}
