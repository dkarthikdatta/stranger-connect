import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final Map<String, ParticipantProfile> participantProfiles;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.participantProfiles,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final profilesMap = data['participantProfiles'] as Map<String, dynamic>? ?? {};
    final profiles = profilesMap.map(
      (key, value) => MapEntry(key, ParticipantProfile.fromMap(value)),
    );

    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantProfiles: profiles,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'],
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
    );
  }

  ParticipantProfile? getOtherProfile(String myUid) {
    final otherUid = participants.firstWhere(
      (uid) => uid != myUid,
      orElse: () => '',
    );
    return participantProfiles[otherUid];
  }
}

class ParticipantProfile {
  final String displayName;
  final String? profilePicUrl;

  ParticipantProfile({required this.displayName, this.profilePicUrl});

  factory ParticipantProfile.fromMap(Map<String, dynamic> map) {
    return ParticipantProfile(
      displayName: map['displayName'] ?? '',
      profilePicUrl: map['profilePicUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'profilePicUrl': profilePicUrl,
    };
  }
}
