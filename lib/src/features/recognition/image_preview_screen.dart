import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Preview screen for captured/selected image
/// Allows basic editing (crop/rotate) before uploading
class ImagePreviewScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const ImagePreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  ConsumerState<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends ConsumerState<ImagePreviewScreen> {
  late File _imageFile;
  int _rotation = 0; // 0, 90, 180, 270
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
  }

  Future<void> _rotateImage() async {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
  }

  Future<File?> _compressImage() async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        _imageFile.absolute.path,
        targetPath,
        quality: 85,
        rotate: _rotation,
        minWidth: 800,
        minHeight: 800,
      );

      if (result == null) return null;

      return File(result.path);
    } catch (e) {
      debugPrint('Failed to compress image: $e');
      return null;
    }
  }

  Future<void> _uploadAndRecognize() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Compress and rotate image
      final compressedFile = await _compressImage();

      if (compressedFile == null) {
        throw Exception('Failed to process image');
      }

      // Check file size (target: <2MB)
      final fileSize = await compressedFile.length();
      debugPrint('Compressed image size: ${fileSize / 1024 / 1024} MB');

      if (fileSize > 2 * 1024 * 1024) {
        throw Exception('Image is too large (max 2MB)');
      }

      if (mounted) {
        // Navigate to recognition results screen
        // Pass the compressed file path
        context.push('/recognition/results', extra: compressedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isProcessing ? null : _rotateImage,
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate',
          ),
        ],
      ),
      body: Column(
        children: [
          // Image preview
          Expanded(
            child: Center(
              child: _imageFile.existsSync()
                  ? RotatedBox(
                      quarterTurns: _rotation ~/ 90,
                      child: Image.file(
                        _imageFile,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Text('Image not found'),
            ),
          ),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tips for better results:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildTip('Place coin on plain background'),
                _buildTip('Ensure good lighting'),
                _buildTip('Keep coin centered and flat'),
                _buildTip('Avoid shadows and reflections'),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _uploadAndRecognize,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _isProcessing ? 'Processing...' : 'Identify Coin',
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : () => context.pop(),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(
                      'Retake Photo',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
