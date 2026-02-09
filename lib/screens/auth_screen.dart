import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:joinme2/screens/main_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import '../utils/constants.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  final _auth = FirebaseAuth.instance;
  final _dbService = DatabaseService();

  void _showErrorDialog(String message, {bool showResendButton = false, User? user}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wystąpił błąd'),
        content: Text(message),
        actions: <Widget>[
          if (showResendButton && user != null)
            TextButton(
              child: const Text('Wyślij ponownie'),
              onPressed: () async {
                try {
                  await user.sendEmailVerification();
                  Navigator.of(ctx).pop();
                  _showVerificationDialog(resent: true);
                } on FirebaseAuthException catch (e) {
                  Navigator.of(ctx).pop();
                  _showErrorDialog(e.message ?? 'Nie udało się wysłać e-maila.');
                }
              },
            ),
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (showResendButton) {
                _auth.signOut();
              }
            },
          )
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await _dbService.createUserDocument(
          userCredential.user!,
          displayName: _nameController.text,
          dateOfBirth: _selectedDate,
        );
        // Save gender during creation
        await _dbService.updateUserProfile(userCredential.user!.uid, {'gender': _selectedGender});
        
        await userCredential.user!.sendEmailVerification();
        _showVerificationDialog();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Wystąpił nieznany błąd.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'E-mail lub hasło nieprawidłowe.';
      }
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVerificationDialog({bool resent = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(resent ? 'E-mail wysłany ponownie' : 'Weryfikacja E-mail'),
        content: const Text('Link weryfikacyjny został wysłany na Twój adres e-mail. Proszę potwierdzić, aby móc się zalogować.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!resent) {
                setState(() {
                  _isLogin = true;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showErrorDialog('Wprowadź poprawny adres e-mail, aby zresetować hasło.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('Wysłano link do resetowania hasła'),
              content: const Text('Sprawdź swoją skrzynkę mailową.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'))
              ]));
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(e.message ?? 'Wystąpił nieznany błąd');
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _dobController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
                  const SizedBox(height: 40),
                  Text(
                    _isLogin ? 'Witaj z powrotem!' : 'Dołącz do JoinMe',
                    style: const TextStyle(
                      color: AppColors.textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Zaloguj się do swojego konta' : 'Stwórz nowe konto',
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Imię'),
                      validator: (value) => value!.isEmpty ? 'Podaj swoje imię' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dobController,
                      decoration: const InputDecoration(labelText: 'Data urodzenia'),
                      readOnly: true,
                      onTap: _pickDate,
                      validator: (value) => value!.isEmpty ? 'Podaj datę urodzenia' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(labelText: 'Płeć'),
                      items: [
                        {'val': 'Mężczyzna', 'key': 'male'},
                        {'val': 'Kobieta', 'key': 'female'},
                        {'val': 'Inna', 'key': 'other_gender'}
                      ].map((item) {
                        return DropdownMenuItem<String>(
                          value: item['val'],
                          child: Text(loc?.translate(item['key']!) ?? item['val']!),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedGender = val),
                      validator: (val) => val == null ? 'Wybierz płeć' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        (value!.isEmpty || !value.contains('@')) ? 'Podaj poprawny adres email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Hasło',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (value) =>
                        (value!.length < 6) ? 'Hasło musi mieć co najmniej 6 znaków' : null,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(_isLogin ? 'Zaloguj się' : 'Zarejestruj się'),
                      ),
                    ),
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Nie pamiętasz hasła?'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin ? 'Nie masz konta? Zarejestruj się' : 'Masz już konto? Zaloguj się'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
