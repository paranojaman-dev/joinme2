import 'dart:async';
import 'package:flutter/material.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/screens/notifications_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/services/notification_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'map_screen.dart';
import 'events_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import '../utils/constants.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _databaseService.saveUserToken(_currentUserId);
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationSubscription = _databaseService.getNotifications(_currentUserId).listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final bool isRead = data['read'] ?? false;
          final Timestamp? timestamp = data['timestamp'] as Timestamp?;

          if (!isRead && timestamp != null) {
             final diff = DateTime.now().difference(timestamp.toDate()).inSeconds;
             if (diff < 15) {
                _triggerSystemNotification(data);
             }
          }
        }
      }
    });
  }

  void _triggerSystemNotification(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String;
    final extraData = data['extraData'] as Map<String, dynamic>?;
    final loc = AppLocalizations.of(context)!;

    String title = "JoinMe";
    String body = "";
    String senderName = extraData?['senderName'] ?? loc.translate('someone');
    String eventTitle = extraData?['eventTitle'] ?? "";

    switch (type) {
      case 'new_message':
        title = senderName;
        body = extraData?['text'] ?? "...";
        break;
      case 'friend_request':
        title = loc.translate('friend_request');
        body = "${loc.translate('friend_req_from')} $senderName";
        break;
      case 'friend_event_created':
        title = loc.translate('new_notification');
        body = "$senderName ${loc.translate('friend_created_event')} $eventTitle";
        break;
      case 'friend_event_deleted':
        title = loc.translate('new_notification');
        body = "$senderName ${loc.translate('friend_deleted_event')} $eventTitle";
        break;
      case 'new_event_nearby':
        title = loc.translate('new_event_nearby_title');
        body = eventTitle;
        break;
      case 'event_joined':
        title = loc.translate('event_joined');
        body = "$senderName dołączył do Twojego wydarzenia $eventTitle";
        break;
      case 'event_left':
        title = "Opuścił wydarzenie";
        body = "$senderName opuścił Twoje wydarzenie $eventTitle";
        break;
      case 'kicked_from_event':
        title = "Usunięto z wydarzenia";
        body = "Twórca usunął Cię z wydarzenia $eventTitle";
        break;
      default:
        title = loc.translate('new_notification');
        body = "...";
    }

    NotificationService.showSimpleNotification(title: title, body: body);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  final List<Widget> _screens = [
    const MapScreen(),
    const EventsScreen(),
    const FriendsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Consumer<AppStateManager>(
      builder: (context, appState, child) {
        return Scaffold(
          extendBody: true, 
          backgroundColor: AppColors.backgroundColor,
          appBar: AppBar(
            leadingWidth: 120,
            leading: const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Icon(Icons.chair, color: AppColors.primaryColor, size: 24),
                  SizedBox(width: 8),
                  Text('JoinMe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (appState.currentCity.isNotEmpty) ...[
                  const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(
                    appState.currentCity, 
                    style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w400)
                  ),
                ] else
                  Text(loc.translate('loading'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            backgroundColor: AppColors.surfaceColor,
            elevation: 8,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
              ),
            ],
          ),
          body: _screens[appState.currentTabIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, -2))
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: appState.currentTabIndex,
              onTap: (index) => appState.setTabIndex(index),
              backgroundColor: AppColors.surfaceColor,
              selectedItemColor: AppColors.primaryColor,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              elevation: 0, 
              items: [
                BottomNavigationBarItem(icon: const Icon(Icons.map), label: loc.translate('map')),
                BottomNavigationBarItem(icon: const Icon(Icons.event), label: loc.translate('events')),
                BottomNavigationBarItem(icon: const Icon(Icons.people), label: loc.translate('friends')),
                BottomNavigationBarItem(icon: const Icon(Icons.person), label: loc.translate('profile')),
              ],
            ),
          ),
        );
      },
    );
  }
}
