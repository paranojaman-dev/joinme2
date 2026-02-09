import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/screens/create_event_screen.dart';
import 'package:joinme2/screens/notifications_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:provider/provider.dart';
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
  int _currentIndex = 0;
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

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
          backgroundColor: AppColors.backgroundColor,
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.chair, color: AppColors.primaryColor),
                SizedBox(width: 12),
                Text('JoinMe'),
              ],
            ),
            backgroundColor: AppColors.surfaceColor,
            actions: [
              _buildNotificationsButton(),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                },
              ),
              IconButton(
                icon: Icon(appState.isOnline ? Icons.visibility : Icons.visibility_off),
                color: appState.isOnline ? Colors.green : Colors.red,
                onPressed: () => appState.toggleOnlineStatus(),
              ),
            ],
          ),
          body: _screens[_currentIndex],
          // USUNIĘTO: floatingActionButton (stara ikonka na dole zniknęła)
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: AppColors.surfaceColor,
            selectedItemColor: AppColors.primaryColor,
            unselectedItemColor: const Color(0xFF757575),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.map),
                label: loc.translate('map'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.event),
                label: loc.translate('events'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.people),
                label: loc.translate('friends'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: loc.translate('profile'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationsButton() {
    return StreamBuilder<QuerySnapshot>(
      stream: _databaseService.getNotifications(_currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
            },
          );
        }
        final unreadCount = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          return data != null && data['read'] == false;
        }).length;

        return Badge(
          label: Text(unreadCount.toString()),
          isLabelVisible: unreadCount > 0,
          child: IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
            },
          ),
        );
      },
    );
  }
}
