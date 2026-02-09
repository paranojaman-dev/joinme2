import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:joinme2/models/event_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- EVENTS METHODS ---

  Stream<QuerySnapshot> getEvents() {
    return _firestore.collection('events').where('isActive', isEqualTo: true).snapshots();
  }

  Future<QuerySnapshot> getEventsOnce() {
    return _firestore.collection('events').where('isActive', isEqualTo: true).get();
  }

  Future<void> createEvent(Event event) async {
    await _firestore.collection('events').add(event.toMap());
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await _firestore.collection('events').doc(eventId).update(data);
  }

  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection('events').doc(eventId).delete();
  }

  Future<void> joinEvent(String eventId, String userId) async {
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) return;
    
    final eventData = eventDoc.data() as Map<String, dynamic>;
    final String creatorId = eventData['creatorId'];
    final String eventTitle = eventData['title'] ?? '';

    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayUnion([userId])
    });

    // Powiadomienie dla twórcy o nowym uczestniku
    if (creatorId != userId) {
      final userDoc = await getUserData(userId);
      final userName = userDoc.exists ? (userDoc.data() as Map<String, dynamic>)['displayName'] : "Ktoś";
      
      await sendNotification(
        creatorId, 
        userId, 
        'event_joined', 
        extraData: {'senderName': userName, 'eventTitle': eventTitle}
      );
    }
  }

  Future<void> leaveEvent(String eventId, String userId) async {
    await _firestore.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayRemove([userId])
    });
  }

  // --- USER METHODS ---

  Stream<QuerySnapshot> getUsers() {
    return _firestore.collection('users').snapshots();
  }

  Future<QuerySnapshot> getUsersOnce() {
    return _firestore.collection('users').get();
  }

  Future<void> createUserDocument(User user, {String? displayName, DateTime? dateOfBirth}) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? 'Użytkownik',
        'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth) : null,
        'interests': [],
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'friends': [],
        'blockedUsers': [],
        'isPremium': false,
        'visibilitySettings': {
          'showToMen': true,
          'showToWomen': true,
          'showToOther': true,
          'ageRange': {'min': 18, 'max': 99}
        },
        'status_info': {'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()},
        'location': const GeoPoint(0, 0)
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentSnapshot> getUserData(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }
  
  Future<void> updateUserStatus(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).set({
      'status_info': {
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp()
        }
    }, SetOptions(merge: true));
  }

  Future<void> updateUserLocation(String uid, double lat, double lng) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'location': GeoPoint(lat, lng),
        'status_info': {'lastSeen': FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Błąd aktualizacji lokalizacji: $e');
    }
  }

  Future<void> deleteAccount(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  Future<void> updateMapStyle(String uid, String styleName) async {
    await _firestore.collection('users').doc(uid).set({
      'mapStyle': styleName,
    }, SetOptions(merge: true));
  }

  // --- NOTIFICATIONS ---

  Stream<QuerySnapshot> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
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

  // --- FRIENDS & RELATIONSHIPS ---

  Stream<QuerySnapshot> getFriendRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptFriendRequest(String requestId, String fromUserId, String toUserId) async {
    await _firestore.collection('users').doc(toUserId).update({
      'friends': FieldValue.arrayUnion([fromUserId])
    });
    await _firestore.collection('users').doc(fromUserId).update({
      'friends': FieldValue.arrayUnion([toUserId])
    });
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  Stream<DocumentSnapshot> getFriends(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
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

  Future<void> blockUser(String userId, String blockedUserId) async {
    await _firestore.collection('users').doc(userId).update({
      'blockedUsers': FieldValue.arrayUnion([blockedUserId])
    });
  }

  Future<void> unblockUser(String userId, String blockedUserId) async {
    await _firestore.collection('users').doc(blockedUserId).update({
      'blockedUsers': FieldValue.arrayRemove([blockedUserId])
    });
  }

  Future<void> removeFriend(String userId, String friendId) async {
    await _firestore.collection('users').doc(userId).update({
      'friends': FieldValue.arrayRemove([friendId])
    });
    await _firestore.collection('users').doc(friendId).update({
      'friends': FieldValue.arrayRemove([userId])
    });
  }

  Future<QuerySnapshot> getFilteredUsers(Map<String, dynamic> filters) {
    return _firestore.collection('users').get();
  }

  // --- CHAT METHODS ---

  Future<String> getOrCreateChat(String userId1, String userId2) async {
    String chatId = userId1.hashCode <= userId2.hashCode ? '$userId1-$userId2' : '$userId2-$userId1';
    final chatDoc = _firestore.collection('chats').doc(chatId);
    final docSnapshot = await chatDoc.get();
    if (!docSnapshot.exists) {
      await chatDoc.set({
        'users': [userId1, userId2],
        'lastMessage': null,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .snapshots();
  }
  
  Stream<QuerySnapshot> getChatMessagesWithCleanup(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(String chatId, String senderId, String text, {Duration? expireDuration}) async {
    final now = DateTime.now();
    final expiresAt = expireDuration != null ? now.add(expireDuration) : now.add(const Duration(days: 365 * 10));

    final messageData = {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
    
    await _firestore.collection('chats').doc(chatId).collection('messages').add(messageData);
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': messageData,
    });

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final List<dynamic> userIds = List.from(chatDoc.data()?['users'] ?? []);
    
    for (String uid in userIds) {
      if (uid == senderId && userIds.length > 1 && userIds[0] != userIds[1]) continue; 
      
      final senderDoc = await getUserData(senderId);
      final senderName = senderDoc.exists ? (senderDoc.data() as Map<String, dynamic>)['displayName'] : "Ktoś";
      
      await sendNotification(uid, senderId, 'new_message', extraData: {'text': text, 'senderName': senderName});
      
      if (userIds.length > 1 && userIds[0] != userIds[1]) break;
    }
  }
}
