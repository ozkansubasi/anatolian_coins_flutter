import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../core/navigation.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'recognition_service.dart';

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

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

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

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_obversePath == null && !await _checkQuota()) return;

    try {
      final image = await _controller!.takePicture();

      if (mounted) {
        if (_obversePath == null) {
          setState(() {
            _obversePath = image.path;
            _capturingReverse = true;
          });
        } else if (_reversePath == null) {
          setState(() {
            _reversePath = image.path;
            _capturingReverse = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        toast(l10n.translate('capture_failed', params: {'error': e.toString()}));
      }
    }
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
      _controller = CameraController(
        _cameras![nextIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to switch camera: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
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
                        '${quota.remaining}/${quota.limit}',
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

  Widget _buildCameraPreview(AppLocalizations l10n) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera Preview
        Container(
          margin: const EdgeInsets.all(16),
          decoration: boxDecorationWithRoundedCorners(
            borderRadius: radius(24),
          ),
          child: ClipRRect(
            borderRadius: radius(24),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: CameraPreview(_controller!),
            ),
          ),
        ),

        // Circular guide overlay with animation
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 220 + (_pulseController.value * 10),
              height: 220 + (_pulseController.value * 10),
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

        // Corner guides
        Positioned(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: radius(16),
            ),
            child: CustomPaint(
              painter: _CornerGuidePainter(color: numPrimaryLight),
            ),
          ),
        ),

        // Instruction text
        Positioned(
          bottom: 32,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: boxDecorationWithRoundedCorners(
              backgroundColor: black.withOpacity(0.7),
              borderRadius: radius(20),
            ),
            child: Text(
              l10n.translate('place_coin_in_circle'),
              style: secondaryTextStyle(size: 12, color: white),
            ),
          ),
        ),

        // Camera switch button
        Positioned(
          top: 24,
          right: 24,
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
