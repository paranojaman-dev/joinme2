import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/models/pin_model.dart';
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

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final DatabaseService _databaseService = DatabaseService();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEventDetails(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('events')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryColor,
          tabs: [
            Tab(text: loc.translate('events').toUpperCase()),
            Tab(text: loc.translate('pins').toUpperCase()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventsList(loc),
          _buildPinsList(loc),
        ],
      ),
    );
  }

  Widget _buildEventsList(AppLocalizations loc) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final List<Map<String, String>> filters = [
      {'key': 'all', 'label': loc.translate('all')},
      {'key': 'cinema', 'label': loc.translate('cinema')},
      {'key': 'walk', 'label': loc.translate('walk')},
      {'key': 'restaurant', 'label': loc.translate('restaurant')},
      {'key': 'my_events', 'label': loc.translate('my_events')},
    ];

    return Column(
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
                // Pokazujemy tylko moje własne wydarzenia
                events = events.where((e) => e.creatorId == _currentUserId).toList();
              } else {
                // Filtr 'all' lub kategorie: Nie pokazujemy moich wydarzeń, chyba że jestem uczestnikiem
                events = events.where((e) => e.creatorId != _currentUserId || e.participants.contains(_currentUserId)).toList();
                
                if (_selectedFilter != 'all') {
                  events = events.where((e) => e.type == _selectedFilter).toList();
                }
              }

              if (events.isEmpty) return Center(child: Text(loc.translate('no_msgs'))); 

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: events.length,
                itemBuilder: (context, i) {
                  final event = events[i];
                  return _buildEventCard(event, loc, appState);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPinsList(AppLocalizations loc) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    return StreamBuilder<QuerySnapshot>(
      stream: _databaseService.getPins(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final pins = snapshot.data!.docs
            .map((d) => PinModel.fromFirestore(d))
            .where((p) => p.creatorId == _currentUserId)
            .toList();

        if (pins.isEmpty) return Center(child: Text(loc.translate('no_pins')));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pins.length,
          itemBuilder: (context, i) {
            final pin = pins[i];
            return Card(
              color: AppColors.surfaceColor,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.cyan, child: Icon(Icons.push_pin, color: Colors.white)),
                title: Text(pin.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(pin.spotifyTrackId != null ? "Spotify ID: ${pin.spotifyTrackId}" : "Brak muzyki"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      onPressed: () {
                        appState.jumpToLocationOnMap(LatLng(pin.latitude, pin.longitude));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeletePin(pin.id, loc),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeletePin(String pinId, AppLocalizations loc) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('delete_pin')),
        content: Text(loc.translate('delete_pin_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.translate('no'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.translate('yes'), style: const TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await _databaseService.deletePin(pinId);
    }
  }

  Widget _buildEventCard(Event event, AppLocalizations loc, AppStateManager appState) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surfaceColor.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: event.imageUrl.isNotEmpty ? NetworkImage(event.imageUrl) : null,
              child: event.imageUrl.isEmpty ? const Icon(Icons.event) : null,
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
                  onPressed: () => appState.jumpToLocationOnMap(LatLng(event.latitude, event.longitude)),
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
}
