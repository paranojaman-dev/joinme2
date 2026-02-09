import 'package:joinme2/models/event_model.dart';

// Mock Database Service for web testing
class DatabaseService {
  Future<void> createEvent(Event event) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    print('Mock Event Created: ${event.title}');
    // Do nothing, just pretend to save.
  }

  // This won't be called in the mock version, but it's here for compatibility.
  Future<dynamic> getUserData(String uid) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'displayName': 'Test User',
    };
  }
}
