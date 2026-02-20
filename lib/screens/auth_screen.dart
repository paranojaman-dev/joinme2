import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import '../utils/constants.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { login, registerTerms, registerProfile, waitingForVerification }

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthMode _currentMode = AuthMode.login;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _termsAccepted = false;
  Timer? _verificationTimer;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _dobController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedGender;
  
  final _auth = FirebaseAuth.instance;
  final _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      _currentMode = AuthMode.waitingForVerification;
      _startVerificationCheck();
    }
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await user.reload();
          if (user.emailVerified) {
            timer.cancel();
            if (mounted) setState(() {}); // Odświeżenie wymusi przejście przez AuthWrapper
          }
        } catch (e) {
          // Ignorujemy błędy sieciowe w tle
        }
      }
    });
  }

  Future<void> _manualCheckStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        await user.reload();
        if (user.emailVerified) {
          if (mounted) setState(() {});
        } else {
          final loc = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.translate('email_verification'))),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('error')),
        content: Text(message),
        actions: [TextButton(child: const Text('OK'), onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
  }

  void _showCreateAccountPrompt() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('account_not_found')),
        content: Text(loc.translate('ask_create_account')),
        actions: [
          TextButton(child: Text(loc.translate('no')), onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            child: Text(loc.translate('yes')),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _currentMode = AuthMode.registerTerms);
            },
          ),
        ],
      ),
    );
  }

  void _showLoginPrompt() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('account_already_exists')),
        content: Text(loc.translate('ask_login_instead')),
        actions: [
          TextButton(child: Text(loc.translate('no')), onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            child: Text(loc.translate('yes')),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _currentMode = AuthMode.login);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleAuth() async {
    final loc = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_currentMode == AuthMode.login) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _isLoading = true);
      try {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          _showCreateAccountPrompt();
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          // Próbujemy upewnić się czy mail istnieje
          try {
            final methods = await _auth.fetchSignInMethodsForEmail(email);
            if (methods.isEmpty) {
              _showCreateAccountPrompt();
            } else {
              _showErrorDialog(loc.translate('invalid_credentials'));
            }
          } catch (_) {
            _showErrorDialog(loc.translate('invalid_credentials'));
          }
        } else {
          _showErrorDialog(loc.translate('unknown_error'));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } 
    else if (_currentMode == AuthMode.registerTerms) {
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('accept_terms'))));
        return;
      }
      setState(() => _currentMode = AuthMode.registerProfile);
    } 
    else if (_currentMode == AuthMode.registerProfile) {
      if (!_formKey.currentState!.validate() || _selectedDate == null || _selectedGender == null) {
        _showErrorDialog(loc.translate('provide_all_data'));
        return;
      }

      setState(() => _isLoading = true);
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);

        await _dbService.createUserDocument(
          userCredential.user!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          nickname: _nicknameController.text.trim(),
          dateOfBirth: _selectedDate,
        );
        await _dbService.updateUserProfile(userCredential.user!.uid, {
          'gender': _selectedGender,
          'hasAcceptedTerms': true,
        });

        await userCredential.user!.sendEmailVerification();
        setState(() => _currentMode = AuthMode.waitingForVerification);
        _startVerificationCheck();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _showLoginPrompt();
        } else {
          _showErrorDialog(loc.translate('unknown_error'));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _dobController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Center(child: Icon(Icons.chair, color: Colors.green.shade700, size: 60)),
                  const SizedBox(height: 20),
                  
                  if (_currentMode == AuthMode.login) ..._buildLoginFields(loc),
                  if (_currentMode == AuthMode.registerTerms) ..._buildTermsStep(loc),
                  if (_currentMode == AuthMode.registerProfile) ..._buildProfileFields(loc),
                  if (_currentMode == AuthMode.waitingForVerification) ..._buildWaitingStep(loc),

                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_currentMode != AuthMode.waitingForVerification)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: _handleAuth,
                        child: Text(_getButtonText(loc).toUpperCase()),
                      ),
                    ),
                  
                  if (_currentMode != AuthMode.login)
                    Center(child: TextButton(
                      onPressed: () async {
                        await _auth.signOut();
                        setState(() {
                          _verificationTimer?.cancel();
                          _currentMode = AuthMode.login;
                        });
                      }, 
                      child: Text(loc.translate('back'))
                    )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoginFields(AppLocalizations loc) {
    return [
      Text(loc.translate('welcome_back'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(loc.translate('login_subtitle'), style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 30),
      TextFormField(
        controller: _emailController,
        decoration: InputDecoration(labelText: loc.translate('email')),
        validator: (v) => (v!.isEmpty || !v.contains('@')) ? loc.translate('provide_email') : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passwordController,
        decoration: InputDecoration(
          labelText: loc.translate('password'),
          suffixIcon: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        obscureText: !_isPasswordVisible,
        validator: (v) => (v!.length < 6) ? loc.translate('password_too_short') : null,
      ),
    ];
  }

  List<Widget> _buildTermsStep(AppLocalizations loc) {
    return [
      Text(loc.translate('legal_info'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Text(loc.translate('terms_body'), style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      CheckboxListTile(
        title: Text(loc.translate('accept_terms'), style: const TextStyle(fontSize: 14)),
        value: _termsAccepted,
        onChanged: (v) => setState(() => _termsAccepted = v!),
        activeColor: Colors.green,
      ),
    ];
  }

  List<Widget> _buildProfileFields(AppLocalizations loc) {
    return [
      Text(loc.translate('signup_subtitle'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      TextFormField(controller: _firstNameController, decoration: InputDecoration(labelText: loc.translate('first_name'))),
      const SizedBox(height: 12),
      TextFormField(controller: _lastNameController, decoration: InputDecoration(labelText: loc.translate('last_name'))),
      const SizedBox(height: 12),
      TextFormField(controller: _nicknameController, decoration: InputDecoration(labelText: loc.translate('nickname'))),
      const SizedBox(height: 12),
      TextFormField(
        controller: _dobController,
        readOnly: true,
        onTap: _pickDate,
        decoration: InputDecoration(labelText: loc.translate('date_of_birth'), suffixIcon: const Icon(Icons.calendar_today)),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        dropdownColor: Colors.grey.shade900,
        value: _selectedGender,
        decoration: InputDecoration(labelText: loc.translate('gender')),
        items: ['male', 'female', 'other_gender'].map((key) => DropdownMenuItem(value: key, child: Text(loc.translate(key)))).toList(),
        onChanged: (val) => setState(() => _selectedGender = val),
      ),
    ];
  }

  List<Widget> _buildWaitingStep(AppLocalizations loc) {
    return [
      const Center(child: Icon(Icons.mark_email_read, color: Colors.green, size: 80)),
      const SizedBox(height: 24),
      Center(child: Text(loc.translate('email_verification'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      const SizedBox(height: 16),
      Text(loc.translate('verification_sent_body'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 30),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _manualCheckStatus,
          child: const Text("ODŚWIEŻ STATUS"),
        ),
      ),
    ];
  }

  String _getButtonText(AppLocalizations loc) {
    switch (_currentMode) {
      case AuthMode.login: return loc.translate('login');
      case AuthMode.registerTerms: return loc.translate('next');
      case AuthMode.registerProfile: return loc.translate('signup');
      default: return "";
    }
  }
}
