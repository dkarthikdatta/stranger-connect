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

  final _stateController = StreamController<MatchmakingState>.broadcast();
  Stream<MatchmakingState> get stateStream => _stateController.stream;

  MatchmakingService(this._authService);

  Future<void> joinQueue() async {
    var uid = _authService.uid;
    if (uid == null) {
      await _authService.signInAnonymously();
      uid = _authService.uid;
    }
    if (uid == null) {
      _stateController.add(MatchmakingState(
        status: MatchmakingStatus.error,
        errorMessage: 'Authentication unavailable',
      ));
      return;
    }

    // Defensive clear to avoid stale matches causing instant reconnects.
    try {
      await _firestore.collection('users').doc(uid).update({
        'currentMatch': null,
      });
    } catch (_) {}

    _listenForMatch(uid);
    _stateController.add(MatchmakingState(status: MatchmakingStatus.searching));

    try {
      final result = await _callJoinQueueWithRetry();

      final status = result.data['status'];

      if (status == 'matched') {
        final chatRoomId = result.data['chatRoomId'] as String?;
        if (chatRoomId != null) {
          _stateController.add(MatchmakingState(
            status: MatchmakingStatus.matched,
            chatRoomId: chatRoomId,
          ));
          _cleanup();
        } else {
          // Keep listener active as fallback if function omitted chatRoomId.
          print("Matched via backend, waiting for currentMatch listener");
        }
      } else {
        print("Waiting for match...");
      }
    } catch (e) {
      print("Matchmaking error: $e");
      _stateController.add(MatchmakingState(
        status: MatchmakingStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<HttpsCallableResult<dynamic>> _callJoinQueueWithRetry() async {
    Object? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final callable = _functions.httpsCallable('joinQueue');
        return await callable.call().timeout(const Duration(seconds: 6));
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
        }
      }
    }
    throw lastError ?? Exception('joinQueue failed');
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
