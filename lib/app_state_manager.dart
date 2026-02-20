import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateManager extends ChangeNotifier {
  Locale _locale = const Locale('pl');
  String _mapStyle = 'normal';
  bool _isOnline = true;
  String _visibility = 'public'; // 'public' lub 'private'
  bool _isInitialized = false;
  LatLng? _mapJumpTo;
  int _currentTabIndex = 0;
  bool _hasShownMapBanner = false; 
  
  final _controller = StreamController<void>.broadcast();
  Stream<void> getStream() => _controller.stream;

  double _searchRadius = 50.0;

  Locale get locale => _locale;
  String get mapStyle => _mapStyle;
  bool get isOnline => _isOnline;
  String get visibility => _visibility;
  bool get isInitialized => _isInitialized;
  LatLng? get mapJumpTo => _mapJumpTo;
  int get currentTabIndex => _currentTabIndex;
  double get searchRadius => _searchRadius;
  bool get hasShownMapBanner => _hasShownMapBanner;

  AppStateManager() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _mapStyle = prefs.getString('mapStyle') ?? 'normal';
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await DatabaseService().getUserData(user.uid);
      if (userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        _visibility = data['visibility'] ?? 'public';
      }
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  void setHasShownMapBanner(bool value) {
    _hasShownMapBanner = value;
    notifyListeners();
  }

  void setLocale(String languageCode) {
    _locale = Locale(languageCode);
    notifyListeners();
  }

  void setSearchRadius(double radius) {
    _searchRadius = radius;
    notifyListeners();
  }

  Future<void> setMapStyle(String style) async {
    _mapStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mapStyle', style);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await DatabaseService().updateMapStyle(user.uid, style);
    }
    notifyListeners();
  }

  Future<void> toggleVisibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _visibility = _visibility == 'public' ? 'private' : 'public';
      await DatabaseService().updateUserVisibility(user.uid, _visibility);
      notifyListeners();
    }
  }

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void jumpToLocationOnMap(LatLng location) {
    _mapJumpTo = location;
    _currentTabIndex = 0; 
    notifyListeners();
    _controller.add(null); 
  }

  void clearJumpTo() {
    _mapJumpTo = null;
  }

  Future<void> toggleOnlineStatus() async {
    _isOnline = !_isOnline;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await DatabaseService().updateUserStatus(user.uid, _isOnline);
    }
    notifyListeners();
  }

  // TA METODA BYŁA POTRZEBNA DLA ONBOARDINGU
  void refreshState() {
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
