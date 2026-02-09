import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfilePicture(String userId, File image) async {
    try {
      final ref = _storage.ref().child('profile_pictures').child('$userId.jpg');
      await ref.putFile(image);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Błąd przesyłania zdjęcia profilowego: $e');
      rethrow;
    }
  }

  Future<String> uploadEventImage(String eventId, File image) async {
    try {
      final ref = _storage.ref().child('event_images').child('$eventId.jpg');
      await ref.putFile(image);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Błąd przesyłania zdjęcia wydarzenia: $e');
      rethrow;
    }
  }
}
