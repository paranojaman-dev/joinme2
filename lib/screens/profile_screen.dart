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
  final _displayNameController = TextEditingController();
  final _statusController = TextEditingController();
  final _interestsController = TextEditingController();
  final _languagesController = TextEditingController();

  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  final _auth = FirebaseAuth.instance;
  User? _user;
  UserModel? _userModel;

  File? _image;
  String? _photoURL;
  bool _isLoading = true;

  DateTime? _dateOfBirth;
  String? _gender;
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

  @override
  void dispose() {
    _displayNameController.dispose();
    _statusController.dispose();
    _interestsController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    _user = _auth.currentUser;
    if (_user != null) {
      final userData = await _databaseService.getUserData(_user!.uid);
      if (userData.exists && userData.data() != null) {
        final data = userData.data() as Map<String, dynamic>;
        _userModel = UserModel.fromMap(data);

        _displayNameController.text = _userModel!.displayName;
        _statusController.text = _userModel!.status ?? '';
        _interestsController.text = _userModel!.interests.join(', ');
        _languagesController.text = _userModel!.languages?.join(', ') ?? '';
        _photoURL = _userModel!.photoURL;
        _dateOfBirth = _userModel!.dateOfBirth;
        _gender = _userModel!.gender;

        final visibility = _userModel!.visibilitySettings;
        if (visibility != null && visibility.containsKey('ageRange')) {
          _visibilityAgeRange = RangeValues(
            (visibility['ageRange']['min'] ?? 18).toDouble(),
            (visibility['ageRange']['max'] ?? 99).toDouble(),
          );
        }
        if (visibility != null) {
          _visibilityGenders = {
            'showToMen': visibility['showToMen'] ?? true,
            'showToWomen': visibility['showToWomen'] ?? true,
            'showToOther': visibility['showToOther'] ?? true,
          };
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _user == null) return;

    setState(() => _isLoading = true);
    final loc = AppLocalizations.of(context)!;
    try {
      String? photoURL = _userModel?.photoURL;
      if (_image != null) {
        photoURL = await _storageService.uploadProfilePicture(_user!.uid, _image!);
      }

      final dataToUpdate = {
        'displayName': _displayNameController.text,
        'photoURL': photoURL,
        'status': _statusController.text,
        'interests': _interestsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'languages': _languagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'visibilitySettings': {
          'showToMen': _visibilityGenders['showToMen'],
          'showToWomen': _visibilityGenders['showToWomen'],
          'showToOther': _visibilityGenders['showToOther'],
          'ageRange': {'min': _visibilityAgeRange.start.round(), 'max': _visibilityAgeRange.end.round()},
        },
      };

      await _databaseService.updateUserProfile(_user!.uid, dataToUpdate);
      
      if (mounted) {
        Provider.of<AppStateManager>(context, listen: false).refreshState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('profile_saved'))),
        );
        _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.translate('profile_save_error')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _getGenderText(String? genderValue, AppLocalizations loc) {
    if (genderValue == null) return loc.translate('loading');
    if (genderValue == 'Mężczyzna' || genderValue == 'male') return loc.translate('male');
    if (genderValue == 'Kobieta' || genderValue == 'female') return loc.translate('female');
    if (genderValue == 'Inna' || genderValue == 'other') return loc.translate('other_gender');
    return loc.translate(genderValue);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('profile')),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // SUBTELNE LOGO W TLE (10% Widoczności)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.10,
                    child: Center(child: Icon(Icons.chair, size: 300, color: Colors.green.shade400)),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: _image != null
                                  ? FileImage(_image!)
                                  : (_photoURL != null && _photoURL!.isNotEmpty ? NetworkImage(_photoURL!) : null) as ImageProvider?,
                              child: _image == null && (_photoURL == null || _photoURL!.isEmpty) ? const Icon(Icons.person, size: 50) : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _displayNameController,
                          decoration: InputDecoration(labelText: loc.translate('full_name'), border: const OutlineInputBorder()),
                          validator: (value) => value!.isEmpty ? loc.translate('enter_full_name') : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _statusController,
                          decoration: InputDecoration(labelText: loc.translate('my_status'), border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: Text(loc.translate('gender')),
                          subtitle: Text(_getGenderText(_gender, loc)),
                          trailing: const Icon(Icons.lock_outline, size: 18),
                        ),
                        const Divider(),
                        TextFormField(
                          controller: _interestsController,
                          decoration: InputDecoration(labelText: loc.translate('interests_hint'), border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        Text("${loc.translate('age_range')}:"),
                        RangeSlider(
                          values: _visibilityAgeRange,
                          min: 18,
                          max: 99,
                          divisions: 81,
                          labels: RangeLabels(_visibilityAgeRange.start.round().toString(), _visibilityAgeRange.end.round().toString()),
                          onChanged: (values) => setState(() => _visibilityAgeRange = values),
                        ),
                        const SizedBox(height: 24),
                        CheckboxListTile(
                          title: Text(loc.translate('men')),
                          value: _visibilityGenders['showToMen'],
                          onChanged: (val) => setState(() => _visibilityGenders['showToMen'] = val!),
                        ),
                        CheckboxListTile(
                          title: Text(loc.translate('women')),
                          value: _visibilityGenders['showToWomen'],
                          onChanged: (val) => setState(() => _visibilityGenders['showToWomen'] = val!),
                        ),
                        CheckboxListTile(
                          title: Text(loc.translate('others')),
                          value: _visibilityGenders['showToOther'],
                          onChanged: (val) => setState(() => _visibilityGenders['showToOther'] = val!),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
