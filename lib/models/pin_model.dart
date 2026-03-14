import 'package:cloud_firestore/cloud_firestore.dart';

class PinModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String? spotifyTrackId; // Opcjonalna muzyka
  final Map<String, dynamic>? visibilityRequirements; // Wiek, płeć twórcy w momencie stawiania

  PinModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.spotifyTrackId,
    this.visibilityRequirements,
  });

  factory PinModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return PinModel(
      id: doc.id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      title: data['title'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      spotifyTrackId: data['spotifyTrackId'],
      visibilityRequirements: data['visibilityRequirements'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'spotifyTrackId': spotifyTrackId,
      'visibilityRequirements': visibilityRequirements,
    };
  }
}
