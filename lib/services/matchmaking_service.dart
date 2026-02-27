import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:stranger_connect/services/auth_service.dart';

enum MatchmakingStatus { idle, searching, matched, error, timeout }

class MatchmakingState {
  final MatchmakingStatus status;
  final String? chatRoomId;
  final String? errorMessage;

  MatchmakingState({
    required this.status,
    this.chatRoomId,
    this.errorMessage,
  });
}

class MatchmakingService {
  final AuthService _authService;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _matchListener;
  Timer? _timeoutTimer;

  final _stateController = StreamController<MatchmakingState>.broadcast();
  Stream<MatchmakingState> get stateStream => _stateController.stream;

  MatchmakingService(this._authService);

  Future<void> joinQueue() async {
    final uid = _authService.uid;
    if (uid == null) return;

    _stateController.add(MatchmakingState(status: MatchmakingStatus.searching));

    try {
      final result = await _functions.httpsCallable('joinQueue').call({});
      final data = result.data as Map<String, dynamic>;

      if (data['status'] == 'matched') {
        _stateController.add(MatchmakingState(
          status: MatchmakingStatus.matched,
          chatRoomId: data['chatRoomId'],
        ));
        return;
      }

      // Status is "waiting" - listen for match via user document
      _listenForMatch(uid);
      _startTimeout();
    } catch (e) {
      _stateController.add(MatchmakingState(
        status: MatchmakingStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _listenForMatch(String uid) {
    _matchListener?.cancel();
    _matchListener = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data['currentMatch'] != null) {
        final chatRoomId = data['currentMatch']['chatRoomId'] as String;
        _stateController.add(MatchmakingState(
          status: MatchmakingStatus.matched,
          chatRoomId: chatRoomId,
        ));
        _cleanup();
      }
    });
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      _stateController.add(MatchmakingState(status: MatchmakingStatus.timeout));
      leaveQueue();
    });
  }

  Future<void> leaveQueue() async {
    try {
      await _functions.httpsCallable('leaveQueue').call({});
    } catch (_) {}
    _cleanup();
    _stateController.add(MatchmakingState(status: MatchmakingStatus.idle));
  }

  void _cleanup() {
    _matchListener?.cancel();
    _matchListener = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  Future<void> clearCurrentMatch() async {
    final uid = _authService.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).update({
      'currentMatch': null,
    });
  }

  void dispose() {
    _cleanup();
    _stateController.close();
  }
}
