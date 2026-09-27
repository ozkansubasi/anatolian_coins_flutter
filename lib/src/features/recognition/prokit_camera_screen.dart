import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../core/navigation.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'capture_processing.dart';
import 'recognition_service.dart';

/// `compute` giriş noktası (üst düzey olmalı): [bytes, sideFraction] → kırpılmış JPEG + netlik.
ProcessedCapture _processCaptureEntry(List<Object> args) =>
    processCaptureBytes(args[0] as Uint8List, args[1] as double);

/// ProKit-styled camera screen for coin scanning
/// Modern dark theme with gradient accents and improved UX
class ProkitCameraScreen extends ConsumerStatefulWidget {
  const ProkitCameraScreen({super.key});

  @override
  ConsumerState<ProkitCameraScreen> createState() => _ProkitCameraScreenState();
}

class _ProkitCameraScreenState extends ConsumerState<ProkitCameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  String? _error;
  late AnimationController _pulseController;

  // Two-sided capture state
  String? _obversePath;
  String? _reversePath;
  bool _capturingReverse = false;

  // Odak / yakınlaştırma (2026-09-28: çember doldurulmaya çalışılınca telefon odak mesafesinin
  // altına iniyor, fotoğraf bulanıklaşıyordu → ~10 cm'de dur, yakınlaştır, dokunarak netle).
  static const _circleFraction = 0.45; // çember çapı / önizleme genişliği
  static const _defaultZoom = 2.0;

  /// Bu değerin altındaki Laplace varyansı "bulanık" sayılır (cihazda ölçülerek ayarlandı).
  static const _blurThreshold = 80.0;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _scaleStartZoom = 1;
  Offset? _focusTap;
  Timer? _focusTimer;
  Size _boxSize = Size.zero;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initializeCamera();
    Future.microtask(() => ref.refresh(scanQuotaProvider));
  }

  bool get _canProceed => _obversePath != null && _reversePath != null;

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _error = 'no_camera';
          _isInitializing = false;
        });
        return;
      }

      final camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      await _startController(camera);

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'camera_error';
        _isInitializing = false;
      });
    }
  }

  /// En yüksek çözünürlük + sürekli otomatik odak + varsayılan 2x yakınlaştırma.
  Future<void> _startController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    _controller = controller;
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('[Camera] focus/exposure mode unsupported: $e');
    }
    try {
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _zoom = _defaultZoom.clamp(_minZoom, _maxZoom).toDouble();
      await controller.setZoomLevel(_zoom);
    } catch (e) {
      debugPrint('[Camera] zoom unsupported: $e');
      _minZoom = _maxZoom = _zoom = 1;
    }
  }

  Future<void> _setZoom(double value) async {
    final c = _controller;
    if (c == null) return;
    final z = value.clamp(_minZoom, _maxZoom).toDouble();
    if ((z - _zoom).abs() < 0.01) return;
    setState(() => _zoom = z);
    try {
      await c.setZoomLevel(z);
    } catch (_) {}
  }

  /// Kutudaki dokunuşu önizleme karesine (cover) çevirip odak + pozlama noktası yapar.
  Future<void> _focusAt(Offset local) async {
    final c = _controller;
    final ps = c?.value.previewSize;
    if (c == null || ps == null || _boxSize.isEmpty) return;
    final fw = ps.height; // dikey kare
    final fh = ps.width;
    final scale = math.max(_boxSize.width / fw, _boxSize.height / fh);
    final ox = (fw * scale - _boxSize.width) / 2;
    final oy = (fh * scale - _boxSize.height) / 2;
    final p = Offset(
      ((local.dx + ox) / (fw * scale)).clamp(0.0, 1.0),
      ((local.dy + oy) / (fh * scale)).clamp(0.0, 1.0),
    );
    setState(() => _focusTap = local);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusTap = null);
    });
    try {
      await c.setFocusPoint(p);
      await c.setExposurePoint(p);
    } catch (e) {
      debugPrint('[Camera] focus point unsupported: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _processing) return;

    if (_obversePath == null && !await _checkQuota()) return;

    setState(() => _processing = true);
    try {
      final image = await _controller!.takePicture();
      final prepared = await _prepareCapture(image.path);
      if (!mounted) return;
      setState(() => _processing = false);

      if (prepared.sharpness != null && prepared.sharpness! < _blurThreshold) {
        final useAnyway = await _confirmBlurry();
        if (!mounted || useAnyway != true) return;
      }

      if (_obversePath == null) {
        setState(() {
          _obversePath = prepared.path;
          _capturingReverse = true;
        });
      } else if (_reversePath == null) {
        setState(() {
          _reversePath = prepared.path;
          _capturingReverse = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        final l10n = AppLocalizations.of(context);
        toast(l10n.translate('capture_failed', params: {'error': e.toString()}));
      }
    }
  }

  /// Tam kareden çember bölgesini kırpar ve netliği ölçer. İşlenemezse özgün dosya kullanılır.
  Future<({String path, double? sharpness})> _prepareCapture(String path) async {
    try {
      final ps = _controller?.value.previewSize;
      final fraction = (ps == null || _boxSize.isEmpty)
          ? 0.7
          : cropSideFraction(
              circleDiameter: _boxSize.width * _circleFraction,
              boxWidth: _boxSize.width,
              boxHeight: _boxSize.height,
              frameWidth: ps.height,
              frameHeight: ps.width,
            );
      // Yerel sıkıştırıcı hızlıca ~2000 px'e indirir ve EXIF yönünü uygular.
      final reduced = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 2000,
        minHeight: 2000,
        quality: 95,
        autoCorrectionAngle: true,
      );
      if (reduced == null) return (path: path, sharpness: null);
      final r = await compute(_processCaptureEntry, <Object>[reduced, fraction]);
      final out = File('${Directory.systemTemp.path}/coin_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(r.jpeg, flush: true);
      debugPrint('[Camera] crop fraction=${fraction.toStringAsFixed(3)} side=${r.side} '
          'sharpness=${r.sharpness.toStringAsFixed(1)} zoom=${_zoom.toStringAsFixed(1)}');
      return (path: out.path, sharpness: r.sharpness);
    } catch (e) {
      debugPrint('[Camera] capture processing failed, using original: $e');
      return (path: path, sharpness: null);
    }
  }

  Future<bool?> _confirmBlurry() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: numCardDark,
        shape: RoundedRectangleBorder(borderRadius: radius(16)),
        title: Text(l10n.translate('photo_blurry_title'), style: boldTextStyle(size: 16, color: white)),
        content: Text(
          l10n.translate('photo_blurry_message'),
          style: secondaryTextStyle(size: 14, color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.translate('use_anyway'), style: secondaryTextStyle(color: numTextHint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimaryLight,
              foregroundColor: numTextPrimary,
              shape: RoundedRectangleBorder(borderRadius: radius(8)),
            ),
            child: Text(l10n.translate('retake_photo')),
          ),
        ],
      ),
    );
  }

  void _proceedToPreview() {
    if (_canProceed) {
      context.push('/recognition/preview', extra: {
        'obverse': _obversePath!,
        'reverse': _reversePath!,
      });

      setState(() {
        _obversePath = null;
        _reversePath = null;
        _capturingReverse = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (!await _checkQuota()) return;

    final picker = ImagePicker();

    try {
      if (_obversePath == null) {
        final XFile? obverseImage = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2000,
          maxHeight: 2000,
          requestFullMetadata: true,
        );

        if (obverseImage != null && mounted) {
          setState(() {
            _obversePath = obverseImage.path;
            _capturingReverse = true;
          });
        }
      } else if (_reversePath == null) {
        final XFile? reverseImage = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2000,
          maxHeight: 2000,
          requestFullMetadata: true,
        );

        if (reverseImage != null && mounted) {
          setState(() {
            _reversePath = reverseImage.path;
            _capturingReverse = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        toast(l10n.translate('pick_failed', params: {'error': e.toString()}));
      }
    }
  }

  Future<bool> _checkQuota() async {
    final quotaAsync = ref.read(scanQuotaProvider);

    return quotaAsync.when(
      data: (quota) {
        if (!quota.hasScansAvailable) {
          _showQuotaExceededDialog(quota);
          return false;
        }
        return true;
      },
      loading: () => true,
      error: (error, stack) {
        debugPrint('Quota check error: $error');
        return true;
      },
    );
  }

  void _showQuotaExceededDialog(ScanQuota quota) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: numCardDark,
        shape: RoundedRectangleBorder(borderRadius: radius(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            ),
            12.width,
            Expanded(
              child: Text(
                l10n.translate('scan_limit_reached'),
                style: boldTextStyle(size: 16, color: white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('used_all_scans', params: {'limit': quota.limit.toString()}),
              style: secondaryTextStyle(size: 14, color: Colors.grey[400]),
            ),
            16.height,
            Container(
              padding: const EdgeInsets.all(16),
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: numSurfaceDark,
                borderRadius: radius(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('upgrade_benefits'),
                    style: boldTextStyle(size: 14, color: numPrimaryLight),
                  ),
                  12.height,
                  _buildBenefitRow(Icons.all_inclusive, l10n.translate('unlimited_scans')),
                  8.height,
                  _buildBenefitRow(Icons.offline_bolt, l10n.translate('offline_access')),
                  8.height,
                  _buildBenefitRow(Icons.high_quality, l10n.translate('high_res_images')),
                  8.height,
                  _buildBenefitRow(Icons.auto_awesome, l10n.translate('advanced_recognition')),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            // Diyalog her temada koyu (numCardDark); nb_utils varsayılan grisi
            // (#757575) bu zeminde okunmuyordu.
            child: Text(l10n.translate('close'), style: secondaryTextStyle(color: numTextHint)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimaryLight,
              foregroundColor: numTextPrimary,
              shape: RoundedRectangleBorder(borderRadius: radius(8)),
            ),
            child: Text(l10n.translate('upgrade_to_pro')),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: numSuccess),
        8.width,
        Expanded(
          child: Text(text, style: primaryTextStyle(size: 12, color: Colors.grey[300])),
        ),
      ],
    );
  }

  void _clearObverse() {
    setState(() {
      _obversePath = null;
      if (_reversePath == null) {
        _capturingReverse = false;
      }
    });
  }

  void _clearReverse() {
    setState(() {
      _reversePath = null;
      _capturingReverse = true;
    });
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentCamera = _controller!.description;
    final currentIndex = _cameras!.indexOf(currentCamera);
    final nextIndex = (currentIndex + 1) % _cameras!.length;

    await _controller?.dispose();

    setState(() {
      _isInitializing = true;
    });

    try {
      await _startController(_cameras![nextIndex]);

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      setState(() {
        debugPrint('Failed to switch camera: $e');
        _error = 'camera_error';
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _controller?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: numScaffoldDark,
      body: SafeArea(
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: numPrimaryLight),
            16.height,
            Text(
              l10n.translate('initializing_camera'),
              style: secondaryTextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: numError.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 64, color: numError),
              ),
              24.height,
              Text(
                l10n.translate(_error!),
                style: boldTextStyle(size: 18, color: white),
                textAlign: TextAlign.center,
              ),
              16.height,
              AppButton(
                text: l10n.translate('go_back'),
                textStyle: boldTextStyle(color: numTextPrimary),
                color: numPrimaryLight,
                shapeBorder: RoundedRectangleBorder(borderRadius: radius(12)),
                onTap: () => context.popOrGoHome(),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Text(
          l10n.translate('camera_not_available'),
          style: secondaryTextStyle(color: Colors.grey[400]),
        ),
      );
    }

    return Column(
      children: [
        // Header
        _buildHeader(l10n),

        // Camera Preview
        Expanded(
          child: _buildCameraPreview(l10n),
        ),

        // Image Slots & Controls
        _buildBottomControls(l10n),
      ],
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.popOrGoHome(),
            icon: const Icon(Icons.arrow_back_ios, color: white),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  l10n.translate('scan_coin'),
                  style: boldTextStyle(size: 18, color: white),
                ),
                4.height,
                Text(
                  _capturingReverse
                      ? l10n.translate('capture_reverse')
                      : l10n.translate('capture_obverse'),
                  style: secondaryTextStyle(size: 12, color: numPrimaryLight),
                ),
              ],
            ),
          ),
          // Quota indicator
          Consumer(
            builder: (context, ref, _) {
              final quotaAsync = ref.watch(scanQuotaProvider);
              return quotaAsync.when(
                data: (quota) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: boxDecorationWithRoundedCorners(
                    backgroundColor: quota.hasScansAvailable
                        ? numSuccess.withOpacity(0.2)
                        : numError.withOpacity(0.2),
                    borderRadius: radius(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        size: 14,
                        color: quota.hasScansAvailable ? numSuccess : numError,
                      ),
                      4.width,
                      Text(
                        // limit < 0 = Pro (kotasız). Ham "-1/-1" basılıyordu;
                        // "sınırsız" kelimesi K2 kararıyla kullanılmıyor.
                        quota.limit < 0 ? 'Pro' : '${quota.remaining}/${quota.limit}',
                        style: boldTextStyle(
                          size: 12,
                          color: quota.hasScansAvailable ? numSuccess : numError,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(width: 60, height: 28),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Önizleme kutuyu gerilmeden doldurur (cover); çember kutunun genişliğine oranlıdır.
  /// Dokun → odak, iki parmak → yakınlaştırma; 1x/2x/3x düğmeleri.
  Widget _buildCameraPreview(AppLocalizations l10n) {
    final ps = _controller!.value.previewSize;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, constraints) {
        _boxSize = constraints.biggest;
        final circle = _boxSize.width * _circleFraction;
        return ClipRRect(
          borderRadius: radius(24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Önizleme (cover): dikey karede genişlik = previewSize.height
              Positioned.fill(
                child: ps == null
                    ? CameraPreview(_controller!)
                    : FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: ps.height,
                          height: ps.width,
                          child: CameraPreview(_controller!),
                        ),
                      ),
              ),

              // Dokunma / yakınlaştırma katmanı
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _focusAt(d.localPosition),
                  onScaleStart: (_) => _scaleStartZoom = _zoom,
                  onScaleUpdate: (d) {
                    if (d.pointerCount >= 2) _setZoom(_scaleStartZoom * d.scale);
                  },
                ),
              ),

              // Kılavuz çember
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: circle + (_pulseController.value * 6),
                      height: circle + (_pulseController.value * 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: numPrimaryLight.withOpacity(0.5 + (_pulseController.value * 0.3)),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Köşe kılavuzları
              IgnorePointer(
                child: SizedBox(
                  width: circle + 24,
                  height: circle + 24,
                  child: CustomPaint(
                    painter: _CornerGuidePainter(color: numPrimaryLight),
                  ),
                ),
              ),

              // Odak göstergesi
              if (_focusTap != null)
                Positioned(
                  left: _focusTap!.dx - 28,
                  top: _focusTap!.dy - 28,
                  child: IgnorePointer(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: numPrimaryLight, width: 2),
                        borderRadius: radius(8),
                      ),
                    ),
                  ),
                ),

              // Yakınlaştırma düğmeleri + ipucu
              Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_maxZoom > _minZoom) _buildZoomChips(),
                    10.height,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: black.withOpacity(0.7),
                        borderRadius: radius(20),
                      ),
                      child: Text(
                        l10n.translate('camera_hint_distance'),
                        textAlign: TextAlign.center,
                        style: secondaryTextStyle(size: 12, color: white),
                      ),
                    ),
                  ],
                ),
              ),

              // Kamera değiştirme
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _cameras != null && _cameras!.length > 1 ? _switchCamera : null,
                    icon: const Icon(Icons.flip_camera_ios, color: white),
                  ),
                ),
              ),

              // Çekim işleniyor
              if (_processing)
                Positioned.fill(
                  child: Container(
                    color: black.withOpacity(0.35),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: numPrimaryLight),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildZoomChips() {
    final levels = <double>[1, 2, 3].where((z) => z >= _minZoom - 0.01 && z <= _maxZoom + 0.01).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final z in levels)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _setZoom(z),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_zoom - z).abs() < 0.25 ? numPrimaryLight : black.withOpacity(0.55),
                ),
                child: Text(
                  '${z.toStringAsFixed(0)}x',
                  style: boldTextStyle(
                    size: 13,
                    color: (_zoom - z).abs() < 0.25 ? numTextPrimary : white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomControls(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: numCardDark,
        borderRadius: radiusOnly(topLeft: 24, topRight: 24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image slots row
          Row(
            children: [
              Expanded(
                child: _buildImageSlot(
                  imagePath: _obversePath,
                  label: l10n.translate('obverse'),
                  icon: Icons.looks_one,
                  isActive: !_capturingReverse && _obversePath == null,
                  onClear: _obversePath != null ? _clearObverse : null,
                ),
              ),
              16.width,
              Expanded(
                child: _buildImageSlot(
                  imagePath: _reversePath,
                  label: l10n.translate('reverse'),
                  icon: Icons.looks_two,
                  isActive: _capturingReverse && _reversePath == null,
                  onClear: _reversePath != null ? _clearReverse : null,
                ),
              ),
            ],
          ),

          24.height,

          // Camera controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery button
              _buildControlButton(
                icon: Icons.photo_library_rounded,
                onTap: _pickFromGallery,
                size: 52,
              ),

              // Capture button
              GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: numPrimaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: numPrimary.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt, color: white, size: 28),
                  ),
                ),
              ),

              // Placeholder or proceed button
              _canProceed
                  ? _buildControlButton(
                      icon: Icons.arrow_forward_rounded,
                      onTap: _proceedToPreview,
                      size: 52,
                      color: numSuccess,
                    )
                  : const SizedBox(width: 52),
            ],
          ),

          16.height,

          // Identify button (full width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceed ? _proceedToPreview : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canProceed ? numPrimaryLight : numSurfaceDark,
                foregroundColor: _canProceed ? numTextPrimary : Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: radius(12)),
                elevation: _canProceed ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 22,
                    color: _canProceed ? numTextPrimary : Colors.grey[600],
                  ),
                  8.width,
                  Text(
                    l10n.translate('identify_coin'),
                    style: boldTextStyle(
                      size: 16,
                      color: _canProceed ? numTextPrimary : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSlot({
    required String? imagePath,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback? onClear,
  }) {
    return Container(
      height: 100,
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: numSurfaceDark,
        borderRadius: radius(12),
        border: Border.all(
          color: isActive ? numPrimaryLight : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          if (imagePath != null)
            ClipRRect(
              borderRadius: radius(10),
              child: Image.file(
                File(imagePath),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: isActive ? numPrimaryLight : Colors.grey[600],
                  ),
                  8.height,
                  Text(
                    label,
                    style: secondaryTextStyle(
                      size: 12,
                      color: isActive ? numPrimaryLight : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

          // Status indicator
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: imagePath != null
                    ? numSuccess.withOpacity(0.9)
                    : (isActive ? numPrimaryLight.withOpacity(0.9) : black.withOpacity(0.6)),
                borderRadius: radius(4),
              ),
              child: Text(
                label,
                style: boldTextStyle(size: 10, color: white),
              ),
            ),
          ),

          // Clear button
          if (onClear != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: numError.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: white, size: 16),
                ),
              ),
            ),

          // Check mark when image is captured
          if (imagePath != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: numSuccess,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: white, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? numSurfaceDark,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Icon(icon, color: white, size: size * 0.45),
      ),
    );
  }
}

/// Custom painter for corner guides
class _CornerGuidePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;

  _CornerGuidePainter({
    required this.color,
    this.strokeWidth = 3,
    this.cornerLength = 30,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawLine(Offset(0, cornerLength), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(cornerLength, 0), paint);

    // Top-right corner
    canvas.drawLine(Offset(size.width - cornerLength, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(0, size.height - cornerLength), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);

    // Bottom-right corner
    canvas.drawLine(
        Offset(size.width, size.height - cornerLength), Offset(size.width, size.height), paint);
    canvas.drawLine(
        Offset(size.width - cornerLength, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
