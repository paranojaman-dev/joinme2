import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/models/user_model.dart';
import 'package:joinme2/screens/settings_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/services/storage_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _statusController = TextEditingController();
  final _interestsController = TextEditingController();

  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  final _auth = FirebaseAuth.instance;
  User? _user;
  UserModel? _userModel;

  File? _image;
  String? _photoURL;
  bool _isLoading = true;
  int _eventCount = 0;

  RangeValues _visibilityAgeRange = const RangeValues(18, 99);
  Map<String, bool> _visibilityGenders = {
    'showToMen': true,
    'showToWomen': true,
    'showToOther': true,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _user = _auth.currentUser;
    if (_user != null) {
      final userData = await _databaseService.getUserData(_user!.uid);
      if (userData.exists) {
        _userModel = UserModel.fromMap(userData.data() as Map<String, dynamic>);
        _statusController.text = _userModel!.status ?? '';
        _interestsController.text = _userModel!.interests.join(', ');
        _photoURL = _userModel!.photoURL;

        final visibility = _userModel!.visibilitySettings;
        if (visibility.containsKey('ageRange')) {
          _visibilityAgeRange = RangeValues(
            (visibility['ageRange']['min'] ?? 18).toDouble(),
            (visibility['ageRange']['max'] ?? 99).toDouble(),
          );
        }
        _visibilityGenders = {
          'showToMen': visibility['showToMen'] ?? true,
          'showToWomen': visibility['showToWomen'] ?? true,
          'showToOther': visibility['showToOther'] ?? true,
        };
      }
      
      final events = await _databaseService.getEventsOnce();
      _eventCount = events.docs.where((d) => d['creatorId'] == _user!.uid).length;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _user == null) return;
    setState(() => _isLoading = true);
    
    String? photoURL = _photoURL;
    if (_image != null) {
      photoURL = await _storageService.uploadProfilePicture(_user!.uid, _image!);
    }

    final data = {
      'status': _statusController.text,
      'interests': _interestsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'photoURL': photoURL,
      'visibilitySettings': {
        'showToMen': _visibilityGenders['showToMen'],
        'showToWomen': _visibilityGenders['showToWomen'],
        'showToOther': _visibilityGenders['showToOther'],
        'ageRange': {'min': _visibilityAgeRange.start.round(), 'max': _visibilityAgeRange.end.round()},
      },
    };

    await _databaseService.updateUserProfile(_user!.uid, data);
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.translate('profile_saved'))));
    }
  }

  String _getGenderTranslation(String? gender, AppLocalizations loc) {
    if (gender == null) return '---';
    String g = gender.toLowerCase();
    if (g == 'male' || g == 'mężczyzna') return loc.translate('male');
    if (g == 'female' || g == 'kobieta') return loc.translate('female');
    return loc.translate('other_gender');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final appState = Provider.of<AppStateManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('profile')),
        actions: [
          IconButton(
            icon: Icon(appState.isOnline ? Icons.visibility : Icons.visibility_off),
            color: appState.isOnline ? Colors.green : Colors.red,
            onPressed: () => appState.toggleOnlineStatus(),
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen()))),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.10,
                  child: Center(child: Icon(Icons.chair, size: 300, color: Colors.green.shade400)),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (picked != null) setState(() => _image = File(picked.path));
                        },
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.green.shade700,
                          child: CircleAvatar(
                            radius: 56,
                            backgroundImage: _image != null ? FileImage(_image!) : (_photoURL != null && _photoURL!.isNotEmpty ? NetworkImage(_photoURL!) : null) as ImageProvider?,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      _buildSectionCard(
                        icon: Icons.badge_outlined,
                        title: loc.translate('full_name'),
                        child: Text(_userModel?.displayName ?? '', style: const TextStyle(fontSize: 18, color: Colors.white)),
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _buildSectionCard(
                              icon: Icons.cake_outlined,
                              title: loc.translate('age_calculated'),
                              child: Text("${_userModel?.age ?? '??'} ${loc.translate('years')}", style: const TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSectionCard(
                              icon: Icons.people_outline,
                              title: loc.translate('gender'),
                              child: Text(_getGenderTranslation(_userModel?.gender, loc), style: const TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),

                      _buildSectionCard(
                        icon: Icons.event_note,
                        title: loc.translate('my_events_count'),
                        child: Text("$_eventCount ${loc.translate('active_events')}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),

                      _buildSectionCard(
                        icon: Icons.chat_bubble_outline,
                        title: loc.translate('my_status'),
                        child: TextFormField(
                          controller: _statusController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(border: InputBorder.none, hintText: loc.translate('status_hint')),
                        ),
                      ),

                      _buildSectionCard(
                        icon: Icons.favorite_border,
                        title: loc.translate('interests_hint'),
                        child: TextFormField(
                          controller: _interestsController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(border: InputBorder.none, hintText: loc.translate('interests_placeholder')),
                        ),
                      ),

                      _buildSectionCard(
                        icon: Icons.radar,
                        title: "${loc.translate('search_radius')}: ${appState.searchRadius.round()} km",
                        child: Slider(
                          value: appState.searchRadius,
                          min: 2, max: 500, divisions: 50,
                          activeColor: Colors.green,
                          label: "${appState.searchRadius.round()} km",
                          onChanged: (v) => appState.setSearchRadius(v),
                        ),
                      ),

                      _buildSectionCard(
                        icon: Icons.manage_search,
                        title: "${loc.translate('visibility_age_desc')}: ${_visibilityAgeRange.start.round()} - ${_visibilityAgeRange.end.round()} ${loc.translate('years')}",
                        child: RangeSlider(
                          values: _visibilityAgeRange,
                          min: 18, max: 99, divisions: 81,
                          activeColor: Colors.green,
                          labels: RangeLabels(
                            _visibilityAgeRange.start.round().toString(),
                            _visibilityAgeRange.end.round().toString(),
                          ),
                          onChanged: (v) => setState(() => _visibilityAgeRange = v),
                        ),
                      ),

                      _buildSectionCard(
                        icon: Icons.visibility_outlined,
                        title: loc.translate('who_can_see_me'),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: Text(loc.translate('men'), style: const TextStyle(color: Colors.white)),
                              value: _visibilityGenders['showToMen'],
                              activeColor: Colors.green,
                              onChanged: (v) => setState(() => _visibilityGenders['showToMen'] = v!),
                            ),
                            CheckboxListTile(
                              title: Text(loc.translate('women'), style: const TextStyle(color: Colors.white)),
                              value: _visibilityGenders['showToWomen'],
                              activeColor: Colors.green,
                              onChanged: (v) => setState(() => _visibilityGenders['showToWomen'] = v!),
                            ),
                            CheckboxListTile(
                              title: Text(loc.translate('others'), style: const TextStyle(color: Colors.white)),
                              value: _visibilityGenders['showToOther'],
                              activeColor: Colors.green,
                              onChanged: (v) => setState(() => _visibilityGenders['showToOther'] = v!),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                          child: Text(loc.translate('save').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionCard({required IconData icon, required String title, required Widget child}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Divider(color: Colors.white10),
            child,
          ],
        ),
      ),
    );
  }
}
