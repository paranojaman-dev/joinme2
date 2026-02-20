import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:joinme2/models/user_model.dart';
import 'package:joinme2/screens/profile_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
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
    final loc = AppLocalizations.of(context)!;
    final isMe = widget.userId == _currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? loc.translate('profile') : loc.translate('app_title')),
      ),
      body: Stack(
        children: [
          // SUBTELNE LOGO W TLE (10% Widoczności)
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Center(child: Icon(Icons.chair, size: 300, color: Colors.green.shade400)),
            ),
          ),
          FutureBuilder<DocumentSnapshot>(
            future: _databaseService.getUserData(widget.userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || _isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final user = UserModel.fromMap(userData);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.green.shade700,
                      child: CircleAvatar(
                        radius: 66,
                        backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
                        child: user.photoURL.isEmpty ? const Icon(Icons.person, size: 70) : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(user.displayName, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(user.dateOfBirth != null ? '${_calculateAge(user.dateOfBirth!)} ${loc.translate('years')}' : loc.translate('no_birth_date'), 
                         style: const TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 24),
                    if (user.status != null && user.status!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceColor.withOpacity(0.8), 
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.green.shade900.withOpacity(0.5))
                        ),
                        child: Text(user.status!, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 32),
                    _buildInfoRow(Icons.favorite, loc.translate('interests_hint').split('(')[0], user.interests.join(', ')),
                    if (user.languages != null && user.languages!.isNotEmpty)
                      _buildInfoRow(Icons.translate, loc.translate('languages_hint').split('(')[0], user.languages!.join(', ')),
                    const SizedBox(height: 40),
                    _buildActionButtons(loc, isMe),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green.shade700, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.trim(), style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value.isEmpty ? '---' : value, style: const TextStyle(fontSize: 17)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations loc, bool isMe) {
    if (isMe) {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          icon: const Icon(Icons.edit),
          label: Text(loc.translate('edit_profile').toUpperCase()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700, 
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
          ),
        ),
      );
    }

    if (_isBlocked) {
      return ElevatedButton(
        onPressed: () {
          _databaseService.unblockUser(_currentUserId, widget.userId);
          setState(() => _isBlocked = false);
        }, 
        child: Text(loc.translate('unblock'))
      );
    }

    return Column(
      children: [
        if (_isFriend)
          SizedBox(
            width: double.infinity,
            height: 55,
            child: OutlinedButton.icon(
              onPressed: () {
                 _databaseService.removeFriend(_currentUserId, widget.userId);
                 setState(() => _isFriend = false);
              }, 
              icon: const Icon(Icons.person_remove),
              label: const Text('USUŃ ZE ZNAJOMYCH'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _friendRequestSent ? null : () {
                 _databaseService.sendFriendRequest(_currentUserId, widget.userId);
                 setState(() => _friendRequestSent = true);
              }, 
              icon: const Icon(Icons.person_add),
              label: Text(_friendRequestSent ? 'ZAPROSZENIE WYSŁANE' : 'DODAJ DO ZNAJOMYCH'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ),
      ],
    );
  }
}
