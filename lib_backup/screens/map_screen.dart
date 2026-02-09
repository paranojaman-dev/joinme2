import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';

  // Przykładowi użytkownicy
  final Set<Marker> _markers = {
    Marker(
      markerId: const MarkerId('user1'),
      position: const LatLng(52.2297, 21.0122), // Warszawa
      infoWindow: const InfoWindow(
        title: 'Jan Kowalski',
        snippet: 'Planszówka',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ),
    Marker(
      markerId: const MarkerId('user2'),
      position: const LatLng(52.4064, 16.9252), // Poznań
      infoWindow: const InfoWindow(
        title: 'Anna Nowak',
        snippet: 'Kino',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ),
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
        // Automatycznie przejdź do lokalizacji po załadowaniu
        _goToCurrentLocation();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Ustaw ciemny styl mapy od razu po utworzeniu
    _setMapStyle();
  }

  Future<void> _setMapStyle() async {
    try {
      await mapController.setMapStyle(AppConstants.darkMapStyle);
    } catch (e) {
      // Ignoruj błędy stylu - mapa i tak będzie działać
    }
  }

  void _goToCurrentLocation() async {
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
        ),
      );
    }
  }

  void _refreshLocation() async {
    setState(() {
      _isLoading = true;
    });
    await _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Ładowanie mapy...',
              style: TextStyle(color: AppColors.textColor),
            ),
          ],
        ),
      )
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 64,
              color: AppColors.errorColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Błąd lokalizacji',
              style: TextStyle(
                color: AppColors.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textColor70,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              zoom: 14,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Wyłącz domyślny przycisk
            compassEnabled: true,
            mapType: MapType.normal,
            onTap: (LatLng position) {
              // Tu później dodamy obsługę kliknięcia na mapę
            },
          ),
          // Przycisk odświeżania lokalizacji - TERAZ U GÓRY
          Positioned(
            top: 80, // Pod paskiem wyszukiwania
            right: 20,
            child: Column(
              children: [
                // Przycisk mojej lokalizacji
                FloatingActionButton(
                  onPressed: _goToCurrentLocation,
                  backgroundColor: AppColors.primaryColor,
                  mini: true,
                  child: const Icon(Icons.my_location, size: 20),
                ),
                const SizedBox(height: 10),
                // Przycisk odświeżania
                FloatingActionButton(
                  onPressed: _refreshLocation,
                  backgroundColor: AppColors.primaryColor,
                  mini: true,
                  child: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
          ),
          // Pasek wyszukiwania
          const Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _SearchBar(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            Icons.search,
            color: AppColors.textColor70,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Szukaj użytkowników...',
              style: TextStyle(
                color: AppColors.textColor70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}