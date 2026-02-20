import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/screens/premium_screen.dart';
import 'package:joinme2/screens/main_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0; // 0: Wybór Mapy, 1: Premium
  bool _isFinishing = false;
  final DatabaseService _dbService = DatabaseService();

  Future<void> _finishOnboarding(bool wantPremium) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Zapisujemy zakończenie onboardingu w Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'hasCompletedOnboarding': true,
        });
        
        if (mounted) {
          // Odświeżamy stan globalny
          Provider.of<AppStateManager>(context, listen: false).refreshState();
          
          if (wantPremium) {
            // Jeśli chce premium, idzie do ekranu premium (z możliwością powrotu do Main)
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const PremiumScreen())
            );
          } else {
            // Jeśli nie chce, idzie prosto do MainScreen
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const MainScreen())
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final appState = Provider.of<AppStateManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(child: Icon(Icons.chair, color: Colors.green.shade700, size: 40)),
              const SizedBox(height: 30),
              Expanded(
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    // KROK 1: WYBÓR MAPY
                    _buildStep(
                      icon: Icons.map_outlined,
                      title: loc.translate('choose_map_style'),
                      content: Column(
                        children: [
                          _mapStyleOption(appState, 'normal', loc.translate('style_normal')),
                          _mapStyleOption(appState, 'dark', loc.translate('style_dark')),
                          _mapStyleOption(appState, 'neon', loc.translate('style_neon')),
                        ],
                      ),
                    ),
                    // KROK 2: PREMIUM
                    _buildStep(
                      icon: Icons.stars_rounded,
                      title: loc.translate('get_premium') ?? "JoinMe Premium",
                      content: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            loc.translate('premium_desc') ?? "Odblokuj wszystkie funkcje i usuń reklamy!",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 40),
                          const Icon(Icons.verified_user, color: Colors.amber, size: 100),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_currentStep == 0)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () => setState(() => _currentStep = 1),
                        child: Text(loc.translate('next').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    if (_currentStep == 1) ...[
                      TextButton(
                        onPressed: () => _finishOnboarding(false),
                        child: Text(loc.translate('later') ?? "PÓŹNIEJ", style: const TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () => _finishOnboarding(true),
                        child: Text(loc.translate('buy_now') ?? "KUP TERAZ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep({required IconData icon, required String title, required Widget content}) {
    return Column(
      children: [
        Icon(icon, size: 80, color: _currentStep == 1 ? Colors.amber : Colors.green),
        const SizedBox(height: 24),
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 30),
        Expanded(child: content),
      ],
    );
  }

  Widget _mapStyleOption(AppStateManager state, String style, String label) {
    bool isSelected = state.mapStyle == style;
    return GestureDetector(
      onTap: () => state.setMapStyle(style),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade800),
          borderRadius: BorderRadius.circular(15),
          color: isSelected ? Colors.green.withOpacity(0.1) : Colors.black.withOpacity(0.3),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.green : Colors.grey),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
