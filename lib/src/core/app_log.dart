/// Hata günlüğü: `[NumisTR][KATEGORİ] mesaj`.
///
/// Cihazda izleme: `adb logcat -s flutter | grep NumisTR`. `debugPrint`
/// release'de susturulduğu için (main.dart) hata satırları bilerek `print`
/// ile yazılır — Play test sürümünde de görünsünler. Kişisel veri, jeton,
/// e-posta YAZILMAZ: yalnız yol, durum kodu, sunucu hata metni, istisna türü.
///
/// Kategoriler: HTTP (başarısız API isteği), UI (widget hatası), UNCAUGHT
/// (yakalanmamış istisna), NAV (ekran geçişi).
void appLog(String category, String message) {
  // ignore: avoid_print
  print('[NumisTR][$category] $message');
}
