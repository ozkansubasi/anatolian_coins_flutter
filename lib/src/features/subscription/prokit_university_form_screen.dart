import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';

/// University Student Free Pro Subscription Application Form
/// Students can apply for free Pro subscription by uploading their university ID
class ProkitUniversityFormScreen extends ConsumerStatefulWidget {
  const ProkitUniversityFormScreen({super.key});

  @override
  ConsumerState<ProkitUniversityFormScreen> createState() => _ProkitUniversityFormScreenState();
}

class _ProkitUniversityFormScreenState extends ConsumerState<ProkitUniversityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();

  File? _idCardImage;
  bool _isSubmitting = false;
  String? _submitError;

  // Interest areas (optional)
  final List<String> _interestAreas = [
    'ancient_coins',
    'archaeology',
    'history',
    'numismatics',
    'art_history',
    'classical_studies',
    'museum_studies',
    'conservation',
  ];
  final Set<String> _selectedInterests = {};

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _pickIdCard() async {
    final picker = ImagePicker();

    // Show selection dialog
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: radius(16)),
        title: Text(
          AppLocalizations.of(context).translate('select_image_source'),
          style: boldTextStyle(size: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: numPrimary.withValues(alpha: 0.1),
                  borderRadius: radius(10),
                ),
                child: const Icon(Icons.camera_alt, color: numPrimary),
              ),
              title: Text(AppLocalizations.of(context).translate('camera')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: numPrimary.withValues(alpha: 0.1),
                  borderRadius: radius(10),
                ),
                child: const Icon(Icons.photo_library, color: numPrimary),
              ),
              title: Text(AppLocalizations.of(context).translate('gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _idCardImage = File(image.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idCardImage == null) {
      toast(
        AppLocalizations.of(context).translate('id_card_required'),
        bgColor: numError,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final l10n = AppLocalizations.of(context);

      // Prepare form data
      final formData = FormData.fromMap({
        'name': _nameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'email': _emailController.text.trim(),
        'university': _universityController.text.trim(),
        'department': _departmentController.text.trim(),
        'interests': _selectedInterests.join(', '),
        'id_card': await MultipartFile.fromFile(
          _idCardImage!.path,
          filename: 'university_id_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      // Send to API endpoint which will forward to email
      final dio = Dio();
      await dio.post(
        'https://www.numistr.org/api/index.php/v1/university-application',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: radius(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: numSuccess.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: numSuccess, size: 64),
                ),
                24.height,
                Text(
                  l10n.translate('application_submitted'),
                  style: boldTextStyle(size: 20),
                  textAlign: TextAlign.center,
                ),
                12.height,
                Text(
                  l10n.translate('application_review_info'),
                  style: secondaryTextStyle(size: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    GoRouter.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: numPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: radius(12)),
                  ),
                  child: Text(l10n.translate('ok')),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _submitError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: numScaffoldLight,
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: numPrimary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: numGradientPrimary),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school, size: 50, color: Colors.white),
                      ),
                      16.height,
                      Text(
                        l10n.translate('university_pro_title'),
                        style: boldTextStyle(size: 20, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      8.height,
                      Text(
                        l10n.translate('university_pro_subtitle'),
                        style: primaryTextStyle(size: 14, color: Colors.white.withValues(alpha: 0.9)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: numScaffoldLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Card
                        _buildInfoCard(l10n),
                        24.height,

                        // Personal Information Section
                        _buildSectionTitle(l10n.translate('personal_info'), Icons.person),
                        16.height,

                        // Name
                        _buildTextField(
                          controller: _nameController,
                          label: l10n.translate('first_name'),
                          icon: Icons.badge_outlined,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.translate('field_required');
                            }
                            return null;
                          },
                        ),
                        16.height,

                        // Surname
                        _buildTextField(
                          controller: _surnameController,
                          label: l10n.translate('last_name'),
                          icon: Icons.badge_outlined,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.translate('field_required');
                            }
                            return null;
                          },
                        ),
                        16.height,

                        // Email
                        _buildTextField(
                          controller: _emailController,
                          label: l10n.translate('email'),
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.translate('field_required');
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return l10n.translate('invalid_email');
                            }
                            return null;
                          },
                        ),
                        24.height,

                        // University Information Section
                        _buildSectionTitle(l10n.translate('university_info'), Icons.school),
                        16.height,

                        // University Name
                        _buildTextField(
                          controller: _universityController,
                          label: l10n.translate('university_name'),
                          icon: Icons.account_balance_outlined,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.translate('field_required');
                            }
                            return null;
                          },
                        ),
                        16.height,

                        // Department
                        _buildTextField(
                          controller: _departmentController,
                          label: l10n.translate('department'),
                          icon: Icons.history_edu_outlined,
                          hint: l10n.translate('department_hint'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.translate('field_required');
                            }
                            return null;
                          },
                        ),
                        24.height,

                        // ID Card Upload Section
                        _buildSectionTitle(l10n.translate('id_card_upload'), Icons.credit_card),
                        8.height,
                        Text(
                          l10n.translate('id_card_info'),
                          style: secondaryTextStyle(size: 14),
                        ),
                        16.height,

                        // ID Card Picker
                        _buildIdCardPicker(l10n),
                        24.height,

                        // Interest Areas Section (Optional)
                        _buildSectionTitle(
                          l10n.translate('interest_areas'),
                          Icons.interests,
                          subtitle: l10n.translate('optional'),
                        ),
                        16.height,

                        // Interest Chips
                        _buildInterestChips(l10n),
                        32.height,

                        // Error Message
                        if (_submitError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: boxDecorationWithRoundedCorners(
                              backgroundColor: numError.withValues(alpha: 0.1),
                              borderRadius: radius(12),
                              border: Border.all(color: numError.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: numError),
                                12.width,
                                Expanded(
                                  child: Text(
                                    _submitError!,
                                    style: primaryTextStyle(size: 14, color: numError),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          16.height,
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: numPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: radius(12)),
                              disabledBackgroundColor: numPrimary.withValues(alpha: 0.5),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    l10n.translate('submit_application'),
                                    style: boldTextStyle(size: 16, color: Colors.white),
                                  ),
                          ),
                        ),
                        24.height,

                        // Privacy Note
                        Text(
                          l10n.translate('privacy_note'),
                          style: secondaryTextStyle(size: 12),
                          textAlign: TextAlign.center,
                        ),
                        32.height,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: numInfo.withValues(alpha: 0.1),
        borderRadius: radius(12),
        border: Border.all(color: numInfo.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: numInfo.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline, color: numInfo, size: 20),
          ),
          12.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('university_pro_info_title'),
                  style: boldTextStyle(size: 14, color: numInfo),
                ),
                8.height,
                Text(
                  l10n.translate('university_pro_info_desc'),
                  style: primaryTextStyle(size: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {String? subtitle}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: numPrimary.withValues(alpha: 0.1),
            borderRadius: radius(8),
          ),
          child: Icon(icon, color: numPrimary, size: 20),
        ),
        12.width,
        Text(title, style: boldTextStyle(size: 16)),
        if (subtitle != null) ...[
          8.width,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: boxDecorationWithRoundedCorners(
              backgroundColor: numTextHint.withValues(alpha: 0.2),
              borderRadius: radius(8),
            ),
            child: Text(subtitle, style: secondaryTextStyle(size: 12)),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: numPrimary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: numBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: numBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: numPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: numError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: numError, width: 2),
        ),
      ),
    );
  }

  Widget _buildIdCardPicker(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _pickIdCard,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: boxDecorationWithRoundedCorners(
          backgroundColor: Colors.white,
          borderRadius: radius(12),
          border: Border.all(
            color: _idCardImage != null ? numSuccess : numBorder,
            width: _idCardImage != null ? 2 : 1,
          ),
        ),
        child: _idCardImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: radius(11),
                    child: Image.file(
                      _idCardImage!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: boxDecorationWithRoundedCorners(
                            backgroundColor: numSuccess,
                            borderRadius: radius(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, color: Colors.white, size: 14),
                              4.width,
                              Text(
                                l10n.translate('uploaded'),
                                style: boldTextStyle(size: 12, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        8.width,
                        GestureDetector(
                          onTap: () => setState(() => _idCardImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: numError,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: numPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined, size: 40, color: numPrimary),
                  ),
                  16.height,
                  Text(
                    l10n.translate('tap_to_upload_id'),
                    style: boldTextStyle(size: 14, color: numTextPrimary),
                  ),
                  8.height,
                  Text(
                    l10n.translate('accepted_formats'),
                    style: secondaryTextStyle(size: 12),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInterestChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _interestAreas.map((interest) {
        final isSelected = _selectedInterests.contains(interest);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedInterests.remove(interest);
              } else {
                _selectedInterests.add(interest);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: boxDecorationWithRoundedCorners(
              backgroundColor: isSelected ? numPrimary : Colors.white,
              borderRadius: radius(20),
              border: Border.all(
                color: isSelected ? numPrimary : numBorder,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: numPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check, size: 16, color: Colors.white),
                  6.width,
                ],
                Text(
                  l10n.translate('interest_$interest'),
                  style: boldTextStyle(
                    size: 14,
                    color: isSelected ? Colors.white : numTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
