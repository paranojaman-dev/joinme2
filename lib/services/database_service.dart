import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/models/pin_model.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- FCM TOKEN ---
  Future<void> saveUserToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        if (kDebugMode) print("🔑 TWÓJ TOKEN FCM: $token");
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) print("❌ Błąd pobierania tokenu: $e");
    }
  }

  // --- WYDARZENIA ---
  Stream<QuerySnapshot> getEvents() {
    return _firestore.collection('events').where('isActive', isEqualTo: true).snapshots();
  }

  Future<QuerySnapshot> getEventsOnce() {
    return _firestore.collection('events').where('isActive', isEqualTo: true).get();
  }

  Future<void> createEvent(Event event, {bool isPrivate = false}) async {
    final Map<String, dynamic> data = event.toMap();
    data['isPrivate'] = isPrivate;
    await _firestore.collection('events').add(data);
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await _firestore.collection('events').doc(eventId).update(data);
  }

  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection('events').doc(eventId).delete();
  }

  Future<void> joinEvent(String eventId, String userId) async {
    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> leaveEvent(String eventId, String userId) async {
    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayRemove([userId])
    });
  }

  // --- PINEZKI ---
  Future<void> createPin(PinModel pin) async {
    await _firestore.collection('pins').add(pin.toMap());
  }

  Stream<QuerySnapshot> getPins() {
    return _firestore.collection('pins').snapshots();
  }

  Future<QuerySnapshot> getPinsOnce() {
    return _firestore.collection('pins').get();
  }

  Future<void> deletePin(String pinId) async {
    await _firestore.collection('pins').doc(pinId).delete();
  }

  // --- UŻYTKOWNICY ---
  Future<void> createUserDocument(User user, {
    required String firstName, 
    required String lastName, 
    required String nickname,
    DateTime? dateOfBirth
  }) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'firstName': firstName, 
      'lastName': lastName,   
      'nickname': nickname,   
      'displayName': "$firstName $lastName", 
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth) : null,
      'interests': [],
      'photoURL': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'friends': [],
      'blockedUsers': [],
      'status_info': {'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()},
      'visibility': 'public',
      'hasAcceptedTerms': false,
    }, SetOptions(merge: true));
    await saveUserToken(user.uid);
  }

  Future<DocumentSnapshot> getUserData(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  Future<QuerySnapshot> getUsersOnce() {
    return _firestore.collection('users').get();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    data.remove('firstName');
    data.remove('lastName');
    data.remove('nickname');
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<void> updateUserStatus(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).update({
      'status_info.isOnline': isOnline,
      'status_info.lastSeen': FieldValue.serverTimestamp()
    });
  }

  Future<void> updateUserVisibility(String uid, String visibility) async {
    await _firestore.collection('users').doc(uid).update({'visibility': visibility});
  }

  Future<void> updateMapStyle(String uid, String style) async {
    await _firestore.collection('users').doc(uid).update({'mapStyle': style});
  }

  Future<void> markTermsAsAccepted(String uid) async {
    await _firestore.collection('users').doc(uid).update({'hasAcceptedTerms': true});
  }

  Future<void> deleteAccount(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final String? userEmail = user?.email;

      final batch = _firestore.batch();
      
      batch.delete(_firestore.collection('users').doc(uid));
      
      final createdEvents = await _firestore.collection('events').where('creatorId', isEqualTo: uid).get();
      for (var doc in createdEvents.docs) batch.delete(doc.reference);
      
      final joinedEvents = await _firestore.collection('events').where('participants', arrayContains: uid).get();
      for (var doc in joinedEvents.docs) {
        batch.update(doc.reference, {'participants': FieldValue.arrayRemove([uid])});
      }
      
      final sentReq = await _firestore.collection('friend_requests').where('from', isEqualTo: uid).get();
      for (var doc in sentReq.docs) batch.delete(doc.reference);
      final recReq = await _firestore.collection('friend_requests').where('to', isEqualTo: uid).get();
      for (var doc in recReq.docs) batch.delete(doc.reference);
      
      final userPins = await _firestore.collection('pins').where('creatorId', isEqualTo: uid).get();
      for (var doc in userPins.docs) batch.delete(doc.reference);

      final userChats = await _firestore.collection('chats').where('users', arrayContains: uid).get();
      for (var chatDoc in userChats.docs) {
        final messages = await chatDoc.reference.collection('messages').get();
        for (var msg in messages.docs) batch.delete(msg.reference);
        batch.delete(chatDoc.reference);
      }

      final notifications = await _firestore.collection('users').doc(uid).collection('notifications').get();
      for (var doc in notifications.docs) batch.delete(doc.reference);

      await batch.commit();

      if (user != null && user.uid == uid) {
        await user.delete();
        if (kDebugMode) print("Konto $userEmail usunięte.");
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ Błąd usuwania konta: $e");
      await FirebaseAuth.instance.signOut();
    }
  }

  // --- ZNAJOMI I BLOKOWANIE ---
  Stream<DocumentSnapshot> getFriends(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  Stream<QuerySnapshot> getFriendRequests(String userId) {
    return _firestore.collection('friend_requests').where('to', isEqualTo: userId).where('status', isEqualTo: 'pending').snapshots();
  }

  Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    await _firestore.collection('friend_requests').add({
      'from': fromUserId,
      'to': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await sendNotification(toUserId, fromUserId, 'friend_request');
  }

  Future<void> acceptFriendRequest(String requestId, String fromUid, String toUid) async {
    await _firestore.collection('users').doc(toUid).update({'friends': FieldValue.arrayUnion([fromUid])});
    await _firestore.collection('users').doc(fromUid).update({'friends': FieldValue.arrayUnion([toUid])});
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  Future<void> removeFriend(String userId, String friendId) async {
    await _firestore.collection('users').doc(userId).update({'friends': FieldValue.arrayRemove([friendId])});
    await _firestore.collection('users').doc(friendId).update({'friends': FieldValue.arrayRemove([userId])});
  }

  Future<void> blockUser(String userId, String blockedId) async {
    await _firestore.collection('users').doc(userId).update({'blockedUsers': FieldValue.arrayUnion([blockedId])});
  }

  Future<void> unblockUser(String userId, String blockedId) async {
    await _firestore.collection('users').doc(userId).update({'blockedUsers': FieldValue.arrayRemove([blockedId])});
  }

  // --- CZAT ---
  Future<String> getOrCreateChat(String userId1, String userId2) async {
    String chatId = userId1.hashCode <= userId2.hashCode ? '$userId1-$userId2' : '$userId2-$userId1';
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'users': [userId1, userId2],
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore.collection('chats').doc(chatId).collection('messages').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> sendMessage(String chatId, String senderId, String? text, {String? imageUrl, Duration? expireDuration}) async {
    final now = DateTime.now();
    final expiresAt = expireDuration != null ? now.add(expireDuration) : now.add(const Duration(days: 365 * 10));

    final msg = {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
    await _firestore.collection('chats').doc(chatId).collection('messages').add(msg);
    await _firestore.collection('chats').doc(chatId).update({'lastMessage': msg});
  }

  Future<String> uploadChatImage(File file, String chatId) async {
    String name = DateTime.now().millisecondsSinceEpoch.toString();
    var ref = _storage.ref().child('chats/$chatId/$name');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // --- POWIADOMIENIA ---
  Stream<QuerySnapshot> getNotifications(String userId) {
    return _firestore.collection('users').doc(userId).collection('notifications').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    await _firestore.collection('users').doc(userId).collection('notifications').doc(notificationId).update({'read': true});
  }

  Future<void> sendNotification(String toUserId, String fromUserId, String type, {Map<String, dynamic>? extraData}) async {
    await _firestore.collection('users').doc(toUserId).collection('notifications').add({
      'type': type,
      'from': fromUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'extraData': extraData,
    });
  }
}
