import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:stranger_connect/services/auth_service.dart';
import 'package:stranger_connect/services/storage_service.dart';
import 'package:stranger_connect/utils/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameController = TextEditingController();
  XFile? _pickedImage;
  String? _existingProfilePicUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authService = context.read<AuthService>();
    final user = await authService.getUserProfile();
    if (!mounted || user == null) return;
    setState(() {
      _nameController.text = user.displayName;
      _existingProfilePicUrl = user.profilePicUrl;
    });
  }

  Future<void> _pickImage() async {
    final storageService = context.read<StorageService>();
    final image = await storageService.pickImage();
    if (!mounted) return;
    if (image != null) {
      setState(() => _pickedImage = image);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final uid = authService.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated. Please reopen the app.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? profilePicUrl;
      if (_pickedImage != null) {
        final storageService = context.read<StorageService>();
        profilePicUrl = await storageService.uploadProfilePic(uid, _pickedImage!);
      }

      await authService.updateProfile(
        displayName: name,
        profilePicUrl: profilePicUrl,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save changes. Please try again.')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPickedImage = _pickedImage != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _isSaving ? null : _pickImage,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: AppTheme.cardColor,
                  backgroundImage: hasPickedImage
                      ? FileImage(File(_pickedImage!.path))
                      : (_existingProfilePicUrl != null
                          ? CachedNetworkImageProvider(_existingProfilePicUrl!)
                          : null) as ImageProvider<Object>?,
                  child: !hasPickedImage && _existingProfilePicUrl == null
                      ? const Icon(
                          Icons.camera_alt_rounded,
                          size: 30,
                          color: AppTheme.textSecondary,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tap image to change',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
