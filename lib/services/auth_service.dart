import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stranger_connect/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  Future<User?> signInAnonymously() async {
    if (_auth.currentUser != null) return _auth.currentUser;

    final credential = await _auth.signInAnonymously();
    return credential.user;
  }

  Future<bool> hasProfile() async {
    if (uid == null) return false;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<UserModel?> getUserProfile() async {
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> saveProfile({
    required String displayName,
    String? profilePicUrl,
  }) async {
    if (uid == null) throw Exception('Not authenticated');

    await _firestore.collection('users').doc(uid).set({
      'displayName': displayName,
      'profilePicUrl': profilePicUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'currentMatch': null,
    });
  }

  Future<void> updateProfile({
    String? displayName,
    String? profilePicUrl,
  }) async {
    if (uid == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (profilePicUrl != null) updates['profilePicUrl'] = profilePicUrl;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  Stream<UserModel?> userStream() {
    if (uid == null) return Stream.value(null);
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }
}
