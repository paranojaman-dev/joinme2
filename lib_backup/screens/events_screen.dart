import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/event_model.dart';
import 'create_event_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Event> _events = Event.sampleEvents;
  String _selectedFilter = 'Wszystkie';

  final List<String> _filters = [
    'Wszystkie',
    'Planszówka',
    'Kino',
    'Piwo',
    'Jedzenie',
    'Moje eventy',
  ];

  List<Event> get _filteredEvents {
    if (_selectedFilter == 'Wszystkie') return _events;
    if (_selectedFilter == 'Moje eventy') {
      return _events.where((e) => e.creatorName == 'Jan Kowalski').toList();
    }
    return _events.where((e) => e.type == _selectedFilter).toList();
  }

  void _createNewEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateEventScreen()),
    );

    // Jeśli event został stworzony, odśwież listę
    if (result != null && result == true) {
      setState(() {
        // Tu później dodamy nowy event do listy
      });
    }
  }

  void _joinEvent(String eventId) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final event = _events[index];
        if (!event.participants.contains('current_user')) {
          _events[index] = Event(
            id: event.id,
            creatorId: event.creatorId,
            creatorName: event.creatorName,
            title: event.title,
            type: event.type,
            description: event.description,
            address: event.address,
            maxParticipants: event.maxParticipants,
            dateTime: event.dateTime,
            endTime: event.endTime,
            participants: [...event.participants, 'current_user'],
            latitude: event.latitude,
            longitude: event.longitude,
            isActive: event.isActive,
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dołączono do eventu!'),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  void _showEventDetails(Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textColor70,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getEventTypeColor(event.type),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getEventTypeIcon(event.type),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            color: AppColors.textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Przez ${event.creatorName}',
                          style: const TextStyle(
                            color: AppColors.textColor70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (event.description.isNotEmpty) ...[
                const Text(
                  'Opis',
                  style: TextStyle(
                    color: AppColors.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: const TextStyle(
                    color: AppColors.textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const Text(
                'Szczegóły',
                style: TextStyle(
                  color: AppColors.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              _buildDetailRow(
                icon: Icons.location_on,
                text: event.address,
              ),
              const SizedBox(height: 8),

              _buildDetailRow(
                icon: Icons.schedule,
                text: _formatDateTime(event.dateTime),
              ),
              const SizedBox(height: 8),

              _buildDetailRow(
                icon: Icons.people,
                text: '${event.participants.length}/${event.maxParticipants} uczestników',
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _joinEvent(event.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'DOŁĄCZ DO EVENTU',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textColor70,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textColor,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewEvent,
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Nagłówek
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            color: AppColors.surfaceColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eventy',
                  style: TextStyle(
                    color: AppColors.textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Znajdź lub stwórz wydarzenie',
                  style: TextStyle(
                    color: AppColors.textColor70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Filtry
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          backgroundColor: AppColors.surfaceColor,
                          selectedColor: AppColors.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Lista eventów
          Expanded(
            child: _filteredEvents.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: AppColors.textColor70,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Brak eventów',
                    style: TextStyle(
                      color: AppColors.textColor,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Stwórz pierwszy event!',
                    style: TextStyle(
                      color: AppColors.textColor70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) {
                final event = _filteredEvents[index];
                return _buildEventCard(event);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final participantsCount = event.participants.length;
    final spotsLeft = event.maxParticipants - participantsCount;
    final isFull = spotsLeft <= 0;
    final isJoined = event.participants.contains('current_user');

    return GestureDetector(
      onTap: () => _showEventDetails(event),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: AppColors.surfaceColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ikona typu eventu
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getEventTypeColor(event.type),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getEventTypeIcon(event.type),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            color: AppColors.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Przez ${event.creatorName}',
                          style: const TextStyle(
                            color: AppColors.textColor70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isJoined)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryColor),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 12, color: AppColors.primaryColor),
                          SizedBox(width: 4),
                          Text(
                            'DOŁĄCZONO',
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Opis
              Text(
                event.description,
                style: const TextStyle(
                  color: AppColors.textColor,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Informacje
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.textColor70,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.address,
                      style: TextStyle(
                        color: AppColors.textColor70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.textColor70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(event.dateTime),
                    style: TextStyle(
                      color: AppColors.textColor70,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.people,
                    size: 16,
                    color: AppColors.textColor70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$participantsCount/${event.maxParticipants}',
                    style: TextStyle(
                      color: isFull ? AppColors.errorColor : AppColors.textColor70,
                      fontSize: 12,
                      fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Przycisk dołączenia
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isFull || isJoined ? null : () => _joinEvent(event.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isJoined ? AppColors.textColor70 : AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.textColor70,
                  ),
                  child: Text(
                    isJoined ? 'DOŁĄCZONO' : (isFull ? 'BRAK MIEJSC' : 'DOŁĄCZ DO EVENTU'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'Planszówka':
        return const Color(0xFFFF9800); // Orange
      case 'Kino':
        return const Color(0xFF9C27B0); // Purple
      case 'Piwo':
        return const Color(0xFFFFC107); // Amber
      case 'Jedzenie':
        return const Color(0xFFF44336); // Red
      default:
        return AppColors.primaryColor;
    }
  }

  IconData _getEventTypeIcon(String type) {
    switch (type) {
      case 'Planszówka':
        return Icons.casino;
      case 'Kino':
        return Icons.movie;
      case 'Piwo':
        return Icons.local_bar;
      case 'Jedzenie':
        return Icons.restaurant;
      default:
        return Icons.event;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (eventDay == today) {
      return 'Dziś ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (eventDay == today.add(const Duration(days: 1))) {
      return 'Jutro ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}