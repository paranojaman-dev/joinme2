import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? status;
  final List<String> interests;
  final List<String>? languages;
  final String photoURL;
  final bool shareLocation;
  final Map<String, dynamic> visibilitySettings;
  final bool isOnline;
  final DateTime lastSeen;
  final GeoPoint? location;
  final Map<String, dynamic> currentActivity;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.dateOfBirth,
    this.gender,
    this.status,
    required this.interests,
    this.languages,
    required this.photoURL,
    required this.shareLocation,
    required this.visibilitySettings,
    required this.isOnline,
    required this.lastSeen,
    this.location,
    required this.currentActivity,
  });

  int? get age {
    if (dateOfBirth == null) return null;
    final today = DateTime.now();
    var age = today.year - dateOfBirth!.year;
    if (today.month < dateOfBirth!.month ||
        (today.month == dateOfBirth!.month && today.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'status': status,
      'interests': interests,
      'languages': languages,
      'photoURL': photoURL,
      'shareLocation': shareLocation,
      'visibilitySettings': visibilitySettings,
      'status_info': {
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(lastSeen),
      },
      'location': location,
      'currentActivity': currentActivity,
    };
  }

  static UserModel fromMap(Map<String, dynamic> map) {
    bool online = false;
    DateTime seen = DateTime.now();
    
    // Bezpieczne wyciąganie statusu
    final dynamic s = map['status'];
    if (s is Map) {
      online = s['isOnline'] ?? false;
      seen = (s['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now();
    } else if (map['status_info'] is Map) {
      online = map['status_info']['isOnline'] ?? false;
      seen = (map['status_info']['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now();
    }

    // Bezpieczne wyciąganie lokalizacji
    GeoPoint? loc;
    if (map['location'] is GeoPoint) {
      loc = map['location'];
    } else if (map['location'] is Map) {
      loc = GeoPoint(
        (map['location']['latitude'] ?? 0.0).toDouble(),
        (map['location']['longitude'] ?? 0.0).toDouble(),
      );
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'Użytkownik',
      dateOfBirth: (map['dateOfBirth'] as Timestamp?)?.toDate(),
      gender: map['gender'],
      status: (s is String) ? s : null,
      interests: List<String>.from(map['interests'] ?? []),
      languages: map['languages'] != null ? List<String>.from(map['languages']) : null,
      photoURL: map['photoURL'] ?? '',
      shareLocation: map['shareLocation'] ?? true,
      visibilitySettings: Map<String, dynamic>.from(map['visibilitySettings'] ?? {}),
      isOnline: online,
      lastSeen: seen,
      location: loc,
      currentActivity: Map<String, dynamic>.from(map['currentActivity'] ?? {}),
    );
  }
}
