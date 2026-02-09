import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _databaseService = DatabaseService();
  final _userId = FirebaseAuth.instance.currentUser!.uid;
  bool _showToMen = true;
  bool _showToWomen = true;
  bool _showToOther = true;
  RangeValues _ageRange = const RangeValues(18, 99);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userData = await _databaseService.getUserData(_userId);
    if (userData.exists) {
      final data = userData.data() as Map<String, dynamic>;
      final settings = data['visibilitySettings'];
      if (settings != null) {
        setState(() {
          _showToMen = settings['showToMen'] ?? true;
          _showToWomen = settings['showToWomen'] ?? true;
          _showToOther = settings['showToOther'] ?? true;
          final ageData = settings['ageRange'];
          if (ageData != null) {
            _ageRange = RangeValues(
              (ageData['min'] ?? 18).toDouble(),
              (ageData['max'] ?? 99).toDouble(),
            );
          }
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final loc = AppLocalizations.of(context)!;
    final newSettings = {
      'visibilitySettings': {
        'showToMen': _showToMen,
        'showToWomen': _showToWomen,
        'showToOther': _showToOther,
        'ageRange': {'min': _ageRange.start.round(), 'max': _ageRange.end.round()},
      }
    };
    await _databaseService.updateUserProfile(_userId, newSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('profile_saved'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('privacy_settings'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(loc.translate('who_can_see_me'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: Text(loc.translate('men')),
                  value: _showToMen,
                  onChanged: (val) => setState(() => _showToMen = val),
                ),
                SwitchListTile(
                  title: Text(loc.translate('women')),
                  value: _showToWomen,
                  onChanged: (val) => setState(() => _showToWomen = val),
                ),
                SwitchListTile(
                  title: Text(loc.translate('others')),
                  value: _showToOther,
                  onChanged: (val) => setState(() => _showToOther = val),
                ),
                const Divider(height: 40),
                Text('${loc.translate('age_range')}: ${_ageRange.start.round()} - ${_ageRange.end.round()} ${loc.translate('years')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                RangeSlider(
                  values: _ageRange,
                  min: 18,
                  max: 99,
                  divisions: 81,
                  labels: RangeLabels(_ageRange.start.round().toString(), _ageRange.end.round().toString()),
                  onChanged: (values) => setState(() => _ageRange = values),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _saveSettings, 
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: Text(loc.translate('save').toUpperCase()),
                ),
                const SizedBox(height: 20),
                const Text(
                  'JoinMe Visibility System', // Static info or add key to JSON if needed
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
