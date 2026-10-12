import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Widget testlerinde yerel kamera yok; bu sahte platform kameraları anında
/// "açar" ve hangilerinin açık olduğunu sayar (M18: sekme değişince kamera
/// bırakılıyor mu?). Önizleme boş bir kutu olarak çizilir.
class FakeCameraPlatform extends CameraPlatform with MockPlatformInterfaceMixin {
  static FakeCameraPlatform install() {
    final fake = FakeCameraPlatform();
    CameraPlatform.instance = fake;
    return fake;
  }

  static const back = CameraDescription(
      name: 'back', lensDirection: CameraLensDirection.back, sensorOrientation: 90);
  static const front = CameraDescription(
      name: 'front', lensDirection: CameraLensDirection.front, sensorOrientation: 270);

  /// Açık (oluşturulmuş, henüz bırakılmamış) kameralar: kimlik → tanım.
  final open = <int, CameraDescription>{};
  int created = 0;
  int _nextId = 1;
  final _initialized = StreamController<CameraInitializedEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => const [back, front];

  @override
  Future<int> createCameraWithSettings(
      CameraDescription cameraDescription, MediaSettings mediaSettings) async {
    final id = _nextId++;
    open[id] = cameraDescription;
    created++;
    return id;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream.where((e) => e.cameraId == cameraId);

  @override
  Future<void> initializeCamera(int cameraId,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {
    _initialized.add(CameraInitializedEvent(
        cameraId, 1920, 1080, ExposureMode.auto, true, FocusMode.auto, true));
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {}

  @override
  Future<void> setExposureMode(int cameraId, ExposureMode mode) async {}

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 4;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<void> dispose(int cameraId) async => open.remove(cameraId);
}
