import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class ShakeService {
  static const double _shakeThreshold = 15.0;
  static const Duration _debounceDuration = Duration(seconds: 3);
  static const int _requiredConsecutiveShakes = 2;

  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastShakeTime;
  int _consecutiveShakeCount = 0;
  final _shakeController = StreamController<void>.broadcast();

  Stream<void> get onShake => _shakeController.stream;

  void startListening() {
    _subscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Subtract gravity (~9.8) and check threshold
    if (magnitude > _shakeThreshold) {
      _consecutiveShakeCount++;
      if (_consecutiveShakeCount >= _requiredConsecutiveShakes) {
        _triggerShake();
        _consecutiveShakeCount = 0;
      }
    } else {
      _consecutiveShakeCount = 0;
    }
  }

  void _triggerShake() {
    final now = DateTime.now();
    if (_lastShakeTime != null &&
        now.difference(_lastShakeTime!) < _debounceDuration) {
      return;
    }
    _lastShakeTime = now;
    _shakeController.add(null);
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
    _shakeController.close();
  }
}
