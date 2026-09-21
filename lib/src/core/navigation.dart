import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension NumNavigation on BuildContext {
  /// Ekrandaki geri okları için: geri gidilecek sayfa varsa döner, yoksa Ana Sayfa.
  ///
  /// StatefulShellRoute'ta (2026-09-21) sekme kökündeki bir ekranın (ör. Tara →
  /// kamera) altında sayfa yoktur; düz `pop()` orada hiçbir şey yapmaz ve buton
  /// ölü kalır (cihazda görüldü). Eskiden her rota `/`'nin çocuğu olduğu için
  /// pop hep Ana Sayfa'ya düşüyordu; bu yardımcı o davranışı korur.
  void popOrGoHome() => canPop() ? pop() : go('/');
}
