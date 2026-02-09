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
import 'package:joinme2/screens/create_event_screen.dart';
import 'package:joinme2/screens/user_profile_screen.dart';
import 'package:joinme2/screens/event_details_screen.dart';
import 'package:joinme2/screens/chat_screen.dart';
import 'package:joinme2/services/ad_service.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/services/location_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/utils/map_styles.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _dataLoadedAtLeastOnce = false;
  
  Map<String, Marker> _userMarkers = {};
  Map<String, Marker> _eventMarkers = {};
  Marker? _myMarker;
  
  final _databaseService = DatabaseService();
  final _adService = AdService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isPremium = false;
  UserModel? _currentUserModel;
  
  final Map<String, BitmapDescriptor> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      await _loadUserData();
      await _updateCurrentLocation();
      
      // Zgodnie z prośbą: Pierwsze ładowanie jest darmowe (widoczne za pierwszym logowaniem)
      await _fetchData();
      
    } catch (e) {
      debugPrint("❌ Map initialization error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _databaseService.getUserData(_currentUserId);
      if (mounted && userData.exists) {
        final data = userData.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _currentUserModel = UserModel.fromMap(data);
            _isPremium = data['isPremium'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error loading user data: $e");
    }
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        await _databaseService.updateUserLocation(_currentUserId, position.latitude, position.longitude);
        if (_currentUserModel != null) await _updateMyMarker();
      }
    } catch (e) {
      debugPrint("❌ Error getting location: $e");
    }
  }

  Future<void> _updateMyMarker() async {
    if (_currentUserModel == null || _currentPosition == null) return;
    try {
      final icon = await _generateUserMarkerIcon(_currentUserModel!);
      if (mounted) {
        setState(() {
          _myMarker = Marker(
            markerId: MarkerId("user_me_$_currentUserId"),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: icon,
            zIndex: 10,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen(userId: 'me'))),
          );
        });
      }
    } catch (e) {
      debugPrint("❌ Error updating my marker: $e");
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final appState = Provider.of<AppStateManager>(context, listen: false);
      
      // Pobieramy użytkowników (oprócz nas)
      final userSnapshot = await _databaseService.getUsersOnce();
      await _processUserMarkers(userSnapshot.docs, appState.isOnline);

      // Pobieramy wydarzenia
      final eventSnapshot = await _databaseService.getEventsOnce();
      await _processEventMarkers(eventSnapshot.docs);

      _dataLoadedAtLeastOnce = true;
    } catch (e) {
      debugPrint("❌ Error fetching data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _applyMapStyle();
  }

  void _applyMapStyle() {
    if (_mapController == null || !mounted) return;
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final styleJson = MapStyles.styles[appState.mapStyle];
    _mapController!.setMapStyle(styleJson != null && styleJson.isNotEmpty && styleJson != '[]' ? styleJson : null);
  }

  Future<BitmapDescriptor> _generateUserMarkerIcon(UserModel user) async {
    final cacheKey = "user_${user.uid}_${user.photoURL}_${user.isOnline}_${user.displayName}_${user.status}";
    if (_iconCache.containsKey(cacheKey)) return _iconCache[cacheKey]!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double width = 260.0;
    const double height = 100.0;
    const double radius = 50.0;

    final Paint paint = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, width, height), const Radius.circular(radius)), paint);

    final Paint borderPaint = Paint()
      ..color = user.isOnline ? Colors.green : Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, width, height), const Radius.circular(radius)), borderPaint);

    const double avatarSize = 70.0;
    if (user.photoURL.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(user.photoURL)).timeout(const Duration(seconds: 2));
        final ui.Codec codec = await ui.instantiateImageCodec(response.bodyBytes, targetWidth: 70, targetHeight: 70);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        canvas.save();
        canvas.clipPath(Path()..addOval(const Rect.fromLTWH(15, 15, avatarSize, avatarSize)));
        canvas.drawImage(frameInfo.image, const Offset(15, 15), Paint());
        canvas.restore();
      } catch (e) {
        _drawDefaultAvatar(canvas, avatarSize);
      }
    } else {
      _drawDefaultAvatar(canvas, avatarSize);
    }

    final TextPainter namePainter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '...');
    namePainter.text = TextSpan(text: user.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
    namePainter.layout(maxWidth: 140);
    namePainter.paint(canvas, const Offset(100, 20));

    final TextPainter statusPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '...');
    statusPainter.text = TextSpan(text: user.status ?? 'JoinMe!', style: TextStyle(fontSize: 16, color: Colors.grey.shade700));
    statusPainter.layout(maxWidth: 140);
    statusPainter.paint(canvas, const Offset(100, 50));

    final ui.Image image = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _iconCache[cacheKey] = icon;
    return icon;
  }

  void _drawDefaultAvatar(Canvas canvas, double size) {
    final Paint p = Paint()..color = Colors.blueGrey.shade200;
    canvas.drawCircle(Offset(15 + size/2, 15 + size/2), size/2, p);
  }

  Future<BitmapDescriptor> _generateEventMarkerIcon(Event event) async {
    final cacheKey = "event_${event.type}";
    if (_iconCache.containsKey(cacheKey)) return _iconCache[cacheKey]!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0;

    final Paint paint = Paint()..color = Colors.green.shade700;
    canvas.drawCircle(const Offset(size/2, size/2), size/2, paint);
    
    final TextPainter iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: _getEventIconChar(event.type),
      style: const TextStyle(fontSize: 50, color: Colors.white, fontFamily: 'MaterialIcons'),
    );
    iconPainter.layout();
    iconPainter.paint(canvas, Offset(size/2 - iconPainter.width/2, size/2 - iconPainter.height/2));

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _iconCache[cacheKey] = icon;
    return icon;
  }

  String _getEventIconChar(String type) {
    switch (type) {
      case 'cinema': return String.fromCharCode(Icons.movie.codePoint);
      case 'walk': return String.fromCharCode(Icons.directions_walk.codePoint);
      case 'bar': return String.fromCharCode(Icons.local_bar.codePoint);
      case 'restaurant': return String.fromCharCode(Icons.restaurant.codePoint);
      case 'board_games': return String.fromCharCode(Icons.casino.codePoint);
      case 'match': return String.fromCharCode(Icons.sports_soccer.codePoint);
      case 'concert': return String.fromCharCode(Icons.music_note.codePoint);
      default: return String.fromCharCode(Icons.event.codePoint);
    }
  }

  Future<void> _processUserMarkers(List<DocumentSnapshot> docs, bool isAppOnline) async {
    final Map<String, Marker> newMarkers = {};
    for (var doc in docs) {
      if (doc.id == _currentUserId) continue; 
      final user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      if (user.location == null) continue;
      
      if (isAppOnline && user.isOnline) {
        final icon = await _generateUserMarkerIcon(user);
        newMarkers[doc.id] = Marker(
          markerId: MarkerId("user_${doc.id}"),
          position: LatLng(user.location!.latitude, user.location!.longitude),
          icon: icon,
          zIndex: 1,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: doc.id))),
        );
      }
    }
    _userMarkers = newMarkers;
  }

  Future<void> _processEventMarkers(List<DocumentSnapshot> docs) async {
    final Map<String, Marker> newMarkers = {};
    for (var doc in docs) {
      try {
        final event = Event.fromFirestore(doc);
        final icon = await _generateEventMarkerIcon(event);
        newMarkers[doc.id] = Marker(
          markerId: MarkerId("event_${doc.id}"),
          position: LatLng(event.latitude, event.longitude),
          icon: icon,
          zIndex: 5,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)));
          },
        );
      } catch (e) {
        debugPrint("❌ Error processing event doc ${doc.id}: $e");
      }
    }
    _eventMarkers = newMarkers;
  }

  void _goToCurrentLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(_currentPosition!.latitude, _currentPosition!.longitude)));
    }
  }

  void _refreshMap() {
    // Odświeżanie wymaga reklamy (jeśli brak premium)
    if (!_isPremium) {
      _adService.showInterstitialAd();
    }
    _updateCurrentLocation().then((_) => _fetchData());
  }

  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) age--;
    return age;
  }

  Future<void> _rollTheDice() async {
    if (_currentUserModel == null) return;
    final loc = AppLocalizations.of(context)!;
    
    // Rzut kostką również wymaga reklamy
    if (!_isPremium) {
      _adService.showInterstitialAd();
    }

    setState(() => _isLoading = true);

    try {
      final eventsSnap = await _databaseService.getEventsOnce();
      final usersSnap = await _databaseService.getUsersOnce();

      List<dynamic> candidates = [];

      for (var doc in eventsSnap.docs) {
        final event = Event.fromFirestore(doc);
        if (event.creatorId == _currentUserId) continue;
        if (event.participants.contains(_currentUserId)) continue;
        if (event.participants.length >= event.maxParticipants) continue;
        
        bool interestMatch = _currentUserModel!.interests.any((i) => event.description.contains(i) || event.type == i);
        if (interestMatch) candidates.add(event);
      }

      for (var doc in usersSnap.docs) {
        if (doc.id == _currentUserId) continue;
        final user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
        if (!user.isOnline) continue;

        int myAge = _calculateAge(_currentUserModel!.dateOfBirth);
        int userAge = _calculateAge(user.dateOfBirth);

        final v = user.visibilitySettings;
        final ageRange = v['ageRange'];
        bool iMatchUser = myAge >= (ageRange?['min'] ?? 18) && myAge <= (ageRange?['max'] ?? 99);
        
        final myV = _currentUserModel!.visibilitySettings;
        final myAgeRange = myV['ageRange'];
        bool userMatchesMe = userAge >= (myAgeRange?['min'] ?? 18) && userAge <= (myAgeRange?['max'] ?? 99);

        if (iMatchUser && userMatchesMe) {
          bool commonInterests = user.interests.any((i) => _currentUserModel!.interests.contains(i));
          if (commonInterests) candidates.add(user);
        }
      }

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('no_dice_matches'))));
        return;
      }

      final winner = candidates[Random().nextInt(candidates.length)];

      if (winner is Event) {
        _showWinnerDialog(loc.translate('winner_event'), winner.title, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailsScreen(event: winner)));
        });
      } else if (winner is UserModel) {
        _showWinnerDialog(loc.translate('winner_person'), winner.displayName, () {
          _databaseService.sendNotification(winner.uid, _currentUserId, 'dice_roll');
          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerId: winner.uid, peerName: winner.displayName)));
        });
      }

    } catch (e) {
      debugPrint("❌ Dice error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showWinnerDialog(String title, String name, VoidCallback onConfirm) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.casino, size: 60, color: Colors.orange),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.translate('roll_again'))),
          ElevatedButton(onPressed: () {
            Navigator.pop(context);
            onConfirm();
          }, child: Text(loc.translate('check'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateManager>(
      builder: (context, appState, child) {
        // Nie wywołujemy _applyMapStyle() bezpośrednio w build, bo kontroler może być disposed.
        // GoogleMap samo wywoła _onMapCreated przy re-buildzie.

        Set<Marker> allMarkers = {};
        if (_myMarker != null) allMarkers.add(_myMarker!);
        allMarkers.addAll(_userMarkers.values);
        allMarkers.addAll(_eventMarkers.values);

        return Scaffold(
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition != null
                            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                            : const LatLng(52.2297, 21.0122),
                        zoom: 14,
                      ),
                      markers: allMarkers,
                      myLocationEnabled: false, 
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    Positioned(
                      top: 40,
                      right: 20,
                      child: Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'loc_btn',
                            onPressed: _goToCurrentLocation,
                            mini: true,
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.my_location, color: Colors.black),
                          ),
                          const SizedBox(height: 10),
                          FloatingActionButton(
                            heroTag: 'ref_btn',
                            onPressed: _refreshMap,
                            mini: true,
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.refresh, color: Colors.black),
                          ),
                          const SizedBox(height: 10),
                          FloatingActionButton(
                            heroTag: 'dice_btn',
                            onPressed: _rollTheDice,
                            mini: true,
                            backgroundColor: Colors.orange,
                            child: const Icon(Icons.casino, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          FloatingActionButton(
                            heroTag: 'add_event_btn',
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateEventScreen()));
                            },
                            mini: true,
                            backgroundColor: Colors.blue,
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
