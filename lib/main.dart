import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stranger_connect/services/auth_service.dart';
import 'package:stranger_connect/services/chat_service.dart';
import 'package:stranger_connect/services/matchmaking_service.dart';
import 'package:stranger_connect/services/storage_service.dart';
import 'package:stranger_connect/screens/splash_screen.dart';
import 'package:stranger_connect/utils/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const StrangerConnectApp());
}

class StrangerConnectApp extends StatelessWidget {
  const StrangerConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<ChatService>(create: (_) => ChatService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<MatchmakingService>(
          create: (_) => MatchmakingService(authService),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Stranger Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
