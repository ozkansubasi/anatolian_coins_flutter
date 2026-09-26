import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension NumNavigation on BuildContext {
  /// Ekrandaki geri okları için: geri gidilecek sayfa varsa döner, yoksa Ana Sayfa.
  ///
  /// StatefulShellRoute'ta (2026-09-21) sekme kökündeki bir ekranın (ör. Tara →
  /// kamera) altında sayfa yoktur; düz `pop()` orada hiçbir şey yapmaz ve buton
  /// ölü kalır (cihazda görüldü). Eskiden her rota `/`'nin çocuğu olduğu için
  /// pop hep Ana Sayfa'ya düşüyordu; bu yardımcı o davranışı korur.
  void popOrGoHome() => canPop() ? pop() : go(returnLocation ?? '/');

  /// `openRoute` bir ekranı başka sekmede `go` ile açtığında geldiği adres
  /// (`from` sorgu parametresi). Yalnız uygulama içi yol kabul edilir.
  String? get returnLocation {
    final from = GoRouterState.of(this).uri.queryParameters['from'];
    return (from != null && from.startsWith('/') && !from.startsWith('//')) ? from : null;
  }

  /// Başlık çubuğu için geri ikonu. Yığında sayfa varsa `null` (AppBar kendi
  /// geri okunu koyar); sekme kökünde açılmış ama başka yerden gelinmişse o
  /// yere dönen ok. Neden: Ana Sayfa'dan açılan makale ve Bölgeler'den açılan
  /// bölge listesi kendi sekmelerinin kökünde açılıyor, geri oku yoktu
  /// (2026-09-26 cihaz testi).
  Widget? get returnLeading {
    if (canPop()) return null;
    final to = returnLocation;
    if (to == null) return null;
    return BackButton(onPressed: () => go(to));
  }
}
