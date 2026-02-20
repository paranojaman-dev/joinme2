import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/screens/auth_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:provider/provider.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsAllowed = false;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _notificationsAllowed = status.isGranted);
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (status.isPermanentlyDenied) openAppSettings();
    } else {
      openAppSettings();
    }
    _checkNotificationStatus();
  }

  void _showDeleteConfirmationDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('confirm_delete')),
        content: Text(loc.translate('delete_account_confirm_body')),
        actions: [
          TextButton(
            child: Text(loc.translate('cancel')), 
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text(loc.translate('delete_account'), style: const TextStyle(color: Colors.red)),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                // Pokazujemy loader
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.red)),
                );

                try {
                  // Nowa metoda czyści WSZYSTKO (Firestore + Auth)
                  await _databaseService.deleteAccount(user.uid);
                  
                  if (mounted) {
                    Navigator.of(context).pop(); // Zamknij loader
                    Navigator.of(ctx).pop();     // Zamknij confirm dialog
                    
                    // Czyścimy stos i idziemy do logowania
                    Navigator.pushAndRemoveUntil(
                      context, 
                      MaterialPageRoute(builder: (context) => const AuthScreen()), 
                      (route) => false
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop(); // Zamknij loader
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.translate('login_again_to_delete')))
                    );
                    await FirebaseAuth.instance.signOut();
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Consumer<AppStateManager>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(title: Text(loc.translate('settings'))),
          body: ListView(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.notifications_active, color: _notificationsAllowed ? Colors.green : Colors.grey),
                title: Text(loc.translate('push_notifications')),
                subtitle: Text(loc.translate('push_notifications_sub')),
                trailing: Switch(
                  value: _notificationsAllowed, 
                  onChanged: _toggleNotifications,
                  activeColor: Colors.green,
                ),
              ),
              const Divider(),
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
                    DropdownMenuItem(value: 'neon', child: Text(loc.translate('style_neon'))),
                  ],
                  onChanged: (value) { if (value != null) appState.setMapStyle(value); },
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
                  onChanged: (value) { if (value != null) appState.setLocale(value); },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.policy_outlined, color: Colors.blueGrey),
                title: Text(loc.translate('privacy_policy')),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                title: Text(loc.translate('about_app')),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: "JoinMe",
                    applicationVersion: "1.0.0",
                    applicationIcon: const Icon(Icons.chair, color: Colors.green, size: 40),
                    children: [Text(loc.translate('about_app_body'))],
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(loc.translate('logout')),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(loc.translate('delete_account'), style: const TextStyle(color: Colors.red)),
                onTap: _showDeleteConfirmationDialog,
              ),
            ],
          ),
        );
      },
    );
  }
}
