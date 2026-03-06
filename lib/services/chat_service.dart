import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stranger_connect/models/chat_room_model.dart';
import 'package:stranger_connect/models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<MessageModel>> getMessages(String chatRoomId, {int limit = 50}) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String text,
    String? clientMessageId,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    final messageRef = roomRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final roomSnap = await transaction.get(roomRef);
      final roomData = roomSnap.data();
      if (!roomSnap.exists || roomData == null) {
        throw Exception('Chat room not found');
      }

      if (roomData['endedBy'] != null || roomData['endedAt'] != null) {
        throw Exception('Chat has ended');
      }

      transaction.set(messageRef, {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'clientMessageId': clientMessageId,
      });

      transaction.update(roomRef, {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> endChat({
    required String chatRoomId,
  }) async {
    try {
      await _functions.httpsCallable('endChat').call({
        'chatRoomId': chatRoomId,
      });
    } catch (_) {
      // Fallback for transient function connectivity issues.
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        rethrow;
      }
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': uid,
        'active': false,
      });
    }
  }

  Future<void> markChatEndedLocally({
    required String chatRoomId,
    required String endedByUid,
  }) async {
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'endedAt': FieldValue.serverTimestamp(),
      'endedBy': endedByUid,
      'active': false,
    });
  }

  Future<ChatRoomModel?> getChatRoom(String chatRoomId) async {
    final doc =
        await _firestore.collection('chat_rooms').doc(chatRoomId).get();
    if (!doc.exists) return null;
    return ChatRoomModel.fromFirestore(doc);
  }

  Stream<ChatRoomModel?> chatRoomStream(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ChatRoomModel.fromFirestore(doc);
    });
  }

  Stream<List<ChatRoomModel>> getUserChatRooms(String uid) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatRoomModel.fromFirestore(doc))
          .toList();
    });
  }
}
