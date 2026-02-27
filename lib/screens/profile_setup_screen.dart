import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:stranger_connect/screens/home_screen.dart';
import 'package:stranger_connect/services/auth_service.dart';
import 'package:stranger_connect/services/storage_service.dart';
import 'package:stranger_connect/utils/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  XFile? _pickedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final storageService = context.read<StorageService>();
    final image = await storageService.pickImage();
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

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final storageService = context.read<StorageService>();
      String? picUrl;

      if (_pickedImage != null) {
        picUrl = await storageService.uploadProfilePic(
          authService.uid!,
          _pickedImage!,
        );
      }

      await authService.saveProfile(
        displayName: name,
        profilePicUrl: picUrl,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.handshake_rounded,
                size: 56,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 12),
              const Text(
                'Stranger Connect',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set up your profile to get started',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 48),

              // Profile picture
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: AppTheme.cardColor,
                  backgroundImage: _pickedImage != null
                      ? FileImage(File(_pickedImage!.path))
                      : null,
                  child: _pickedImage == null
                      ? const Icon(
                          Icons.camera_alt_rounded,
                          size: 32,
                          color: AppTheme.textSecondary,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to add photo (optional)',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 32),

              // Name field
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Enter your display name',
                  prefixIcon: Icon(
                    Icons.person_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Get Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
