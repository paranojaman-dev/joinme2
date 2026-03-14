import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String imageUrl;
  final String? spotifyTrackId; // Nowe
  final int? iconCodePoint;    // Nowe

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
    this.imageUrl = '',
    this.spotifyTrackId,
    this.iconCodePoint,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      maxParticipants: data['maxParticipants'] ?? 0,
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      participants: List<String>.from(data['participants'] ?? []),
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      isActive: data['isActive'] ?? true,
      imageUrl: data['imageUrl'] ?? '',
      spotifyTrackId: data['spotifyTrackId'],
      iconCodePoint: data['iconCodePoint'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'type': type,
      'description': description,
      'address': address,
      'maxParticipants': maxParticipants,
      'dateTime': Timestamp.fromDate(dateTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'participants': participants,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'imageUrl': imageUrl,
      'spotifyTrackId': spotifyTrackId,
      'iconCodePoint': iconCodePoint,
    };
  }
}
