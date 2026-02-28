import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
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
    final uid = _authService.uid;
    if (uid == null) return;

    _stateController.add(MatchmakingState(status: MatchmakingStatus.searching));

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('joinQueue');
      final result = await callable.call();

      final status = result.data['status'];

      if (status == 'matched') {
        // Do nothing here.
        // Navigation should ONLY happen from user doc listener.
        print("Matched via backend");
      } else {
        print("Waiting for match...");
      }
    } catch (e) {
      print("Matchmaking error: $e");
      rethrow;
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
