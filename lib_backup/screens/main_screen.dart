import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'events_screen.dart';
import 'chat_screen.dart';
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
  bool _isOnline = true;

  final List<Widget> _screens = [
    const MapScreen(),
    const EventsScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: Icon(_isOnline ? Icons.circle : Icons.circle_outlined),
            color: _isOnline ? AppColors.primaryColor : AppColors.errorColor,
            onPressed: _toggleStatus,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createEvent,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppColors.surfaceColor,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: const Color(0xFF757575),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Eventy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Czat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  void _toggleStatus() {
    setState(() => _isOnline = !_isOnline);
  }

  void _createEvent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stwórz event'),
        content: const Text('Funkcjonalność w budowie...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}