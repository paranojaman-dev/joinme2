class EventModel {
  final String id;
  final String creatorId;
  final String title;
  final String type;
  final String address;
  final int maxParticipants;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> participants;
  final bool isActive;
  final double latitude;
  final double longitude;

  EventModel({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.type,
    required this.address,
    required this.maxParticipants,
    required this.startTime,
    required this.endTime,
    required this.participants,
    required this.isActive,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creatorId': creatorId,
      'title': title,
      'type': type,
      'address': address,
      'maxParticipants': maxParticipants,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'participants': participants,
      'isActive': isActive,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static EventModel fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'],
      creatorId: map['creatorId'],
      title: map['title'],
      type: map['type'],
      address: map['address'],
      maxParticipants: map['maxParticipants'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime']),
      participants: List<String>.from(map['participants']),
      isActive: map['isActive'],
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }
}