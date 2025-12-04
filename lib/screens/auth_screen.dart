import 'package:flutter/material.dart';
import 'main_screen.dart';
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
  final _ageController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                  _isLogin
                      ? 'Zaloguj się do swojego konta'
                      : 'Stwórz nowe konto',
                  style: const TextStyle(
                    color: Color(0xFF757575),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Imię',
                      prefixIcon: Icon(Icons.person),
                      filled: true,
                      fillColor: AppColors.surfaceColor,
                    ),
                    style: const TextStyle(color: AppColors.textColor),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Podaj swoje imię';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                      labelText: 'Wiek',
                      prefixIcon: Icon(Icons.cake),
                      filled: true,
                      fillColor: AppColors.surfaceColor,
                    ),
                    style: const TextStyle(color: AppColors.textColor),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Podaj swój wiek';
                      }
                      final age = int.tryParse(value);
                      if (age == null || age < 16 || age > 100) {
                        return 'Podaj poprawny wiek (16-100)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    filled: true,
                    fillColor: AppColors.surfaceColor,
                  ),
                  style: const TextStyle(color: AppColors.textColor),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Podaj adres email';
                    }
                    if (!value.contains('@')) {
                      return 'Podaj poprawny adres email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Hasło',
                    prefixIcon: Icon(Icons.lock),
                    filled: true,
                    fillColor: AppColors.surfaceColor,
                  ),
                  style: const TextStyle(color: AppColors.textColor),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Podaj hasło';
                    }
                    if (value.length < 6) {
                      return 'Hasło musi mieć co najmniej 6 znaków';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isLogin ? 'Zaloguj się' : 'Zarejestruj się',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _emailController.clear();
                        _passwordController.clear();
                        if (!_isLogin) {
                          _nameController.clear();
                          _ageController.clear();
                        }
                      });
                    },
                    child: Text(
                      _isLogin
                          ? 'Nie masz konta? Zarejestruj się'
                          : 'Masz już konto? Zaloguj się',
                      style: const TextStyle(color: AppColors.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}