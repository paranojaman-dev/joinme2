import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/models/pin_model.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

  // --- LOKALIZACJA ---
  Future<void> updateUserLocation(String uid, double lat, double lng) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'location': GeoPoint(lat, lng),
        'status_info.lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print("❌ Błąd aktualizacji lokalizacji: $e");
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
    DocumentReference ref = await _firestore.collection('events').add(data);
    
    final creatorDoc = await _firestore.collection('users').doc(event.creatorId).get();
    if (creatorDoc.exists) {
      final List friends = creatorDoc.data()?['friends'] ?? [];
      String creatorName = creatorDoc.data()?['nickname'] ?? 'Ktoś';
      for (String friendId in friends) {
        await sendNotification(friendId, event.creatorId, 'friend_event_created', extraData: {
          'eventId': ref.id,
          'eventTitle': event.title,
          'senderName': creatorName
        });
      }
    }

    if (!isPrivate) {
      final allUsers = await _firestore.collection('users').get();
      for (var userDoc in allUsers.docs) {
        if (userDoc.id == event.creatorId) continue;
        final userData = userDoc.data();
        if (userData['notifyAllEvents'] == true && userData['location'] != null) {
          GeoPoint userLoc = userData['location'];
          double distance = Geolocator.distanceBetween(
            event.latitude, event.longitude,
            userLoc.latitude, userLoc.longitude
          );
          if (distance < 10000) { 
            await sendNotification(userDoc.id, event.creatorId, 'new_event_nearby', extraData: {
              'eventId': ref.id,
              'eventTitle': event.title
            });
          }
        }
      }
    }
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await _firestore.collection('events').doc(eventId).update(data);
  }

  Future<void> deleteEvent(String eventId) async {
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (eventDoc.exists) {
      final eventData = eventDoc.data()!;
      final String creatorId = eventData['creatorId'];
      final String eventTitle = eventData['title'];

      final creatorUserDoc = await _firestore.collection('users').doc(creatorId).get();
      if (creatorUserDoc.exists) {
        String creatorName = creatorUserDoc.data()?['nickname'] ?? 'Ktoś';
        final List friends = creatorUserDoc.data()?['friends'] ?? [];
        for (String friendId in friends) {
          await sendNotification(friendId, creatorId, 'friend_event_deleted', extraData: {
            'eventTitle': eventTitle,
            'senderName': creatorName
          });
        }
      }
    }
    await _firestore.collection('events').doc(eventId).delete();
  }

  Future<void> joinEvent(String eventId, String userId) async {
    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayUnion([userId])
    });
    
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (eventDoc.exists) {
      final creatorId = eventDoc.data()?['creatorId'];
      final userDoc = await _firestore.collection('users').doc(userId).get();
      String userName = userDoc.exists ? (userDoc.data()?['nickname'] ?? 'Ktoś') : 'Ktoś';
      await sendNotification(creatorId, userId, 'event_joined', extraData: {
        'eventTitle': eventDoc.data()?['title'],
        'senderName': userName
      });
    }
  }

  Future<void> leaveEvent(String eventId, String userId) async {
    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayRemove([userId])
    });
    
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (eventDoc.exists) {
      final creatorId = eventDoc.data()?['creatorId'];
      final userDoc = await _firestore.collection('users').doc(userId).get();
      String userName = userDoc.exists ? (userDoc.data()?['nickname'] ?? 'Ktoś') : 'Ktoś';
      await sendNotification(creatorId, userId, 'event_left', extraData: {
        'eventTitle': eventDoc.data()?['title'],
        'senderName': userName
      });
    }
  }

  Future<void> kickParticipant(String eventId, String participantId) async {
    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayRemove([participantId])
    });
    
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (eventDoc.exists) {
      await sendNotification(participantId, eventDoc.data()?['creatorId'], 'kicked_from_event', extraData: {
        'eventTitle': eventDoc.data()?['title']
      });
    }
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

  Future<void> updatePin(String pinId, Map<String, dynamic> data) async {
    await _firestore.collection('pins').doc(pinId).update(data);
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
      'notifyFriends': true,
      'notifyFriendEvents': true,
      'notifyAllEvents': true,
      'shareLocation': true,
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

  Future<void> updateNotificationSettings(String uid, {bool? friends, bool? friendEvents, bool? allEvents}) async {
    Map<String, dynamic> updates = {};
    if (friends != null) updates['notifyFriends'] = friends;
    if (friendEvents != null) updates['notifyFriendEvents'] = friendEvents;
    if (allEvents != null) updates['notifyAllEvents'] = allEvents;
    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
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
      if (user != null && user.uid == uid) await user.delete();
    } catch (e) {
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
    final senderDoc = await _firestore.collection('users').doc(fromUserId).get();
    String senderName = senderDoc.exists ? (senderDoc.data()?['nickname'] ?? 'Ktoś') : 'Ktoś';
    await sendNotification(toUserId, fromUserId, 'friend_request', extraData: {'senderName': senderName});
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

  Future<void> sendMessage(String chatId, String senderId, String? text, {String? imageUrl, Duration? expireDuration, Map<String, dynamic>? extraData}) async {
    final now = DateTime.now();
    final expiresAt = expireDuration != null ? now.add(expireDuration) : now.add(const Duration(days: 365 * 10));
    final msg = {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'extraData': extraData,
    };
    await _firestore.collection('chats').doc(chatId).collection('messages').add(msg);
    await _firestore.collection('chats').doc(chatId).update({'lastMessage': msg});
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final List users = chatDoc.data()?['users'] ?? [];
      final String receiverId = users.firstWhere((u) => u != senderId, orElse: () => "");
      if (receiverId.isNotEmpty) {
        final senderDoc = await _firestore.collection('users').doc(senderId).get();
        String senderName = senderDoc.exists ? (senderDoc.data()?['nickname'] ?? 'Ktoś') : 'Ktoś';
        await sendNotification(receiverId, senderId, 'new_message', extraData: {
          'text': text ?? '📸 Zdjęcie',
          'senderName': senderName
        });
      }
    }
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
    final userDoc = await _firestore.collection('users').doc(toUserId).get();
    if (!userDoc.exists) return;
    final userData = userDoc.data() as Map<String, dynamic>;
    bool shouldSend = true;
    if (type == 'friend_request' || type == 'new_message') {
      shouldSend = userData['notifyFriends'] ?? true;
    } else if (type == 'friend_event_created' || type == 'friend_event_deleted') {
      shouldSend = userData['notifyFriendEvents'] ?? true;
    } else if (type == 'new_event_nearby') {
      shouldSend = userData['notifyAllEvents'] ?? true;
    }
    if (shouldSend) {
      await _firestore.collection('users').doc(toUserId).collection('notifications').add({
        'type': type,
        'from': fromUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'extraData': extraData,
      });
    }
  }
}
