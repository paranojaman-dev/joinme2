import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/models/user_model.dart';
import 'package:joinme2/models/event_model.dart';
import 'package:joinme2/models/pin_model.dart';
import 'package:joinme2/screens/create_event_screen.dart';
import 'package:joinme2/screens/user_profile_screen.dart';
import 'package:joinme2/screens/event_details_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/services/location_service.dart';
import 'package:joinme2/services/ad_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/map_styles.dart';
import 'package:joinme2/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isAddingPin = false; 
  double _currentZoom = 14.0;
  String? _lastAppliedStyle;
  StreamSubscription? _appStateSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Map<String, Marker> _userMarkers = {};
  Map<String, Marker> _eventMarkers = {};
  Map<String, Marker> _pinMarkers = {}; 
  Marker? _myMarker;
  
  final _databaseService = DatabaseService();
  final AdService _adService = AdService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  UserModel? _currentUserModel;

  bool _showOnlyFriends = false;

  final List<IconData> _availableIcons = [
    Icons.favorite, Icons.star, Icons.music_note, Icons.restaurant, 
    Icons.directions_run, Icons.local_bar, Icons.camera_alt, Icons.sports_esports
  ];

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _adService.loadInterstitialAd();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppStateManager>(context, listen: false);
      _appStateSubscription = appState.getStream().listen((_) {
        if (mounted) _handleJump();
      });
      _handleJump();
    });
  }

  void _handleJump() {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    if (appState.mapJumpTo != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(appState.mapJumpTo!, 16));
      appState.clearJumpTo();
      _fetchData(); // Odśwież, aby marker na pewno się pojawił
    }
  }
  
  @override
  void dispose() {
    _appStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _databaseService.getUserData(_currentUserId);
      if (mounted && userData.exists) {
        _currentUserModel = UserModel.fromMap(userData.data() as Map<String, dynamic>);
      }
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() => _currentPosition = position);
        await _databaseService.updateUserLocation(_currentUserId, position.latitude, position.longitude);
      }
      await _fetchData();
    } catch (e) { debugPrint("❌ Map Error: $e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchData() async {
    try {
      final appState = Provider.of<AppStateManager>(context, listen: false);
      final userData = await _databaseService.getUserData(_currentUserId);
      if (userData.exists) {
        _currentUserModel = UserModel.fromMap(userData.data() as Map<String, dynamic>);
      }

      final userSnapshot = await _databaseService.getUsersOnce();
      final eventSnapshot = await _databaseService.getEventsOnce();
      final pinSnapshot = await _databaseService.getPinsOnce();
      
      await _updateMarkers(
        userDocs: userSnapshot.docs, 
        eventDocs: eventSnapshot.docs, 
        pinDocs: pinSnapshot.docs,
        appState: appState
      );
    } catch (e) { debugPrint("❌ Fetch Error: $e"); }
  }

  LatLng _applyJitter(LatLng position, Set<LatLng> existingPositions) {
    double lat = position.latitude;
    double lng = position.longitude;
    final random = Random();
    
    bool isOccupied(double la, double ln) {
      for (var pos in existingPositions) {
        if ((pos.latitude - la).abs() < 0.0001 && (pos.longitude - ln).abs() < 0.0001) return true;
      }
      return false;
    }

    int attempts = 0;
    while (isOccupied(lat, lng) && attempts < 15) {
      lat += (random.nextDouble() - 0.5) * 0.00025;
      lng += (random.nextDouble() - 0.5) * 0.00025;
      attempts++;
    }
    existingPositions.add(LatLng(lat, lng));
    return LatLng(lat, lng);
  }

  bool _shouldSeeObject(Map<String, dynamic>? visibilitySettings, String creatorId, {List<dynamic>? participants, LatLng? objectPos, double? maxRadius}) {
    if (_currentUserModel == null) return true;
    if (creatorId == _currentUserId) return true; 
    
    if (participants != null && participants.contains(_currentUserId)) return true;

    if (_showOnlyFriends) {
      if (!_currentUserModel!.friends.contains(creatorId)) return false;
    }

    if (objectPos != null && _currentPosition != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        objectPos.latitude, objectPos.longitude
      ) / 1000; 
      if (distance > (maxRadius ?? 500)) return false;
    }

    if (visibilitySettings == null || visibilitySettings.isEmpty) return true;
    
    int minAge = visibilitySettings['ageRange']?['min'] ?? 18;
    int maxAge = visibilitySettings['ageRange']?['max'] ?? 99;
    bool showMen = visibilitySettings['showToMen'] ?? true;
    bool showWomen = visibilitySettings['showToWomen'] ?? true;
    bool showOther = visibilitySettings['showToOther'] ?? true;

    int? myAge = _currentUserModel!.age;
    String myGender = (_currentUserModel!.gender ?? 'other').toLowerCase();

    if (myAge != null && (myAge < minAge || myAge > maxAge)) return false;
    
    if ((myGender.contains('mal') || myGender.contains('męż')) && !showMen) return false;
    if ((myGender.contains('fem') || myGender.contains('kob')) && !showWomen) return false;
    if (!myGender.contains('mal') && !myGender.contains('męż') && !myGender.contains('fem') && !myGender.contains('kob') && !showOther) return false;

    return true;
  }

  Future<void> _updateMarkers({
    required List<DocumentSnapshot> userDocs, 
    required List<DocumentSnapshot> eventDocs, 
    required List<DocumentSnapshot> pinDocs,
    required AppStateManager appState
  }) async {
    bool miniStyle = _currentZoom < 13.0;
    Set<LatLng> usedPositions = {};

    if (_currentUserModel != null && _currentPosition != null) {
      LatLng myPos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      usedPositions.add(myPos);
      _myMarker = Marker(
        markerId: const MarkerId("user_me"),
        position: myPos,
        icon: await _generate3DMarker(_currentUserModel!.photoURL, AppColors.primaryColor, miniStyle, _currentUserModel!.displayName, isMe: true),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: _currentUserId))),
      );
    }

    final Map<String, Marker> newPins = {};
    for (var doc in pinDocs) {
      final pin = PinModel.fromFirestore(doc);
      LatLng pinPos = LatLng(pin.latitude, pin.longitude);
      if (!_shouldSeeObject(pin.visibilityRequirements, pin.creatorId, objectPos: pinPos, maxRadius: appState.searchRadius)) continue;

      LatLng pos = _applyJitter(pinPos, usedPositions);
      newPins[doc.id] = Marker(
        markerId: MarkerId("pin_${doc.id}"),
        position: pos,
        icon: await _generate3DPinMarker(pin.title, Colors.cyan, miniStyle),
        onTap: () {
          if (pin.spotifyTrackId != null) _playSpotifyPreview(pin.spotifyTrackId!);
          Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: pin.creatorId)));
        },
      );
    }
    _pinMarkers = newPins;

    final Map<String, Marker> newEvents = {};
    final Map<String, Map<String, dynamic>> userSettingsMap = {};
    for (var doc in userDocs) {
      final data = doc.data() as Map<String, dynamic>;
      userSettingsMap[doc.id] = Map<String, dynamic>.from(data['visibilitySettings'] ?? {});
    }

    for (var doc in eventDocs) {
      final event = Event.fromFirestore(doc);
      final creatorSettings = userSettingsMap[event.creatorId];
      LatLng eventPos = LatLng(event.latitude, event.longitude);
      if (!_shouldSeeObject(creatorSettings, event.creatorId, participants: event.participants, objectPos: eventPos, maxRadius: appState.searchRadius)) continue;

      LatLng pos = _applyJitter(eventPos, usedPositions);
      newEvents[doc.id] = Marker(
        markerId: MarkerId("event_${doc.id}"),
        position: pos,
        icon: await _generate3DEventMarker(event.type, miniStyle),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event))),
      );
    }
    _eventMarkers = newEvents;

    final Map<String, Marker> newUserMarkers = {};
    for (var doc in userDocs) {
      if (doc.id == _currentUserId) continue;
      final user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      
      if (user.isOnline && user.location != null && user.shareLocation) {
        LatLng userPos = LatLng(user.location!.latitude, user.location!.longitude);
        if (!_shouldSeeObject(user.visibilitySettings, user.uid, objectPos: userPos, maxRadius: appState.searchRadius)) continue;

        LatLng pos = _applyJitter(userPos, usedPositions);
        newUserMarkers[doc.id] = Marker(
          markerId: MarkerId("user_${doc.id}"),
          position: pos,
          icon: await _generate3DMarker(user.photoURL, Colors.blue.shade700, miniStyle, user.displayName),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: user.uid))),
        );
      }
    }
    _userMarkers = newUserMarkers;

    if (mounted) setState(() {});
  }

  Future<void> _playSpotifyPreview(String trackId) async {
    final url = "https://p.scdn.co/mp3-preview/$trackId";
    await _audioPlayer.play(UrlSource(url));
  }

  void _rollTheDice() {
    if (_eventMarkers.isEmpty) return;
    final random = Random();
    final eventsList = _eventMarkers.values.toList();
    final randomMarker = eventsList[random.nextInt(eventsList.length)];
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(randomMarker.position, 16));
  }

  void _refreshWithAd() {
    _adService.showInterstitialAd(() {
      _initializeMap();
    });
  }

  void _onMapLongPress(LatLng point) {
    if (!_isAddingPin) return;
    _showAddPinDialog(point);
  }

  void _showAddPinDialog(LatLng point) {
    final TextEditingController pinController = TextEditingController();
    final TextEditingController spotifyController = TextEditingController();
    IconData selectedIcon = Icons.push_pin;
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceColor,
          title: Text(loc.translate('name_point'), style: const TextStyle(color: AppColors.primaryColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: loc.translate('pin_title_hint'), hintStyle: const TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: spotifyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: "Spotify Track ID", hintStyle: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 20),
                Wrap(
                  children: _availableIcons.map((icon) => IconButton(
                    icon: Icon(icon, color: selectedIcon == icon ? AppColors.primaryColor : Colors.white54),
                    onPressed: () => setDialogState(() => selectedIcon = icon),
                  )).toList(),
                )
              ],
            ),
          ),
          actions: [
            TextButton(child: Text(loc.translate('cancel')), onPressed: () => Navigator.pop(ctx)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
              child: Text(loc.translate('save')),
              onPressed: () async {
                if (pinController.text.isEmpty) return;
                final pin = PinModel(
                  id: '',
                  creatorId: _currentUserId,
                  creatorName: _currentUserModel?.nickname ?? '',
                  title: pinController.text,
                  latitude: point.latitude,
                  longitude: point.longitude,
                  createdAt: DateTime.now(),
                  spotifyTrackId: spotifyController.text.isNotEmpty ? spotifyController.text : null,
                  visibilityRequirements: _currentUserModel?.visibilitySettings,
                );
                await _databaseService.createPin(pin);
                Navigator.pop(ctx);
                setState(() => _isAddingPin = false);
                _fetchData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<BitmapDescriptor> _generate3DMarker(String url, Color color, bool mini, String name, {bool isMe = false}) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double size = mini ? 100 : 160;
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(Rect.fromLTWH(size * 0.2, size * 0.85, size * 0.6, size * 0.15), shadowPaint);
    final Paint ringPaint = Paint()..color = const Color(0xFF212121);
    canvas.drawCircle(Offset(size/2, size/2 - 15), size/2 - 5, ringPaint);
    final Paint borderPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 5;
    canvas.drawCircle(Offset(size/2, size/2 - 15), size/2 - 10, borderPaint);
    await _drawAvatar(canvas, url, size - 40, size/2, size/2 - 15);
    final Path path = Path()..moveTo(size * 0.4, size * 0.75)..lineTo(size * 0.5, size * 0.95)..lineTo(size * 0.6, size * 0.75)..close();
    canvas.drawPath(path, Paint()..color = color);
    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _generate3DPinMarker(String title, Color color, bool mini) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double size = mini ? 100 : 140;
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(Rect.fromLTWH(size * 0.3, size * 0.8, size * 0.4, size * 0.1), shadowPaint);
    final Paint p = Paint()..color = color;
    canvas.drawCircle(Offset(size/2, size/2 - 10), size/3, p);
    final Paint border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawCircle(Offset(size/2, size/2 - 10), size/3, border);
    final Path path = Path()..moveTo(size * 0.4, size * 0.6)..lineTo(size * 0.5, size * 0.85)..lineTo(size * 0.6, size * 0.6)..close();
    canvas.drawPath(path, p);
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: String.fromCharCode(Icons.push_pin.codePoint), style: TextStyle(fontSize: size/4, fontFamily: Icons.push_pin.fontFamily, color: Colors.white));
    tp.layout();
    tp.paint(canvas, Offset(size/2 - tp.width/2, size/2 - 10 - tp.height/2));
    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _generate3DEventMarker(String type, bool mini) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double size = mini ? 100 : 150;
    final Color eventColor = const Color(0xFFFFD700);
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(Rect.fromLTWH(size * 0.25, size * 0.85, size * 0.5, size * 0.1), shadowPaint);
    final Paint p = Paint()..color = eventColor;
    canvas.drawCircle(Offset(size/2, size/2 - 15), size/2.5, p);
    final Paint border = Paint()..color = const Color(0xFFB8860B)..style = PaintingStyle.stroke..strokeWidth = 4;
    canvas.drawCircle(Offset(size/2, size/2 - 15), size/2.5, border);
    final Path path = Path()..moveTo(size * 0.4, size * 0.7)..lineTo(size * 0.5, size * 0.95)..lineTo(size * 0.6, size * 0.7)..close();
    canvas.drawPath(path, p);
    IconData icon = Icons.event;
    if (type == 'Kino') icon = Icons.movie;
    else if (type == 'Bar') icon = Icons.local_bar;
    else if (type == 'Spacer') icon = Icons.directions_walk;
    else if (type == 'Impreza') icon = Icons.celebration;
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: size/3, fontFamily: icon.fontFamily, color: Colors.black87));
    tp.layout();
    tp.paint(canvas, Offset(size/2 - tp.width/2, size/2 - 15 - tp.height/2));
    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _drawAvatar(Canvas canvas, String url, double size, double x, double y) async {
    if (url.isEmpty) {
      canvas.drawCircle(Offset(x, y), size/2, Paint()..color = Colors.blueGrey.shade700);
      return;
    }
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 2));
      final ui.Codec codec = await ui.instantiateImageCodec(response.bodyBytes, targetWidth: size.toInt(), targetHeight: size.toInt());
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCenter(center: Offset(x, y), width: size, height: size)));
      canvas.drawImage(frameInfo.image, Offset(x - size/2, y - size/2), Paint());
      canvas.restore();
    } catch (e) { canvas.drawCircle(Offset(x, y), size/2, Paint()..color = Colors.blueGrey.shade700); }
  }

  void _goToCurrentLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 14));
    }
  }

  void _searchUser() {
     final TextEditingController searchController = TextEditingController();
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         backgroundColor: AppColors.surfaceColor,
         title: const Text("Szukaj użytkownika", style: TextStyle(color: Colors.white)),
         content: TextField(
           controller: searchController,
           style: const TextStyle(color: Colors.white),
           decoration: const InputDecoration(hintText: "Wpisz nick...", hintStyle: TextStyle(color: Colors.grey)),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Anuluj")),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
             onPressed: () async {
                final query = await FirebaseFirestore.instance.collection('users')
                  .where('nickname', isEqualTo: searchController.text.trim())
                  .get();
                
                if (query.docs.isNotEmpty) {
                  final userData = query.docs.first.data();
                  if (userData['location'] != null) {
                    GeoPoint loc = userData['location'];
                    Navigator.pop(ctx);
                    
                    // Używamy jumpToLocationOnMap z managera, aby zachować spójność
                    Provider.of<AppStateManager>(context, listen: false)
                      .jumpToLocationOnMap(LatLng(loc.latitude, loc.longitude));
                  }
                }
             },
             child: const Text("Szukaj"),
           )
         ],
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final loc = AppLocalizations.of(context)!;
    
    if (_mapController != null && _lastAppliedStyle != appState.mapStyle) {
      _lastAppliedStyle = appState.mapStyle;
      _mapController!.setMapStyle(MapStyles.styles[appState.mapStyle]);
    }

    Set<Marker> allMarkers = {};
    if (_myMarker != null) allMarkers.add(_myMarker!);
    allMarkers.addAll(_userMarkers.values);
    allMarkers.addAll(_eventMarkers.values);
    allMarkers.addAll(_pinMarkers.values);

    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: LatLng(_currentPosition?.latitude ?? 52.2, _currentPosition?.longitude ?? 21.0), zoom: 14),
                onMapCreated: (c) {
                  _mapController = c;
                  _mapController!.setMapStyle(MapStyles.styles[appState.mapStyle]);
                  _handleJump();
                },
                onLongPress: _onMapLongPress,
                markers: allMarkers,
                onCameraMove: (pos) => _currentZoom = pos.zoom,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                padding: const EdgeInsets.only(top: 100),
              ),
              Positioned(
                top: 20, left: 15, right: 15,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(color: AppColors.surfaceColor, borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)]),
                  child: Row(
                    children: [
                      const SizedBox(width: 15),
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(child: GestureDetector(onTap: _searchUser, child: const Text("Szukaj na mapie...", style: TextStyle(color: Colors.grey)))),
                      IconButton(
                        icon: Icon(appState.isOnline ? Icons.visibility : Icons.visibility_off, color: appState.isOnline ? AppColors.primaryColor : Colors.red),
                        onPressed: () => appState.toggleOnlineStatus(),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 100, right: 15,
                child: Column(
                  children: [
                    _mapButton(Icons.add_location_alt, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateEventScreen())), hero: 'add_ev'),
                    _mapButton(Icons.push_pin, () => setState(() => _isAddingPin = !_isAddingPin), color: _isAddingPin ? Colors.orange : Colors.white, hero: 'pin'),
                    _mapButton(Icons.people, () {
                      setState(() => _showOnlyFriends = !_showOnlyFriends);
                      _fetchData();
                    }, color: _showOnlyFriends ? AppColors.primaryColor : Colors.white, hero: 'friends_filter'),
                    _mapButton(Icons.casino, _rollTheDice, color: Colors.amber, hero: 'dice'),
                    _mapButton(Icons.refresh, _refreshWithAd, hero: 'refresh'),
                    _mapButton(Icons.my_location, _goToCurrentLocation, hero: 'my_loc'),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap, {Color color = Colors.white, required String hero}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FloatingActionButton(
        heroTag: hero,
        onPressed: onTap,
        mini: true,
        backgroundColor: AppColors.surfaceColor,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
