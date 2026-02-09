import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/screens/user_profile_screen.dart';
import 'package:joinme2/screens/chat_screen.dart';
import 'package:joinme2/utils/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _databaseService = DatabaseService();
  final _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('notifications')),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _databaseService.getNotifications(_currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text(loc.translate('no_requests'))); 
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;
              return _buildNotificationTile(notification.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(String notificationId, Map<String, dynamic> data) {
    final loc = AppLocalizations.of(context)!;
    final type = data['type'];
    final fromUserId = data['from'];
    final bool isRead = data['read'] ?? false;
    final String? customMessage = data['message'];
    final Map<String, dynamic>? extraData = data['extraData'] != null ? Map<String, dynamic>.from(data['extraData']) : null;

    return FutureBuilder<DocumentSnapshot>(
      future: (fromUserId == 'system' || fromUserId == null) ? null : _databaseService.getUserData(fromUserId),
      builder: (context, userSnapshot) {
        String senderName = extraData?['senderName'] ?? '...';
        if (fromUserId != 'system' && senderName == '...' && userSnapshot.hasData && userSnapshot.data!.exists) {
          final senderData = userSnapshot.data!.data() as Map<String, dynamic>;
          senderName = senderData['displayName'] ?? '...';
        }

        String title = loc.translate('notifications');
        String subtitle = customMessage ?? '';
        IconData icon = Icons.notifications;

        if (type == 'created_new_event' || type == 'updated_event') {
          title = loc.translate('events');
          String eventTitle = extraData?['eventTitle'] ?? '';
          subtitle = '$senderName ${loc.translate(type)}: $eventTitle';
          icon = Icons.event_available;
        } else if (type == 'friend_request') {
          title = loc.translate('friends');
          subtitle = '$senderName ${loc.translate('friend_req_from')}';
          icon = Icons.person_add;
        } else if (type == 'new_message') {
          title = loc.translate('friends_chats');
          subtitle = '${loc.translate('chat_hint')} $senderName';
          icon = Icons.message;
        } else if (type == 'event_joined') {
          title = loc.translate('events');
          String eventTitle = extraData?['eventTitle'] ?? '';
          subtitle = '$senderName ${loc.translate('joined_count')} $eventTitle';
          icon = Icons.person_pin_circle;
        }

        return ListTile(
          tileColor: isRead ? Colors.transparent : Colors.blue.withOpacity(0.1),
          leading: CircleAvatar(
            backgroundColor: isRead ? Colors.grey[800] : Colors.blue[900],
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
          subtitle: Text(subtitle),
          onTap: () async {
            _databaseService.markNotificationAsRead(_currentUserId, notificationId);
            
            if (type == 'created_new_event' || type == 'updated_event' || type == 'event_joined') {
              // Powiadomienia o wydarzeniach -> Wracamy do głównego ekranu (Mapy/Wydarzeń)
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (type == 'new_message') {
              // Czat
              if (fromUserId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerId: fromUserId, peerName: senderName)));
              }
            } else if (fromUserId != null) {
              // Profil użytkownika
              Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: fromUserId)));
            }
          },
        );
      },
    );
  }
}
