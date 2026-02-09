import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/screens/auth_screen.dart';
import 'package:joinme2/screens/privacy_settings_screen.dart';
import 'package:joinme2/screens/privacy_policy_screen.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(loc.translate('confirm_delete')),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(loc.translate('delete_warning')),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(loc.translate('cancel')),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(loc.translate('delete_account')),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteAccount(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await user.delete();
      await FirebaseAuth.instance.signOut();
      navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Consumer<AppStateManager>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(loc.translate('settings')),
          ),
          body: Stack(
            children: [
              // SUBTELNE LOGO W TLE (Watermark)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05, // Bardzo delikatne, zielone tło
                  child: Center(
                    child: Icon(
                      Icons.chair, // Twoje logo (fotel)
                      size: 300,
                      color: Colors.green.shade400,
                    ),
                  ),
                ),
              ),
              // LISTA USTAWIEŃ
              ListView(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.map, color: Colors.blue),
                    title: Text(loc.translate('map_style')),
                    trailing: DropdownButton<String>(
                      value: appState.mapStyle,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(value: 'normal', child: Text(loc.translate('style_normal'))),
                        DropdownMenuItem(value: 'dark', child: Text(loc.translate('style_dark'))),
                        DropdownMenuItem(value: 'retro', child: Text(loc.translate('style_retro'))),
                      ],
                      onChanged: (value) {
                        if (value != null) appState.setMapStyle(value);
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.blue),
                    title: Text(loc.translate('language')),
                    trailing: DropdownButton<String>(
                      value: appState.locale.languageCode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'pl', child: Text('Polski')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                        DropdownMenuItem(value: 'es', child: Text('Español')),
                        DropdownMenuItem(value: 'it', child: Text('Italiano')),
                        DropdownMenuItem(value: 'zh', child: Text('中文')),
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      ],
                      onChanged: (value) {
                        if (value != null) appState.setLocale(value);
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: Colors.teal),
                    title: Text(loc.translate('privacy_policy')),
                    subtitle: Text(loc.translate('privacy_policy_sub')),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: Colors.teal),
                    title: Text(loc.translate('privacy_settings')),
                    subtitle: Text(loc.translate('privacy_settings_sub')),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacySettingsScreen())),
                  ),
                  const Divider(),
                  // OPCJA PREMIUM (Złoty Kolor)
                  ListTile(
                    leading: const Icon(Icons.card_membership, color: Colors.amber), // Złota ikona
                    title: Text(
                      loc.translate('premium'), 
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)
                    ),
                    subtitle: const Text('Remove ads and see everyone instantly', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      // Tutaj logika zakupu w przyszłości
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(loc.translate('about_app')),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'JoinMe',
                        applicationVersion: '1.0.0',
                        applicationIcon: const Icon(Icons.chair, color: Colors.green, size: 40),
                        children: [Text(loc.translate('app_title'))],
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(loc.translate('logout')),
                    onTap: () => _signOut(context),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                    title: Text(loc.translate('delete_account'), style: TextStyle(color: Colors.red.shade700)),
                    onTap: () => _showDeleteConfirmationDialog(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
