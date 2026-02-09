import 'package:flutter/material.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/screens/auth_wrapper.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  _navigateToNext() async {
    // Czekaj na inicjalizację AppStateManager
    final appState = Provider.of<AppStateManager>(context, listen: false);
    while (!appState.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Używamy standardowego tekstu, dopóki AppLocalizations nie będzie gotowy
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.chair,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'JoinMe',
              style: TextStyle(
                color: AppColors.textColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Consumer<AppStateManager>(
              builder: (context, appState, child) {
                if (!appState.isInitialized) return const SizedBox.shrink();
                final loc = AppLocalizations.of(context);
                return Text(
                  loc?.translate('splash_tagline') ?? 'Znajdź towarzystwo',
                  style: const TextStyle(
                    color: Color(0xFF757575),
                    fontSize: 16,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
