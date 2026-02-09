import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/models/user_model.dart';
import 'package:joinme2/screens/user_profile_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/constants.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  const EventDetailsScreen({required this.event, super.key});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final DatabaseService _databaseService = DatabaseService();
  late Event _currentEvent;
  List<String> _myFriendsUids = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final myData = await _databaseService.getUserData(_currentUserId);
    if (myData.exists) {
      _myFriendsUids = List<String>.from(myData.get('friends') ?? []);
    }
    setState(() => _isLoading = false);
  }

  void _toggleJoin() async {
    final isJoined = _currentEvent.participants.contains(_currentUserId);
    final loc = AppLocalizations.of(context)!;
    if (isJoined) {
      await _databaseService.leaveEvent(_currentEvent.id, _currentUserId);
      await _databaseService.sendNotification(_currentEvent.creatorId, _currentUserId, 'event_left');
    } else {
      if (_currentEvent.participants.length >= _currentEvent.maxParticipants) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('no_spots'))));
        return;
      }
      await _databaseService.joinEvent(_currentEvent.id, _currentUserId);
      await _databaseService.sendNotification(_currentEvent.creatorId, _currentUserId, 'event_joined');
    }

    final updatedDoc = await FirebaseFirestore.instance.collection('events').doc(_currentEvent.id).get();
    setState(() {
      _currentEvent = Event.fromFirestore(updatedDoc);
    });
  }

  void _removeParticipant(String uid) async {
    await _databaseService.leaveEvent(_currentEvent.id, uid);
    final updatedDoc = await FirebaseFirestore.instance.collection('events').doc(_currentEvent.id).get();
    setState(() {
      _currentEvent = Event.fromFirestore(updatedDoc);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = _currentEvent.creatorId == _currentUserId;
    final isJoined = _currentEvent.participants.contains(_currentUserId);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('events'))),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentEvent.imageUrl.isNotEmpty)
                  Image.network(_currentEvent.imageUrl, height: 250, width: double.infinity, fit: BoxFit.cover)
                else
                  Container(height: 150, color: Colors.grey[900], child: const Center(child: Icon(Icons.event, size: 80, color: Colors.white24))),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(_currentEvent.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
                          Chip(label: Text(_currentEvent.type), backgroundColor: AppColors.primaryColor.withOpacity(0.2)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // KLIKALNY ORGANIZATOR
                      InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: _currentEvent.creatorId))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_pin, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                '${loc.translate('organizer')}: ${_currentEvent.creatorName}',
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 40),
                      _buildInfoRow(Icons.location_on, _currentEvent.address),
                      _buildInfoRow(Icons.access_time, 'Start: ${DateFormat.yMMMd().add_Hm().format(_currentEvent.dateTime)}'),
                      const SizedBox(height: 20),
                      Text(loc.translate('about_event'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(_currentEvent.description, style: const TextStyle(fontSize: 16, height: 1.4)),
                      const Divider(height: 40),
                      Text('${loc.translate('participants')} (${_currentEvent.participants.length} / ${_currentEvent.maxParticipants}):', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildParticipantsList(isCreator),
                      const SizedBox(height: 40),
                      if (!isCreator)
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _toggleJoin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isJoined ? Colors.red : AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                            ),
                            child: Text(isJoined ? loc.translate('leave_event') : loc.translate('join_event')),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildParticipantsList(bool isCreator) {
    final loc = AppLocalizations.of(context)!;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _currentEvent.participants.length,
      itemBuilder: (context, index) {
        final uid = _currentEvent.participants[index];
        final bool isMe = uid == _currentUserId;
        final bool isFriend = _myFriendsUids.contains(uid);

        if (!isCreator && !isMe && !isFriend) {
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.lock_outline, size: 16)),
            title: Text(loc.translate('others'), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: _databaseService.getUserData(uid),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final userData = snap.data!.data() as Map<String, dynamic>?;
            if (userData == null) return const SizedBox.shrink();
            final user = UserModel.fromMap(userData);
            
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null, child: user.photoURL.isEmpty ? const Icon(Icons.person) : null),
              title: Text(isMe ? "${user.displayName} (${loc.translate('profile')})" : user.displayName),
              trailing: isCreator && !isMe
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isFriend) IconButton(icon: const Icon(Icons.person_add, color: Colors.blue), onPressed: () => _databaseService.sendFriendRequest(_currentUserId, uid)),
                      IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.red), onPressed: () => _removeParticipant(uid)),
                    ],
                  )
                : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: uid))),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(children: [Icon(icon, size: 20, color: AppColors.primaryColor), const SizedBox(width: 12), Expanded(child: Text(text))]),
    );
  }
}
