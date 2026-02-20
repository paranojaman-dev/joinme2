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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-2.0, 0.0), 
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // POPRAWKA: Curves.easeOutBack zamiast Curves.backOut
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _navigateToNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _navigateToNext() async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    while (!appState.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                    ],
                  ),
                  child: const Icon(Icons.chair, color: Colors.white, size: 70),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'JoinMe',
              style: TextStyle(color: AppColors.textColor, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
