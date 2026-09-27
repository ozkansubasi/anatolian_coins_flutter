import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Widget testlerinde Google haritasının yerel görünümü yok; harita boş bir kutu olarak
/// çizilir, üstteki Flutter katmanları (başlık, kart, lejant, panel) normal test edilir.
class FakeGoogleMapsPlatform extends GoogleMapsFlutterPlatform with MockPlatformInterfaceMixin {
  static void install() => GoogleMapsFlutterPlatform.instance = FakeGoogleMapsPlatform();

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) =>
      const SizedBox.expand();
}
