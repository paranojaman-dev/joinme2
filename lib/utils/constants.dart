import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF00C853);
  static const Color secondaryColor = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color textColor = Color(0xFFE0E0E0);
  static const Color errorColor = Color(0xFFCF6679);

  static const Color textColor70 = Color(0xB3E0E0E0);
  static const Color textColor50 = Color(0x80E0E0E0);
}

class AppConstants {
  static const String appName = 'JoinMe';

  // Zunifikowana lista kategorii
  static const List<String> eventTypes = [
    'Kino',
    'Spacer',
    'Dyskusja',
    'Restauracja',
    'Bar',
    'Dyskoteka',
    'Koncert',
    'Spotkanie',
    'Planszówka',
    'Wyjazd',
    'Mecz',
    'Grill',
    'Galeria',
    'Zakupy',
    'Impreza',
    'Inne'
  ];

  static const String darkMapStyle = '''
[
  { "elementType": "geometry", "stylers": [ { "color": "#1d1d1d" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#757575" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#1d1d1d" } ] },
  { "featureType": "administrative", "elementType": "geometry", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [ { "color": "#4b4b4b" } ] },
  { "featureType": "poi", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#2c2c2c" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#000000" } ] }
]
''';
}
