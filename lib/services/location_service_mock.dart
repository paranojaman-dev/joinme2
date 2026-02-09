import 'package:geolocator/geolocator.dart';

// Mock Location Service for web testing
class LocationService {
  static Future<Position> getCurrentLocation() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    // Return a fixed position for testing
    return Position(
      latitude: 52.2297,
      longitude: 21.0122,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}
