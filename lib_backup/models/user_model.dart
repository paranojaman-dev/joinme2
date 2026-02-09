class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final int age;
  final List<String> interests;
  final String photoURL;
  final bool shareLocation;
  final Map<String, dynamic> visibilitySettings;
  final bool isOnline;
  final DateTime lastSeen;
  final Map<String, dynamic> currentActivity;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.age,
    required this.interests,
    required this.photoURL,
    required this.shareLocation,
    required this.visibilitySettings,
    required this.isOnline,
    required this.lastSeen,
    required this.currentActivity,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'age': age,
      'interests': interests,
      'photoURL': photoURL,
      'shareLocation': shareLocation,
      'visibilitySettings': visibilitySettings,
      'isOnline': isOnline,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'currentActivity': currentActivity,
    };
  }

  static UserModel fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      displayName: map['displayName'],
      age: map['age'],
      interests: List<String>.from(map['interests']),
      photoURL: map['photoURL'],
      shareLocation: map['shareLocation'],
      visibilitySettings: Map<String, dynamic>.from(map['visibilitySettings']),
      isOnline: map['isOnline'],
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen']),
      currentActivity: Map<String, dynamic>.from(map['currentActivity']),
    );
  }
}