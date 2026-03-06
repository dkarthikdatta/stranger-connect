import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfig {
  final int timeoutSeconds;
  final int matchWindowSeconds;

  const AppConfig({
    this.timeoutSeconds = 30,
    this.matchWindowSeconds = 5,
  });

  factory AppConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppConfig(
      timeoutSeconds: (data['timeoutSeconds'] as num?)?.toInt() ?? 30,
      matchWindowSeconds: (data['matchWindowSeconds'] as num?)?.toInt() ?? 5,
    );
  }
}

class ConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AppConfig _config = const AppConfig();

  AppConfig get config => _config;

  Future<AppConfig> load() async {
    try {
      final doc = await _firestore
          .collection('config')
          .doc('matchmaking')
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) {
        _config = AppConfig.fromFirestore(doc);
      }
    } catch (_) {
      // Fall back to cached/default values quickly when backend is unavailable.
    }
    return _config;
  }
}
