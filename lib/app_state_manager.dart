import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:joinme2/services/database_service.dart';

class AppStateManager extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  bool _isOnline = true;
  String _mapStyle = 'normal';
  Locale _locale = const Locale('pl');
  bool _isInitialized = false;

  bool get isOnline => _isOnline;
  String get mapStyle => _mapStyle;
  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  AppStateManager() {
    _loadInitialState();
  }

  void _loadInitialState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Intl.defaultLocale = _locale.languageCode;
      _isInitialized = true;
      notifyListeners();
      return;
    }

    try {
      final userDoc = await _databaseService.getUserData(user.uid);
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        
        final status = data['status_info'];
        if (status is Map) {
          _isOnline = status['isOnline'] ?? true;
        }

        _mapStyle = data['mapStyle'] ?? 'normal';

        final langCode = data['languageCode'] ?? 'pl';
        _locale = Locale(langCode);
        Intl.defaultLocale = langCode;
      }
    } catch (e) {
      debugPrint("Error loading user state: $e");
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleOnlineStatus() async {
    if (_userId == null) return;
    _isOnline = !_isOnline;
    await _databaseService.updateUserStatus(_userId!, _isOnline);
    notifyListeners();
  }

  Future<void> setMapStyle(String style) async {
    if (_userId == null) return;
    _mapStyle = style;
    await _databaseService.updateMapStyle(_userId!, style);
    notifyListeners();
  }

  Future<void> setLocale(String langCode) async {
    if (_userId == null) return;
    _locale = Locale(langCode);
    Intl.defaultLocale = langCode;
    await _databaseService.updateUserProfile(_userId!, {'languageCode': langCode});
    notifyListeners();
  }

  void refreshState() {
    _isInitialized = false;
    _loadInitialState();
  }
}
