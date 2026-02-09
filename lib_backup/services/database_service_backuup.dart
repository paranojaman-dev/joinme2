import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create user document
  Future<void> createUserDocument(
      User user, {
        String? displayName,
        int? age,
      }) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? 'Użytkownik',
        'age': age ?? 18,
        'interests': [],
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'visibilitySettings': {
          'showToMen': true,
          'showToWomen': true,
          'showToOther': true,
          'ageRange': {'min': 18, 'max': 99}
        },
        'status': {
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        'location': {
          'latitude': 0.0,
          'longitude': 0.0,
          'timestamp': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      print('✅ Dokument użytkownika stworzony: ${user.uid}');
    } catch (e) {
      print('❌ Błąd tworzenia dokumentu użytkownika: $e');
      rethrow;
    }
  }

  // Get user data
  Future<DocumentSnapshot> getUserData(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  // Update user location
  Future<void> updateUserLocation(String uid, double lat, double lng) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'location': {
          'latitude': lat,
          'longitude': lng,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'status.lastSeen': FieldValue.serverTimestamp(),
      });
      print('📍 Lokalizacja zaktualizowana dla użytkownika: $uid');
    } catch (e) {
      print('❌ Błąd aktualizacji lokalizacji: $e');
    }
  }

  // Check if user document exists
  Future<bool> userDocumentExists(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }
}