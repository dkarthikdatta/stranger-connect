import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stranger_connect/models/user_model.dart';
import 'package:stranger_connect/screens/matching_screen.dart';
import 'package:stranger_connect/screens/chat_history_screen.dart';
import 'package:stranger_connect/screens/profile_edit_screen.dart';
import 'package:stranger_connect/services/auth_service.dart';
import 'package:stranger_connect/services/shake_service.dart';
import 'package:stranger_connect/utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ShakeService _shakeService;
  StreamSubscription<void>? _shakeSubscription;
  UserModel? _user;
  bool _isShakeEnabled = true;

  @override
  void initState() {
    super.initState();
    _shakeService = ShakeService();
    _shakeService.startListening();
    _shakeSubscription = _shakeService.onShake.listen((_) => _onShake());
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = context.read<AuthService>();
    final user = await authService.getUserProfile();
    if (mounted) setState(() => _user = user);
  }

  void _onShake() {
    if (!_isShakeEnabled) return;
    _navigateToMatching();
  }

  void _navigateToMatching() {
    setState(() => _isShakeEnabled = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MatchingScreen()),
    ).then((_) {
      if (mounted) setState(() => _isShakeEnabled = true);
    });
  }

  Future<void> _openProfileEditor() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
    if (changed == true) {
      _loadUser();
    }
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _shakeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stranger Connect'),
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: _openProfileEditor,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.cardColor,
              backgroundImage: _user?.profilePicUrl != null
                  ? CachedNetworkImageProvider(_user!.profilePicUrl!)
                  : null,
              child: _user?.profilePicUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: AppTheme.textSecondary,
                    )
                  : null,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_user != null)
                Text(
                  'Hey, ${_user!.displayName}!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 48),

              // Shake icon with animation
              const Icon(
                Icons.vibration_rounded,
                size: 120,
                color: AppTheme.primaryColor,
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shake(duration: 800.ms, hz: 3)
                  .then(delay: 1500.ms),

              const SizedBox(height: 32),
              const Text(
                'Shake your phone\nto connect!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You\'ll be matched with someone\nshaking at the same time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),

              // Manual button as fallback
              OutlinedButton.icon(
                onPressed: _isShakeEnabled ? _navigateToMatching : null,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Or tap to find someone'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
