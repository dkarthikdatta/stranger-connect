import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stranger_connect/models/chat_room_model.dart';
import 'package:stranger_connect/models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  }) async {
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc();

    final batch = _firestore.batch();

    batch.set(messageRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    batch.update(
      _firestore.collection('chat_rooms').doc(chatRoomId),
      {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
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
