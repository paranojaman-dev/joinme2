import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/screens/auth_wrapper.dart';
import 'package:joinme2/screens/help_screen.dart';
import 'package:joinme2/screens/premium_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:joinme2/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsAllowed = false;
  final DatabaseService _databaseService = DatabaseService();
  UserModel? _userModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await _databaseService.getUserData(user.uid);
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>);
            _isLoading = false;
          });
        }
      }
    }
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

  Future<void> _updateNotifyFriends(bool value) async {
    if (_userModel == null) return;
    await _databaseService.updateNotificationSettings(_userModel!.uid, friends: value);
    setState(() {
      _userModel = UserModel.fromMap({..._userModel!.toMap(), 'notifyFriends': value});
    });
  }

  Future<void> _updateNotifyFriendEvents(bool value) async {
    if (_userModel == null) return;
    await _databaseService.updateNotificationSettings(_userModel!.uid, friendEvents: value);
    setState(() {
      _userModel = UserModel.fromMap({..._userModel!.toMap(), 'notifyFriendEvents': value});
    });
  }

  Future<void> _updateNotifyAllEvents(bool value) async {
    if (_userModel == null) return;
    await _databaseService.updateNotificationSettings(_userModel!.uid, allEvents: value);
    setState(() {
      _userModel = UserModel.fromMap({..._userModel!.toMap(), 'notifyAllEvents': value});
    });
  }

  Future<void> _rateUs() async {
    const String packageName = "com.joinme2.app";
    final Uri url = Uri.parse("https://play.google.com/store/apps/details?id=$packageName");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open Store")));
      }
    }
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
          TextButton(child: Text(loc.translate('cancel')), onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            child: Text(loc.translate('delete_account'), style: const TextStyle(color: Colors.red)),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.red)));
                try {
                  await _databaseService.deleteAccount(user.uid);
                  if (mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(ctx).pop();
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const AuthWrapper()), (r) => false);
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('login_again_to_delete'))));
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const AuthWrapper()), (r) => false);
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
                leading: const Icon(Icons.stars, color: Colors.amber),
                title: Text(loc.translate('get_premium') ?? "Zyskaj Premium", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                subtitle: Text(loc.translate('premium_desc')),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PremiumScreen())),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(loc.translate('notifications_settings'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
              ListTile(
                leading: Icon(Icons.notifications_active, color: _notificationsAllowed ? Colors.green : Colors.grey),
                title: Text(loc.translate('push_notifications')),
                trailing: Switch(value: _notificationsAllowed, onChanged: _toggleNotifications, activeColor: Colors.green),
              ),
              if (_userModel != null) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.person_outline),
                  title: Text(loc.translate('notify_friends')),
                  value: _userModel!.notifyFriends,
                  onChanged: _notificationsAllowed ? _updateNotifyFriends : null,
                  activeColor: Colors.green,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.event_note),
                  title: Text(loc.translate('notify_friend_events')),
                  value: _userModel!.notifyFriendEvents,
                  onChanged: _notificationsAllowed ? _updateNotifyFriendEvents : null,
                  activeColor: Colors.green,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.map_outlined),
                  title: Text(loc.translate('notify_all_events')),
                  value: _userModel!.notifyAllEvents,
                  onChanged: _notificationsAllowed ? _updateNotifyAllEvents : null,
                  activeColor: Colors.green,
                ),
              ],
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
                    DropdownMenuItem(value: 'neon', child: Text(loc.translate('style_neon'))),
                    DropdownMenuItem(value: 'alice', child: Text(loc.translate('style_alice'))),
                    DropdownMenuItem(value: 'medieval', child: Text(loc.translate('style_medieval'))),
                    DropdownMenuItem(value: 'joinme', child: Text(loc.translate('style_joinme'))),
                  ],
                  onChanged: (v) { if (v != null) appState.setMapStyle(v); },
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
                  onChanged: (v) { if (v != null) appState.setLocale(v); },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.green),
                title: Text(loc.translate('help')),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const HelpScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline, color: Colors.amber),
                title: Text(loc.translate('feedback')),
                onTap: _rateUs,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.policy_outlined, color: Colors.blueGrey),
                title: Text(loc.translate('privacy_policy')),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PrivacyPolicyScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(loc.translate('logout')),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const AuthWrapper()), (r) => false);
                  }
                },
              ),
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
