import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:nb_utils/nb_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';

/// ProKit-styled preview screen for captured/selected image(s)
/// Modern card-based layout with gradient accents
class ProkitImagePreviewScreen extends ConsumerStatefulWidget {
  final dynamic imageData;

  const ProkitImagePreviewScreen({
    super.key,
    required this.imageData,
  });

  @override
  ConsumerState<ProkitImagePreviewScreen> createState() => _ProkitImagePreviewScreenState();
}

class _ProkitImagePreviewScreenState extends ConsumerState<ProkitImagePreviewScreen> {
  late File? _obverseFile;
  late File? _reverseFile;
  double _obverseRotation = 0;
  double _reverseRotation = 0;
  bool _isProcessing = false;
  int _selectedTab = 0; // 0 = obverse, 1 = reverse
  // BUGFIX (Faz C): her build'de yeni PageController(initialPage:) yaratmak
  // PageView'i guncellemiyordu -> sekmeye basinca gorsel degismiyordu.
  // Kalici controller + animateToPage ile senkron.
  final PageController _pageController = PageController();

  void _goToTab(int index) {
    setState(() => _selectedTab = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    if (widget.imageData is Map) {
      final map = widget.imageData as Map<String, dynamic>;
      _obverseFile = File(map['obverse'] as String);
      _reverseFile = File(map['reverse'] as String);
    } else {
      _obverseFile = File(widget.imageData as String);
      _reverseFile = null;
    }
  }

  Future<void> _rotateObverse() async {
    setState(() {
      _obverseRotation = (_obverseRotation + 90) % 360;
    });
  }

  Future<void> _rotateReverse() async {
    setState(() {
      _reverseRotation = (_reverseRotation + 90) % 360;
    });
  }

  Future<File?> _compressImage(File imageFile, double rotation, String suffix) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        'compressed_${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final compressRotation = ((rotation / 90).round() * 90) % 360;

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 85,
        rotate: compressRotation,
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
      final compressedObverse = await _compressImage(_obverseFile!, _obverseRotation, 'obverse');

      if (compressedObverse == null) {
        throw Exception('Failed to process obverse image');
      }

      final obverseSize = await compressedObverse.length();
      debugPrint('Compressed obverse size: ${obverseSize / 1024 / 1024} MB');

      if (obverseSize > 2 * 1024 * 1024) {
        throw Exception('Obverse image is too large (max 2MB)');
      }

      File? compressedReverse;
      if (_reverseFile != null) {
        compressedReverse = await _compressImage(_reverseFile!, _reverseRotation, 'reverse');

        if (compressedReverse == null) {
          throw Exception('Failed to process reverse image');
        }

        final reverseSize = await compressedReverse.length();
        debugPrint('Compressed reverse size: ${reverseSize / 1024 / 1024} MB');

        if (reverseSize > 2 * 1024 * 1024) {
          throw Exception('Reverse image is too large (max 2MB)');
        }
      }

      if (mounted) {
        final extra = _reverseFile != null
            ? {
                'obverse': compressedObverse.path,
                'reverse': compressedReverse!.path,
              }
            : compressedObverse.path;

        context.push('/recognition/results', extra: extra);
      }
    } catch (e) {
      if (mounted) {
        toast('Error: $e', bgColor: numError);
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
    final l10n = AppLocalizations.of(context);
    final isDualImage = _reverseFile != null;

    return Scaffold(
      backgroundColor: numScaffoldDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(l10n),

            // Tab selector for dual images
            if (isDualImage) _buildTabSelector(l10n),

            // Image preview
            Expanded(
              child: isDualImage ? _buildDualImagePreview(l10n) : _buildSingleImagePreview(l10n),
            ),

            // Bottom controls
            _buildBottomControls(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => GoRouter.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: white),
          ),
          Expanded(
            child: Text(
              l10n.translate('preview'),
              style: boldTextStyle(size: 18, color: white),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: () => _showTipsDialog(l10n),
            icon: Icon(Icons.lightbulb_outline, color: Colors.amber[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: numSurfaceDark,
        borderRadius: radius(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _goToTab(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: boxDecorationWithRoundedCorners(
                  backgroundColor: _selectedTab == 0 ? numPrimary : Colors.transparent,
                  borderRadius: radius(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.looks_one,
                      size: 18,
                      color: _selectedTab == 0 ? white : Colors.grey[500],
                    ),
                    8.width,
                    Text(
                      l10n.translate('obverse'),
                      style: boldTextStyle(
                        size: 14,
                        color: _selectedTab == 0 ? white : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _goToTab(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: boxDecorationWithRoundedCorners(
                  backgroundColor: _selectedTab == 1 ? numPrimary : Colors.transparent,
                  borderRadius: radius(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.looks_two,
                      size: 18,
                      color: _selectedTab == 1 ? white : Colors.grey[500],
                    ),
                    8.width,
                    Text(
                      l10n.translate('reverse'),
                      style: boldTextStyle(
                        size: 14,
                        color: _selectedTab == 1 ? white : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualImagePreview(AppLocalizations l10n) {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) => setState(() => _selectedTab = index),
      children: [
        _buildImageCard(
          file: _obverseFile!,
          rotation: _obverseRotation,
          label: l10n.translate('obverse'),
          onRotate: _rotateObverse,
          rotateText: l10n.translate('rotate'),
        ),
        _buildImageCard(
          file: _reverseFile!,
          rotation: _reverseRotation,
          label: l10n.translate('reverse'),
          onRotate: _rotateReverse,
          rotateText: l10n.translate('rotate'),
        ),
      ],
    );
  }

  Widget _buildSingleImagePreview(AppLocalizations l10n) {
    return _buildImageCard(
      file: _obverseFile!,
      rotation: _obverseRotation,
      label: l10n.translate('obverse'),
      onRotate: _rotateObverse,
      rotateText: l10n.translate('rotate'),
    );
  }

  Widget _buildImageCard({
    required File file,
    required double rotation,
    required String label,
    required VoidCallback onRotate,
    required String rotateText,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Image card
          Expanded(
            child: Container(
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: numCardDark,
                borderRadius: radius(20),
                boxShadow: [
                  BoxShadow(
                    color: black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: radius(20),
                    child: file.existsSync()
                        ? Transform.rotate(
                            angle: rotation * math.pi / 180,
                            child: Image.file(
                              file,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                16.height,
                                Text(
                                  'Image not found',
                                  style: secondaryTextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // Label badge
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: numPrimary.withOpacity(0.9),
                        borderRadius: radius(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, size: 16, color: white),
                          8.width,
                          Text(label, style: boldTextStyle(size: 12, color: white)),
                        ],
                      ),
                    ),
                  ),

                  // Rotation indicator
                  if (rotation != 0)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: boxDecorationWithRoundedCorners(
                          backgroundColor: black.withOpacity(0.6),
                          borderRadius: radius(12),
                        ),
                        child: Text(
                          '${rotation.toInt()}°',
                          style: boldTextStyle(size: 12, color: white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          16.height,

          // Rotation controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: boxDecorationWithRoundedCorners(
              backgroundColor: numCardDark,
              borderRadius: radius(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$rotateText:',
                  style: secondaryTextStyle(size: 14, color: Colors.grey[400]),
                ),
                16.width,
                _buildRotateButton(
                  icon: Icons.rotate_left,
                  onTap: _isProcessing
                      ? null
                      : () {
                          if (_selectedTab == 0) {
                            setState(() {
                              _obverseRotation = (_obverseRotation - 90) % 360;
                            });
                          } else {
                            setState(() {
                              _reverseRotation = (_reverseRotation - 90) % 360;
                            });
                          }
                        },
                ),
                12.width,
                _buildRotateButton(
                  icon: Icons.rotate_right,
                  onTap: _isProcessing ? null : onRotate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotateButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: numSurfaceDark,
          shape: BoxShape.circle,
          border: Border.all(color: numPrimaryLight.withOpacity(0.5)),
        ),
        child: Icon(icon, color: numPrimaryLight, size: 24),
      ),
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
          // Progress indicator
          if (_isProcessing)
            Column(
              children: [
                LinearProgressIndicator(
                  backgroundColor: numSurfaceDark,
                  valueColor: const AlwaysStoppedAnimation<Color>(numPrimaryLight),
                ),
                16.height,
              ],
            ),

          // Identify button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _uploadAndRecognize,
              style: ElevatedButton.styleFrom(
                backgroundColor: numPrimaryLight,
                foregroundColor: numTextPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: radius(12)),
                elevation: 4,
              ),
              child: _isProcessing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: numTextPrimary,
                          ),
                        ),
                        12.width,
                        Text(
                          l10n.translate('processing'),
                          style: boldTextStyle(size: 16, color: numTextPrimary),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search, size: 22),
                        8.width,
                        Text(
                          l10n.translate('identify_coin'),
                          style: boldTextStyle(size: 16, color: numTextPrimary),
                        ),
                      ],
                    ),
            ),
          ),

          12.height,

          // Retake button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isProcessing ? null : () => GoRouter.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[400],
                side: BorderSide(color: Colors.grey[600]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: radius(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, size: 20),
                  8.width,
                  Text(
                    l10n.translate('retake_photo'),
                    style: primaryTextStyle(size: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTipsDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: numCardDark,
        shape: RoundedRectangleBorder(borderRadius: radius(16)),
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber[400], size: 24),
            12.width,
            Text(
              l10n.translate('tips_title'),
              style: boldTextStyle(size: 18, color: white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTipItem(Icons.contrast, l10n.translate('tip_background')),
            12.height,
            _buildTipItem(Icons.wb_sunny_outlined, l10n.translate('tip_lighting')),
            12.height,
            _buildTipItem(Icons.center_focus_strong, l10n.translate('tip_centered')),
            12.height,
            _buildTipItem(Icons.blur_off, l10n.translate('tip_shadows')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.translate('close'), style: primaryTextStyle(color: numPrimaryLight)),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: numPrimary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: numPrimaryLight),
        ),
        12.width,
        Expanded(
          child: Text(
            text,
            style: primaryTextStyle(size: 14, color: Colors.grey[300]),
          ),
        ),
      ],
    );
  }
}
