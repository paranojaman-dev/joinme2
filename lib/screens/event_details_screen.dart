import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/models/user_model.dart';
import 'package:joinme2/screens/create_event_screen.dart';
import 'package:joinme2/screens/user_profile_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/constants.dart';
import 'package:provider/provider.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _isLoading = false;
  }

  void _toggleJoin() async {
    final isJoined = _currentEvent.participants.contains(_currentUserId);
    if (isJoined) {
      await _databaseService.leaveEvent(_currentEvent.id, _currentUserId);
    } else {
      await _databaseService.joinEvent(_currentEvent.id, _currentUserId);
    }
    _refreshEvent();
  }

  void _refreshEvent() async {
    final updatedDoc = await FirebaseFirestore.instance.collection('events').doc(_currentEvent.id).get();
    if (mounted && updatedDoc.exists) {
      setState(() {
        _currentEvent = Event.fromFirestore(updatedDoc);
      });
    } else if (mounted && !updatedDoc.exists) {
       Navigator.pop(context); // Wydarzenie usunięte
    }
  }

  Future<void> _deleteEvent() async {
    final loc = AppLocalizations.of(context)!;
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('delete_event_title')),
        content: Text(loc.translate('delete_event_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.translate('no'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.translate('yes'), style: const TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await _databaseService.deleteEvent(_currentEvent.id);
      if (mounted) Navigator.pop(context);
    }
  }

  void _kickUser(String userId, String userName) async {
    final loc = AppLocalizations.of(context)!;
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Usuń uczestnika"),
        content: Text("Czy na pewno chcesz usunąć użytkownika $userName z wydarzenia?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.translate('no'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.translate('yes'), style: const TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await _databaseService.kickParticipant(_currentEvent.id, userId);
      _refreshEvent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = _currentEvent.creatorId == _currentUserId;
    final isJoined = _currentEvent.participants.contains(_currentUserId);
    final loc = AppLocalizations.of(context)!;
    final appState = Provider.of<AppStateManager>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('about_event'))),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.10,
                  child: Center(child: Icon(Icons.chair, size: 300, color: Colors.green.shade400)),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentEvent.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(_currentEvent.imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 20),
                    Text(_currentEvent.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.location_on, _currentEvent.address),
                    _buildInfoRow(Icons.access_time, DateFormat.yMMMd().add_Hm().format(_currentEvent.dateTime)),
                    const Divider(height: 40),
                    Text(loc.translate('description'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(_currentEvent.description, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 30),
                    
                    if (isCreator && _currentEvent.participants.isNotEmpty) ...[
                      Text(loc.translate('participants_list'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _currentEvent.participants.length,
                          itemBuilder: (context, index) {
                            final userId = _currentEvent.participants[index];
                            return FutureBuilder<DocumentSnapshot>(
                              future: _databaseService.getUserData(userId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox.shrink();
                                final data = snapshot.data!.data() as Map<String, dynamic>;
                                final photo = data['photoURL'] ?? '';
                                final name = data['nickname'] ?? 'User';
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          GestureDetector(
                                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserProfileScreen(userId: userId))),
                                            child: CircleAvatar(
                                              radius: 25,
                                              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                              child: photo.isEmpty ? const Icon(Icons.person) : null,
                                            ),
                                          ),
                                          Positioned(
                                            right: -5, top: -5,
                                            child: GestureDetector(
                                              onTap: () => _kickUser(userId, name),
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(name, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                    ],
                                  ),
                                );
                              }
                            );
                          },
                        ),
                      ),
                      const Divider(height: 40),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          appState.jumpToLocationOnMap(LatLng(_currentEvent.latitude, _currentEvent.longitude));
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        icon: const Icon(Icons.map_outlined, color: Colors.blue),
                        label: Text(loc.translate('show_on_map'), style: const TextStyle(color: Colors.blue)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (isCreator) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateEventScreen(eventToEdit: _currentEvent))),
                          icon: const Icon(Icons.edit),
                          label: Text(loc.translate('edit_event')),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _deleteEvent,
                          icon: const Icon(Icons.delete_forever),
                          label: Text(loc.translate('delete_event')),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                        ),
                      ),
                    ],

                    if (!isCreator)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _toggleJoin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isJoined ? Colors.red : Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: Text(isJoined ? loc.translate('leave_event') : loc.translate('join_event')),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(children: [Icon(icon, size: 20, color: Colors.green), const SizedBox(width: 12), Expanded(child: Text(text))]),
    );
  }
}
