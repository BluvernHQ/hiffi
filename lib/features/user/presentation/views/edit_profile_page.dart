import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/file_validation_utils.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/otp_code_input.dart';
import '../../domain/models/user_model.dart';
import '../viewmodels/user_view_model.dart';

const _profileRed = Color(0xFFED1C2F);
const _bioMaxLength = 160;
const _editProfileAvatarRadius = 56.0;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final UserModel user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _bioController;
  late final String _initialEmail;

  File? _localPreviewFile;
  Uint8List? _localPreviewBytes;
  bool _isUploadingPhoto = false;
  int _cacheBust = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _initialEmail = widget.user.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(UserViewModel viewModel) async {
    if (_isUploadingPhoto) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
    } catch (_) {
      return;
    }

    if (!mounted || result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    final fileName = pickedFile.name.toLowerCase();
    if (!FileValidationUtils.isValidImageExtension(fileName)) {
      _showError('Please select a JPG or PNG image.');
      return;
    }

    File? imageFile;
    Uint8List? previewBytes;
    int? fileSizeBytes;

    if (pickedFile.bytes != null) {
      previewBytes = pickedFile.bytes;
      fileSizeBytes = previewBytes!.length;
      if (pickedFile.path != null) {
        imageFile = File(pickedFile.path!);
      }
    } else if (pickedFile.path != null) {
      imageFile = File(pickedFile.path!);
      fileSizeBytes = imageFile.lengthSync();
    } else {
      _showError('Unable to access selected file. Please try again.');
      return;
    }

    if (fileSizeBytes > FileValidationUtils.maxProfilePictureSizeBytes) {
      _showError(
        'Image size should be less than 10 MB. Please choose a smaller image.',
      );
      return;
    }

    // Show local preview immediately so the user can confirm before saving.
    setState(() {
      _localPreviewFile = imageFile;
      _localPreviewBytes = previewBytes;
      _isUploadingPhoto = true;
    });

    if (imageFile == null) {
      setState(() => _isUploadingPhoto = false);
      _showError('Unable to process file. Please try again.');
      return;
    }

    try {
      await viewModel.uploadProfilePicture(imageFile);
      await viewModel.loadUser(widget.user.username);

      if (!mounted) return;
      setState(() {
        _localPreviewFile = null;
        _localPreviewBytes = null;
        _cacheBust = DateTime.now().millisecondsSinceEpoch;
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      _showError('Failed to upload photo: $error');
    }
  }

  Widget _buildAvatar(UserModel displayUser) {
    ImageProvider? previewProvider;
    if (_localPreviewFile != null) {
      previewProvider = FileImage(_localPreviewFile!);
    } else if (_localPreviewBytes != null) {
      previewProvider = MemoryImage(_localPreviewBytes!);
    }

    return SizedBox(
      width: _editProfileAvatarRadius * 2,
      height: _editProfileAvatarRadius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: _editProfileAvatarRadius,
            backgroundColor: const Color(0xFFF0F0F0),
            backgroundImage: previewProvider,
            child: previewProvider == null
                ? HiffiAvatar(
                    size: _editProfileAvatarRadius * 2 - 4,
                    imageUrl:
                        displayUser.profilePicture ?? displayUser.avatarUrl,
                    fallbackText: displayUser.name,
                    cacheBust: _cacheBust != 0
                        ? _cacheBust
                        : displayUser.updatedAt?.millisecondsSinceEpoch,
                  )
                : null,
          ),
          if (_isUploadingPhoto)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.38),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 2,
            bottom: 2,
            child: GestureDetector(
            onTap: _isUploadingPhoto
                ? null
                : () => _pickAndUploadPhoto(
                    context.read<UserViewModel>(),
                  ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _profileRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? helper,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF8A8A8A),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF8A8A8A),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _profileRed.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _profileRed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  Future<void> _save(UserViewModel viewModel) async {
    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim().toLowerCase();
    final newBio = _bioController.text.trim();
    final emailChanged = newEmail != _initialEmail.trim().toLowerCase();

    if (newName.isEmpty) {
      _showError('Display name cannot be empty.');
      return;
    }
    if (newEmail.isEmpty) {
      _showError('Email is required.');
      return;
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(newEmail)) {
      _showError('Please enter a valid email address.');
      return;
    }

    try {
      if (emailChanged) {
        final result = await viewModel.sendEmailUpdateOTP(
          currentUsername: widget.user.username,
          name: newName,
          email: newEmail,
          bio: newBio,
        );
        final otpId = result['id'] as String?;
        if (!mounted || otpId == null) return;
        await _showOtpSheet(viewModel, otpId);
      } else {
        await viewModel.updateUser(
          currentUsername: widget.user.username,
          name: newName,
          email: newEmail,
          bio: newBio,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showError(viewModel.otpError ?? 'Failed to update profile: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _showOtpSheet(UserViewModel viewModel, String otpId) async {
    final otpController = TextEditingController();
    String? otpError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verify Email',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the code sent to your new email address.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                OtpCodeInput(
                  controller: otpController,
                  enabled: !viewModel.isVerifyingOTP,
                  errorText: otpError,
                  autofocus: true,
                  onChanged: (_) {
                    if (otpError != null) setModalState(() => otpError = null);
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: viewModel.isVerifyingOTP
                      ? null
                      : () async {
                          final otp = otpController.text.trim();
                          if (otp.length != 6) {
                            setModalState(
                              () => otpError = 'Please enter a 6-digit code',
                            );
                            return;
                          }
                          try {
                            await viewModel.verifyEmailUpdateOTP(
                              id: otpId,
                              otp: otp,
                              currentUsername: widget.user.username,
                            );
                            if (!context.mounted) return;
                            Navigator.of(sheetContext).pop();
                            Navigator.of(this.context).pop(true);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully'),
                              ),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            setModalState(
                              () => otpError =
                                  viewModel.otpError ??
                                  'Invalid code. Please try again.',
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _profileRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: viewModel.isVerifyingOTP
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify & save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    otpController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final isLoading = viewModel.isLoading || viewModel.isSendingOTP;
    final displayUser = viewModel.viewedUser ??
        viewModel.currentUser ??
        widget.user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _profileRed),
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  children: [
                    _buildAvatar(displayUser),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isUploadingPhoto
                          ? null
                          : () => _pickAndUploadPhoto(viewModel),
                      child: const Text(
                        'CHANGE PHOTO',
                        style: TextStyle(
                          color: _profileRed,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _nameController,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                        LengthLimitingTextInputFormatter(30),
                      ],
                      decoration: _fieldDecoration(label: 'DISPLAY NAME *'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: _fieldDecoration(
                        label: 'USERNAME',
                        helper: 'Username cannot be changed.',
                        suffixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                      ).copyWith(
                        filled: true,
                        fillColor: const Color(0xFFEEEEEE),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      child: Text(
                        '@${widget.user.username.toLowerCase()}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration(label: 'EMAIL *'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bioController,
                      maxLines: 5,
                      maxLength: _bioMaxLength,
                      buildCounter: (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) =>
                          Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$currentLength/$_bioMaxLength',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      decoration: _fieldDecoration(label: 'BIO').copyWith(
                        alignLabelWithHint: true,
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _profileRed,
                        side: const BorderSide(color: _profileRed, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: isLoading ? null : () => _save(viewModel),
                      style: FilledButton.styleFrom(
                        backgroundColor: _profileRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
