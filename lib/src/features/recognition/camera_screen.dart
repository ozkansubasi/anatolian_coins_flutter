import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'recognition_service.dart';

/// Camera screen for coin scanning
/// Allows capturing photo with camera or selecting from gallery
/// Shows quota information and enforces scan limits
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Load quota on screen init
    Future.microtask(() => ref.refresh(scanQuotaProvider));
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _error = 'No camera found on this device';
          _isInitializing = false;
        });
        return;
      }

      // Use back camera by default
      final camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      // Initialize controller
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
        _error = 'Failed to initialize camera: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    // Check quota before capture
    if (!await _checkQuota()) {
      return;
    }

    try {
      final image = await _controller!.takePicture();

      if (mounted) {
        // Navigate to preview screen
        context.push('/recognition/preview', extra: image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    // Check quota before gallery pick
    if (!await _checkQuota()) {
      return;
    }

    final picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image != null && mounted) {
        context.push('/recognition/preview', extra: image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  /// Check if user has scans available
  /// Returns true if can proceed, false if quota exceeded
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
      loading: () {
        // Allow scan if quota is still loading (fail open)
        return true;
      },
      error: (error, stack) {
        // Allow scan if quota check failed (fail open)
        print('Quota check error: $error');
        return true;
      },
    );
  }

  void _showQuotaExceededDialog(ScanQuota quota) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Scan Limit Reached'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have used all ${quota.limit} free scans for this month.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (quota.resetDate != null) ...[
              Text(
                'Resets on: ${_formatResetDate(quota.resetDate!)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Upgrade to Pro for:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text('✓ Unlimited scans', style: TextStyle(fontSize: 14)),
            const Text('✓ Offline database access', style: TextStyle(fontSize: 14)),
            const Text('✓ High-resolution images', style: TextStyle(fontSize: 14)),
            const Text('✓ Advanced recognition', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }

  String _formatResetDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    // Get current camera index
    final currentCamera = _controller!.description;
    final currentIndex = _cameras!.indexOf(currentCamera);
    final nextIndex = (currentIndex + 1) % _cameras!.length;

    // Dispose current controller
    await _controller?.dispose();

    // Initialize new controller
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Coin'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Text('Camera not available', style: TextStyle(color: Colors.white)),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),
        ),

        // Overlay with crosshair/guide
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(125),
            ),
            child: Center(
              child: Icon(
                Icons.circle_outlined,
                size: 200,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ),

        // Quota display and instructions
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Quota info
              Consumer(
                builder: (context, ref, child) {
                  final quotaAsync = ref.watch(scanQuotaProvider);

                  return quotaAsync.when(
                    data: (quota) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: quota.hasScansAvailable
                            ? Colors.green.withOpacity(0.8)
                            : Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            quota.isPro ? Icons.star : Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            quota.isPro
                                ? 'Pro: Unlimited scans'
                                : 'Free: ${quota.remaining}/${quota.limit} scans left',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Instructions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Center the coin in the circle',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Controls at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                IconButton(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  iconSize: 32,
                ),

                // Capture button
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Switch camera button
                IconButton(
                  onPressed: _cameras != null && _cameras!.length > 1
                      ? _switchCamera
                      : null,
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                  iconSize: 32,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
