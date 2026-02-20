import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/screens/event_details_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/constants.dart';
import 'package:provider/provider.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final DatabaseService _databaseService = DatabaseService();
  String _selectedFilter = 'all';

  void _showEventDetails(Event event) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final appState = Provider.of<AppStateManager>(context, listen: false);
    
    final List<Map<String, String>> filters = [
      {'key': 'all', 'label': loc.translate('all')},
      {'key': 'cinema', 'label': loc.translate('cinema')},
      {'key': 'walk', 'label': loc.translate('walk')},
      {'key': 'restaurant', 'label': loc.translate('restaurant')},
      {'key': 'my_events', 'label': loc.translate('my_events')},
    ];

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('events'))),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
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
                    
                    // Mapujemy dokumenty na obiekty Event
                    var events = snapshot.data!.docs.map((d) => Event.fromFirestore(d)).toList();
                    
                    // FILTRACJA
                    if (_selectedFilter == 'my_events') {
                      events = events.where((e) => e.creatorId == _currentUserId).toList();
                    } else if (_selectedFilter != 'all') {
                      events = events.where((e) => e.type == _selectedFilter).toList();
                    }

                    if (events.isEmpty) return Center(child: Text(loc.translate('no_msgs'))); 

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: events.length,
                      itemBuilder: (context, i) {
                        final event = events[i];
                        
                        // ZABEZPIECZENIE: Sprawdzamy czy twórca istnieje (opcjonalne, ale pomocne przy starych śmieciach)
                        return FutureBuilder<DocumentSnapshot>(
                          future: _databaseService.getUserData(event.creatorId),
                          builder: (context, userSnap) {
                            // Jeśli twórca nie istnieje, nie pokazujemy wydarzenia
                            if (userSnap.hasData && !userSnap.data!.exists) {
                              return const SizedBox.shrink();
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: AppColors.surfaceColor.withOpacity(0.9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: (event.imageUrl.isNotEmpty && event.imageUrl.startsWith('http')) 
                                          ? NetworkImage(event.imageUrl) 
                                          : null,
                                      child: (event.imageUrl.isEmpty || !event.imageUrl.startsWith('http')) 
                                          ? const Icon(Icons.event) 
                                          : null,
                                    ),
                                    title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${event.participants.length}/${event.maxParticipants} ${loc.translate('participants')}'),
                                    onTap: () => _showEventDetails(event),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            appState.jumpToLocationOnMap(LatLng(event.latitude, event.longitude));
                                          },
                                          icon: const Icon(Icons.map, size: 18),
                                          label: Text(loc.translate('show_on_map')),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () => _showEventDetails(event),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                          child: Text(loc.translate('check')),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          }
                        );
                      },
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
}
