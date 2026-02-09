import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:joinme2/models/user_model.dart';
import 'package:joinme2/screens/profile_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/constants.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({required this.userId, super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isFriend = false;
  bool _isBlocked = false;
  bool _friendRequestSent = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRelationship();
  }

  Future<void> _checkRelationship() async {
    if (widget.userId == _currentUserId) {
      setState(() => _isLoading = false);
      return;
    }
    
    final currentUserData = await _databaseService.getUserData(_currentUserId);
    if (currentUserData.exists) {
      final data = currentUserData.data() as Map<String, dynamic>;
      final friends = data['friends'] ?? [];
      final blocked = data['blockedUsers'] ?? [];

      setState(() {
        _isFriend = friends.contains(widget.userId);
        _isBlocked = blocked.contains(widget.userId);
        _isLoading = false;
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userId == _currentUserId ? 'Mój Profil' : 'Profil użytkownika'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _databaseService.getUserData(widget.userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final user = UserModel.fromMap(userData);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
                  child: user.photoURL.isEmpty ? const Icon(Icons.person, size: 60) : null,
                ),
                const SizedBox(height: 16),
                Text(user.displayName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(user.dateOfBirth != null ? '${_calculateAge(user.dateOfBirth!)} lat' : 'Wiek nieznany', style: const TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 16),
                if (user.status != null && user.status!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surfaceColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(user.status!, style: const TextStyle(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 24),
                _buildInfoRow(Icons.interests, 'Zainteresowania', user.interests.join(', ')),
                if (user.languages != null && user.languages!.isNotEmpty)
                  _buildInfoRow(Icons.language, 'Języki', user.languages!.join(', ')),
                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value.isEmpty ? 'Brak informacji' : value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.userId == _currentUserId) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          icon: const Icon(Icons.edit),
          label: const Text('EDYTUJ MÓJ PROFIL'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
        ),
      );
    }

    if (_isBlocked) {
      return ElevatedButton(onPressed: () {
        _databaseService.unblockUser(_currentUserId, widget.userId);
        setState(() => _isBlocked = false);
      }, child: const Text('Odblokuj'));
    }

    return Column(
      children: [
        if (_isFriend)
          ElevatedButton(onPressed: () {
             _databaseService.removeFriend(_currentUserId, widget.userId);
             setState(() => _isFriend = false);
          }, child: const Text('Usuń ze znajomych'))
        else if (_friendRequestSent)
          const ElevatedButton(onPressed: null, child: Text('Zaproszenie wysłane'))
        else
          ElevatedButton(onPressed: () {
             _databaseService.sendFriendRequest(_currentUserId, widget.userId);
             setState(() => _friendRequestSent = true);
          }, child: const Text('Dodaj do znajomych')),
        const SizedBox(height: 8),
        TextButton(onPressed: () {
           _databaseService.blockUser(_currentUserId, widget.userId);
           setState(() => _isBlocked = true);
        }, child: const Text('Zablokuj użytkownika', style: TextStyle(color: Colors.red))),
      ],
    );
  }
}
