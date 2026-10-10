import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage.dart';

/// M17 — oturumsuz deneme hakkı için rastgele kurulum kimliği (UUID v4).
///
/// Donanım kimliği DEĞİL: cihaz hakkında bilgi taşımaz, yalnız oturum yokken tanıma
/// isteğine `X-Device-Id` başlığıyla gider; sunucu ham değeri değil SHA-256 özetini saklar.
/// iOS'ta Keychain'de durduğu için uygulama silinip kurulunca da korunur; Android'de
/// kaldırınca silinir (sunucudaki IP tavanı deneme hakkının bu yolla katlanmasını sınırlar).
class InstallId {
  static const storageKey = 'anon_install_id';

  static final _uuidV4 =
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  static bool isValid(String? value) => value != null && _uuidV4.hasMatch(value);

  /// Kayıtlı kimliği döndürür; yoksa (ya da bozuksa) üretip kaydeder.
  static Future<String> get({
    Future<String?> Function(String key) read = SecureStore.read,
    Future<void> Function(String key, String value) write = SecureStore.write,
    Random? random,
  }) async {
    final saved = await read(storageKey);
    if (isValid(saved)) return saved!;
    final id = generate(random ?? Random.secure());
    await write(storageKey, id);
    return id;
  }

  /// RFC 4122 sürüm 4 (rastgele) UUID, küçük harf.
  static String generate(Random random) {
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // sürüm 4
    b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 varyantı
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}

/// Kurulum kimliği bir kez okunur/üretilir ve uygulama ömrü boyunca önbellekte kalır.
final installIdProvider = FutureProvider<String>((ref) => InstallId.get());
