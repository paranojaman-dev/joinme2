import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Sprawdź czy usługa lokalizacji jest włączona
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Usługa lokalizacji jest wyłączona.');
    }

    // Sprawdź uprawnienia
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Uprawnienia do lokalizacji są odrzucone.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Uprawnienia do lokalizacji są permanentnie odrzucone.');
    }

    // Pobierz aktualną lokalizację
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metry
      ),
    );
  }
}