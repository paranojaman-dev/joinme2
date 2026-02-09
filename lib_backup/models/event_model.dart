class Event {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final String type;
  final String description;
  final String address;
  final int maxParticipants;
  final DateTime dateTime;
  final DateTime? endTime;
  final List<String> participants;
  final double latitude;
  final double longitude;
  final bool isActive;

  Event({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.type,
    required this.description,
    required this.address,
    required this.maxParticipants,
    required this.dateTime,
    this.endTime,
    required this.participants,
    required this.latitude,
    required this.longitude,
    this.isActive = true,
  });

  // Przykładowe dane dla testów
  static List<Event> sampleEvents = [
    Event(
      id: '1',
      creatorId: 'user1',
      creatorName: 'Jan Kowalski',
      title: 'Wieczór planszówek',
      type: 'Planszówka',
      description: 'Gramy w Catan, Ticket to Ride i inne',
      address: 'Kawiarnia Planszowa, Warszawska 15, Warszawa',
      maxParticipants: 6,
      dateTime: DateTime.now().add(const Duration(hours: 2)),
      participants: ['user1', 'user2'],
      latitude: 52.2297,
      longitude: 21.0122,
    ),
    Event(
      id: '2',
      creatorId: 'user2',
      creatorName: 'Anna Nowak',
      title: 'Kino - nowy film Marvel',
      type: 'Kino',
      description: 'Idziemy na najnowszy film Marvel Universe',
      address: 'Multikino Złote Tarasy, Warszawa',
      maxParticipants: 4,
      dateTime: DateTime.now().add(const Duration(days: 1)),
      participants: ['user2'],
      latitude: 52.2323,
      longitude: 21.0062,
    ),
    Event(
      id: '3',
      creatorId: 'user3',
      creatorName: 'Michał Wiśniewski',
      title: 'Piwo po pracy',
      type: 'Piwo',
      description: 'Relaks przy piwie i rozmowy',
      address: 'Pub pod Kogutem, Krakowskie Przedmieście 23',
      maxParticipants: 8,
      dateTime: DateTime.now().add(const Duration(hours: 3)),
      participants: ['user3', 'user4', 'user5'],
      latitude: 52.2400,
      longitude: 21.0150,
    ),
  ];
}