import 'dart:io';

// Mock Storage Service for web testing
class StorageService {
  Future<String> uploadProfilePicture(String userId, File image) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    print('Mock Profile Picture Uploaded for $userId');
    // Return a fixed URL for testing
    return 'https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png';
  }
}
