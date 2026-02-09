import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/screens/create_event_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/constants.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final DatabaseService _databaseService = DatabaseService();
  String _selectedFilter = 'all';

  void _joinEvent(String eventId) {
    final loc = AppLocalizations.of(context)!;
    _databaseService.joinEvent(eventId, _currentUserId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.translate('event_joined')), backgroundColor: Colors.green),
    );
  }

  void _leaveEvent(String eventId) {
    final loc = AppLocalizations.of(context)!;
    _databaseService.leaveEvent(eventId, _currentUserId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.translate('leave_event')), backgroundColor: Colors.orange),
    );
  }

  void _deleteEvent(String eventId) async {
    final loc = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('delete_event_title')),
        content: Text(loc.translate('delete_event_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.translate('no'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(loc.translate('yes'), style: const TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _databaseService.deleteEvent(eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('event_removed')))
        );
      }
    }
  }

  void _showEventDetails(Event event) {
    final loc = AppLocalizations.of(context)!;
    final isCreator = event.creatorId == _currentUserId;
    final isJoined = event.participants.contains(_currentUserId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (event.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(event.imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(event.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      if (isCreator)
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CreateEventScreen(eventToEdit: event)));
                            }),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                              Navigator.pop(context);
                              _deleteEvent(event.id);
                            }),
                          ],
                        ),
                    ],
                  ),
                  Text('${loc.translate('by')} ${event.creatorName}', style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 32),
                  _buildDetailRow(Icons.location_on, event.address),
                  _buildDetailRow(Icons.people, '${event.participants.length} / ${event.maxParticipants} ${loc.translate('joined_count')}'),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isCreator ? null : (isJoined ? () => _leaveEvent(event.id) : () => _joinEvent(event.id)),
                            style: ElevatedButton.styleFrom(backgroundColor: isJoined ? Colors.red : Colors.green),
                            child: Text(isJoined ? loc.translate('leave_event') : loc.translate('join_event')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Icon(icon, size: 20, color: Colors.grey), const SizedBox(width: 12), Text(text)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    final List<Map<String, String>> filters = [
      {'key': 'all', 'label': loc.translate('all')},
      {'key': 'cinema', 'label': loc.translate('cinema')},
      {'key': 'walk', 'label': loc.translate('walk')},
      {'key': 'discussion', 'label': loc.translate('discussion')},
      {'key': 'restaurant', 'label': loc.translate('restaurant')},
      {'key': 'bar', 'label': loc.translate('bar')},
      {'key': 'disco', 'label': loc.translate('disco')},
      {'key': 'concert', 'label': loc.translate('concert')},
      {'key': 'meeting', 'label': loc.translate('meeting')},
      {'key': 'board_games', 'label': loc.translate('board_games')},
      {'key': 'trip', 'label': loc.translate('trip')},
      {'key': 'match', 'label': loc.translate('match')},
      {'key': 'grill', 'label': loc.translate('grill')},
      {'key': 'gallery', 'label': loc.translate('gallery')},
      {'key': 'shopping', 'label': loc.translate('shopping')},
      {'key': 'party', 'label': loc.translate('party')},
      {'key': 'my_events', 'label': loc.translate('my_events')},
    ];

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('events'))),
      body: Stack(
        children: [
          // SUBTELNE LOGO W TLE
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Center(child: Icon(Icons.chair, size: 300, color: Colors.green.shade400)),
            ),
          ),
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: filters.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f['label']!),
                      selected: _selectedFilter == f['key'],
                      onSelected: (val) => setState(() => _selectedFilter = f['key']!),
                    ),
                  )).toList(),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _databaseService.getEvents(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var events = snapshot.data!.docs.map((d) => Event.fromFirestore(d)).toList();
                    
                    if (_selectedFilter == 'my_events') {
                      events = events.where((e) => e.creatorId == _currentUserId).toList();
                    } else if (_selectedFilter != 'all') {
                      events = events.where((e) => e.type == _selectedFilter).toList();
                    }

                    if (events.isEmpty) {
                      return Center(child: Text(loc.translate('no_msgs'))); 
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: events.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage: events[i].imageUrl.isNotEmpty ? NetworkImage(events[i].imageUrl) : null,
                          child: events[i].imageUrl.isEmpty ? Icon(_getIcon(events[i].type)) : null,
                        ),
                        title: Text(events[i].title),
                        subtitle: Text('${events[i].participants.length}/${events[i].maxParticipants} ${loc.translate('participants')}'),
                        onTap: () => _showEventDetails(events[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'cinema': return Icons.movie;
      case 'walk': return Icons.directions_walk;
      case 'bar': return Icons.local_bar;
      case 'restaurant': return Icons.restaurant;
      case 'board_games': return Icons.casino;
      case 'match': return Icons.sports_soccer;
      case 'concert': return Icons.music_note;
      case 'shopping': return Icons.shopping_cart;
      case 'gallery': return Icons.palette;
      case 'discussion': return Icons.forum;
      case 'disco': return Icons.nightlife;
      case 'meeting': return Icons.people;
      case 'trip': return Icons.map;
      case 'grill': return Icons.outdoor_grill;
      case 'party': return Icons.celebration;
      default: return Icons.event;
    }
  }
}
