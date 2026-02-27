import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String? profilePicUrl;
  final DateTime createdAt;
  final MatchInfo? currentMatch;

  UserModel({
    required this.uid,
    required this.displayName,
    this.profilePicUrl,
    required this.createdAt,
    this.currentMatch,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      profilePicUrl: data['profilePicUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      currentMatch: data['currentMatch'] != null
          ? MatchInfo.fromMap(data['currentMatch'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'profilePicUrl': profilePicUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentMatch': currentMatch?.toMap(),
    };
  }
}

class MatchInfo {
  final String chatRoomId;
  final DateTime matchedAt;

  MatchInfo({required this.chatRoomId, required this.matchedAt});

  factory MatchInfo.fromMap(Map<String, dynamic> map) {
    return MatchInfo(
      chatRoomId: map['chatRoomId'],
      matchedAt: (map['matchedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'matchedAt': Timestamp.fromDate(matchedAt),
    };
  }
}
