import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stranger_connect/screens/home_screen.dart';
import 'package:stranger_connect/screens/profile_setup_screen.dart';
import 'package:stranger_connect/services/auth_service.dart';
import 'package:stranger_connect/utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final authService = context.read<AuthService>();

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await authService.signInAnonymously();
        final hasProfile = await authService.hasProfile();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                hasProfile ? const HomeScreen() : const ProfileSetupScreen(),
          ),
        );
        return;
      } catch (e) {
        debugPrint('Init attempt ${attempt + 1} failed: $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.handshake_rounded,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: 24),
            Text(
              'Stranger Connect',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
