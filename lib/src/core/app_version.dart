import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Kurulu uygulamanın sürümü: "0.6.0 (5)". Kaynak pubspec `version:`
/// (derlemede pakete gömülür) — elle yazılan sürüm her sürümde unutuluyordu
/// (ayarlarda 0.6.0'da hâlâ "0.4.0" yazıyordu, 2026-09-26 cihaz testi).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
});
