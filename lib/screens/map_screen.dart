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
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showBanner = false;
  bool _isAddingPin = false; 
  double _currentZoom = 14.0;
  StreamSubscription? _appStateSubscription;
  late AnimationController _bannerController;
  late Animation<double> _bannerScale;
  
  Map<String, Marker> _userMarkers = {};
  Map<String, Marker> _eventMarkers = {};
  Map<String, Marker> _pinMarkers = {}; 
  Marker? _myMarker;
  
  final _databaseService = DatabaseService();
  final AdService _adService = AdService();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  UserModel? _currentUserModel;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _adService.loadInterstitialAd();

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bannerScale = CurvedAnimation(parent: _bannerController, curve: Curves.easeOutBack);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppStateManager>(context, listen: false);
      if (!appState.hasShownMapBanner) {
        setState(() => _showBanner = true);
        _bannerController.forward();
        appState.setHasShownMapBanner(true);
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted && _showBanner) {
            _bannerController.reverse().then((_) {
              if (mounted) setState(() => _showBanner = false);
            });
          }
        });
      }

      _appStateSubscription = appState.getStream().listen((_) {
         _handleJump();
      });
    });
  }

  void _handleJump() {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    if (appState.mapJumpTo != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(appState.mapJumpTo!, 16));
      appState.clearJumpTo();
    }
  }
  
  @override
  void dispose() {
    _appStateSubscription?.cancel();
    _bannerController.dispose();
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
      if (mounted) setState(() => _currentPosition = position);
      await _fetchData();
      Future.delayed(const Duration(milliseconds: 500), () => _handleJump());
    } catch (e) {
      debugPrint("❌ Map Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchData() async {
    try {
      final appState = Provider.of<AppStateManager>(context, listen: false);
      final userSnapshot = await _databaseService.getUsersOnce();
      final eventSnapshot = await _databaseService.getEventsOnce();
      final pinSnapshot = await _databaseService.getPinsOnce();
      
      List<DocumentSnapshot> filteredUsers = userSnapshot.docs.where((doc) {
        if (doc.id == _currentUserId) return false;
        final data = doc.data() as Map<String, dynamic>;
        if (data['location'] == null) return false;
        GeoPoint loc = data['location'];
        double dist = _calculateDistance(_currentPosition?.latitude ?? 0, _currentPosition?.longitude ?? 0, loc.latitude, loc.longitude);
        return appState.searchRadius == 0 || dist <= appState.searchRadius;
      }).toList();

      List<DocumentSnapshot> filteredEvents = eventSnapshot.docs.where((doc) {
        final event = Event.fromFirestore(doc);
        double dist = _calculateDistance(_currentPosition?.latitude ?? 0, _currentPosition?.longitude ?? 0, event.latitude, event.longitude);
        return appState.searchRadius == 0 || dist <= appState.searchRadius;
      }).toList();

      await _updateMarkers(userDocs: filteredUsers, eventDocs: filteredEvents, pinDocs: pinSnapshot.docs);
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _updateMarkers({List<DocumentSnapshot>? userDocs, List<DocumentSnapshot>? eventDocs, List<DocumentSnapshot>? pinDocs}) async {
    bool miniStyle = _currentZoom < 13.0;

    if (_currentUserModel != null && _currentPosition != null) {
      _myMarker = Marker(
        markerId: const MarkerId("user_me"),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: await _generate3DMarker(_currentUserModel!.photoURL, Colors.blue, miniStyle, _currentUserModel!.displayName),
        zIndex: 10,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: _currentUserId))),
      );
    }

    if (userDocs != null) {
      final Map<String, Marker> newUsers = {};
      for (var doc in userDocs) {
        final user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
        newUsers[doc.id] = Marker(
          markerId: MarkerId("user_${doc.id}"),
          position: LatLng(user.location!.latitude, user.location!.longitude),
          icon: await _generate3DMarker(user.photoURL, Colors.green, miniStyle, user.displayName),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: doc.id))),
        );
      }
      _userMarkers = newUsers;
    }

    if (eventDocs != null) {
      final Map<String, Marker> newEvents = {};
      for (var doc in eventDocs) {
        final event = Event.fromFirestore(doc);
        newEvents[doc.id] = Marker(
          markerId: MarkerId("event_${doc.id}"),
          position: LatLng(event.latitude, event.longitude),
          icon: await _generate3DEventMarker(event.type, miniStyle),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event))),
        );
      }
      _eventMarkers = newEvents;
    }

    if (pinDocs != null) {
      final Map<String, Marker> newPins = {};
      for (var doc in pinDocs) {
        final pin = PinModel.fromFirestore(doc);
        newPins[doc.id] = Marker(
          markerId: MarkerId("pin_${doc.id}"),
          position: LatLng(pin.latitude, pin.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: pin.title), // POPRAWKA: InfoWindow zamiast InfoTitle
        );
      }
      _pinMarkers = newPins;
    }
    if (mounted) setState(() {});
  }

  void _onMapLongPress(LatLng point) {
    if (!_isAddingPin) return;
    
    final TextEditingController pinController = TextEditingController();
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: Text(loc.translate('name_point'), style: const TextStyle(color: Colors.green)),
        content: TextField(
          controller: pinController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: loc.translate('pin_title_hint'), hintStyle: const TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(child: Text(loc.translate('cancel')), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: Text(loc.translate('save')),
            onPressed: () async {
              final pin = PinModel(
                id: '',
                creatorId: _currentUserId,
                creatorName: _currentUserModel?.nickname ?? '', // Używamy Nicku
                title: pinController.text,
                latitude: point.latitude,
                longitude: point.longitude,
                createdAt: DateTime.now(),
              );
              await _databaseService.createPin(pin);
              Navigator.pop(ctx);
              setState(() => _isAddingPin = false);
              _fetchData();
            },
          ),
          ElevatedButton(
            child: Text(loc.translate('create_event')),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isAddingPin = false);
              Navigator.push(context, MaterialPageRoute(builder: (context) => CreateEventScreen(
                initialLat: point.latitude,
                initialLng: point.longitude,
              )));
            },
          ),
        ],
      ),
    );
  }

  void _rollTheDice() async {
    _adService.showInterstitialAd();
    final eventSnapshot = await _databaseService.getEventsOnce();
    if (eventSnapshot.docs.isNotEmpty) {
      final randomIdx = Random().nextInt(eventSnapshot.docs.length);
      final event = Event.fromFirestore(eventSnapshot.docs[randomIdx]);
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(event.latitude, event.longitude), 16));
      }
    }
  }

  void _handleRefresh() {
    _adService.showInterstitialAd();
    _initializeMap();
  }

  void _searchUser() {
    final TextEditingController searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: const Text("Szukaj użytkownika", style: TextStyle(color: Colors.green)),
        content: TextField(
          controller: searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Wpisz nazwę...",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
          ),
        ),
        actions: [
          TextButton(child: const Text("Anuluj", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: const Text("Szukaj", style: TextStyle(color: Colors.green)),
            onPressed: () async {
              Navigator.pop(ctx);
              final snapshot = await _databaseService.getUsersOnce();
              for (var doc in snapshot.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['displayName'].toString().toLowerCase().contains(searchController.text.toLowerCase())) {
                  final GeoPoint? loc = data['location'];
                  if (loc != null && _mapController != null) {
                    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(loc.latitude, loc.longitude), 16));
                    return;
                  }
                }
              }
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nie znaleziono użytkownika.")));
            },
          ),
        ],
      ),
    );
  }

  Future<BitmapDescriptor> _generate3DMarker(String url, Color color, bool mini, String name) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double size = mini ? 100 : 160;
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(Rect.fromLTWH(size * 0.25, size * 0.85, size * 0.5, size * 0.15), shadowPaint);
    final Paint bubblePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size/2, size/2 - 15), size/2 - 10, bubblePaint);
    final Paint borderPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6;
    canvas.drawCircle(Offset(size/2, size/2 - 15), size/2 - 10, borderPaint);
    await _drawAvatar(canvas, url, size - 35, size/2, size/2 - 15);
    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _generate3DEventMarker(String type, bool mini) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double size = mini ? 90 : 140;
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(Rect.fromLTWH(size * 0.25, size * 0.88, size * 0.5, size * 0.12), shadowPaint);
    final Paint p = Paint()..color = Colors.orange.shade800;
    canvas.drawCircle(Offset(size/2, size/2 - 12), size/2 - 8, p);
    final Paint border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4;
    canvas.drawCircle(Offset(size/2, size/2 - 12), size/2 - 8, border);
    final TextPainter iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: _getEventIconChar(type),
      style: TextStyle(fontSize: size/2, color: Colors.white, fontFamily: 'MaterialIcons'),
    );
    iconPainter.layout();
    iconPainter.paint(canvas, Offset(size/2 - iconPainter.width/2, size/2 - 12 - iconPainter.height/2));
    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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

  Future<void> _drawAvatar(Canvas canvas, String url, double size, double x, double y) async {
    if (url.isEmpty) {
      canvas.drawCircle(Offset(x, y), size/2, Paint()..color = Colors.grey);
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
    } catch (e) {
      canvas.drawCircle(Offset(x, y), size/2, Paint()..color = Colors.grey);
    }
  }

  void _goToCurrentLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 14));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final loc = AppLocalizations.of(context)!;
    
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
                initialCameraPosition: CameraPosition(
                  target: LatLng(_currentPosition?.latitude ?? 52.2, _currentPosition?.longitude ?? 21.0), 
                  zoom: 14
                ),
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
              ),

              if (_showBanner)
                Positioned(
                  top: 80, left: 30, right: 30,
                  child: ScaleTransition(
                    scale: _bannerScale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.6), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.green, size: 30),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              loc.translate('watch_ad_to_refresh'),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.4),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () {
                              if (mounted) {
                                _bannerController.reverse().then((_) {
                                  if (mounted) setState(() => _showBanner = false);
                                });
                              }
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                ),

              if (_isAddingPin)
                Positioned(
                  top: 60, left: 40, right: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.cyanAccent)),
                    child: Text(loc.translate('add_pin_hint'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),

              Positioned(
                top: 40,
                right: 20,
                child: Column(
                  children: [
                    // 1. OKO (ONLINE/OFFLINE)
                    FloatingActionButton(
                      heroTag: 'eye_btn', 
                      onPressed: () => appState.toggleOnlineStatus(), 
                      mini: true, 
                      backgroundColor: appState.isOnline ? Colors.green : Colors.red, 
                      child: Icon(appState.isOnline ? Icons.visibility : Icons.visibility_off, color: Colors.white)
                    ),
                    const SizedBox(height: 10),
                    // 2. WIDOCZNOŚĆ (PUBLICZNY / PRYWATNY)
                    FloatingActionButton(
                      heroTag: 'visibility_toggle_btn', 
                      onPressed: () => appState.toggleVisibility(), 
                      mini: true, 
                      backgroundColor: appState.visibility == 'public' ? Colors.blue : Colors.purple, 
                      child: Icon(appState.visibility == 'public' ? Icons.public : Icons.group, color: Colors.white)
                    ),
                    const SizedBox(height: 10),
                    // 3. KOSTKA
                    FloatingActionButton(heroTag: 'dice_btn', onPressed: _rollTheDice, mini: true, backgroundColor: Colors.orange, child: const Icon(Icons.casino, color: Colors.white)),
                    const SizedBox(height: 10),
                    // 4. REFRESH
                    FloatingActionButton(heroTag: 'ref_btn', onPressed: _handleRefresh, mini: true, backgroundColor: Colors.white, child: const Icon(Icons.refresh, color: Colors.black)),
                    const SizedBox(height: 10),
                    // 5. CENTRUJ
                    FloatingActionButton(heroTag: 'loc_btn', onPressed: _goToCurrentLocation, mini: true, backgroundColor: Colors.white, child: const Icon(Icons.my_location, color: Colors.black)),
                    const SizedBox(height: 10),
                    // 6. DODAJ WYDARZENIE
                    FloatingActionButton(heroTag: 'add_event_btn', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateEventScreen())), mini: true, backgroundColor: Colors.blue, child: const Icon(Icons.add, color: Colors.white)),
                    const SizedBox(height: 10),
                    // 7. SZUKAJ
                    FloatingActionButton(heroTag: 'search_user_btn', onPressed: _searchUser, mini: true, backgroundColor: Colors.teal, child: const Icon(Icons.person_search, color: Colors.white)),
                    const SizedBox(height: 10),
                    // 8. PINEZKA
                    FloatingActionButton(
                      heroTag: 'add_pin_btn', 
                      onPressed: () => setState(() => _isAddingPin = !_isAddingPin), 
                      mini: true, 
                      backgroundColor: _isAddingPin ? Colors.cyanAccent : Colors.white, 
                      child: Icon(Icons.push_pin, color: _isAddingPin ? Colors.white : Colors.black)
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
