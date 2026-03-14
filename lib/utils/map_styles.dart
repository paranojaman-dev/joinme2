class MapStyles {
  static const String classic = '[]';
  
  static const String dark = r'''
[
  { "elementType": "geometry", "stylers": [ { "color": "#242f3e" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#746855" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#242f3e" } ] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [ { "color": "#d59563" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#38413e" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#17263c" } ] }
]
''';

  static const String neon = r'''
[
  { "elementType": "geometry", "stylers": [ { "color": "#1a1a1a" } ] },
  { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#ff4081" } ] },
  { "featureType": "water", "elementType": "geometry.fill", "stylers": [ { "color": "#6a1b9a" } ] },
  { "featureType": "landscape.natural", "elementType": "geometry.fill", "stylers": [ { "color": "#424242" } ] },
  { "featureType": "transit.line", "elementType": "geometry.fill", "stylers": [ { "color": "#ff6d00" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#ffffff" } ] }
]
''';

  static const String alice = r'''
[
  { "elementType": "geometry", "stylers": [ { "color": "#f5f5f5" } ] },
  { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#1a1a1a" } ] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [ { "color": "#000000" } ] },
  { "featureType": "landscape.natural", "elementType": "geometry.fill", "stylers": [ { "color": "#2e7d32" } ] },
  { "featureType": "poi.park", "elementType": "geometry.fill", "stylers": [ { "color": "#4caf50" } ] },
  { "featureType": "water", "elementType": "geometry.fill", "stylers": [ { "color": "#b3e5fc" } ] }
]
''';

  static const String medieval = r'''
[
  { "elementType": "geometry", "stylers": [ { "color": "#ab8763" } ] },
  { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#93673e" } ] },
  { "featureType": "landscape.man_made", "elementType": "geometry.fill", "stylers": [ { "color": "#874040" } ] },
  { "featureType": "water", "elementType": "geometry.fill", "stylers": [ { "color": "#3b788c" } ] },
  { "featureType": "poi.park", "elementType": "geometry.fill", "stylers": [ { "color": "#675522" } ] }
]
''';

  static const String joinme = r'''
[
  { "elementType": "geometry", "stylers": [ { "color": "#121212" } ] },
  { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#388E3C" } ] },
  { "featureType": "water", "elementType": "geometry.fill", "stylers": [ { "color": "#000000" } ] }
]
''';

  static const Map<String, String> styles = {
    'normal': classic,
    'dark': dark,
    'neon': neon,
    'alice': alice,
    'medieval': medieval,
    'joinme': joinme,
  };
}
