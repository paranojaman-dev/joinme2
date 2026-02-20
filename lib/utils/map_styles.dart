class MapStyles {
  static const String classic = '[]';
  
  static const String dark = r'''
[
  { "elementType": "geometry", "stylers": [ { "color": "#242f3e" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#746855" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#242f3e" } ] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [ { "color": "#d59563" } ] },
  { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [ { "color": "#d59563" } ] },
  { "featureType": "poi.park", "elementType": "geometry", "stylers": [ { "color": "#263c3f" } ] },
  { "featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [ { "color": "#6b9a76" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#38413e" } ] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [ { "color": "#212a37" } ] },
  { "featureType": "road", "elementType": "labels.text.fill", "stylers": [ { "color": "#9ca5b3" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#746855" } ] },
  { "featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [ { "color": "#1f2835" } ] },
  { "featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [ { "color": "#f3d19c" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#17263c" } ] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [ { "color": "#515c6d" } ] },
  { "featureType": "water", "elementType": "labels.text.stroke", "stylers": [ { "color": "#17263c" } ] }
]
''';

  static const String retro = r'''
[
  { "elementType": "geometry", "stylers": [ { "color": "#ebe3cd" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#523735" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#f5f1e6" } ] },
  { "featureType": "administrative", "elementType": "geometry.stroke", "stylers": [ { "color": "#c9b2a6" } ] },
  { "featureType": "landscape.natural", "elementType": "geometry", "stylers": [ { "color": "#dfd2ae" } ] },
  { "featureType": "poi", "elementType": "geometry", "stylers": [ { "color": "#dfd2ae" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#f5f1e6" } ] },
  { "featureType": "road.arterial", "elementType": "geometry", "stylers": [ { "color": "#fdfcf8" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#f8c967" } ] },
  { "featureType": "water", "elementType": "geometry.fill", "stylers": [ { "color": "#b9d3c2" } ] }
]
''';

  static const String neon = r'''
[
  { "elementType": "geometry", "stylers": [ { "color": "#24063c" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#863fa6" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#24063c" } ] },
  { "featureType": "administrative", "elementType": "geometry.stroke", "stylers": [ { "color": "#42057f" } ] },
  { "featureType": "landscape", "elementType": "geometry", "stylers": [ { "color": "#10273c" } ] },
  { "featureType": "poi", "elementType": "geometry", "stylers": [ { "color": "#292929" } ] },
  { "featureType": "poi.park", "elementType": "geometry", "stylers": [ { "color": "#29920c" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#42057f" } ] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [ { "color": "#630486" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#863fa6" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#0789ca" } ] }
]
''';

  static const Map<String, String> styles = {
    'normal': classic,
    'dark': dark,
    'retro': retro,
    'neon': neon,
  };
}
