import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:joinme2/screens/auth_screen.dart';
import 'package:joinme2/screens/main_screen.dart';
import 'package:joinme2/screens/onboarding_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }
        
        final user = authSnapshot.data;
        
        // 1. Jeśli nikt nie jest zalogowany -> Ekran Logowania
        if (user == null) return const AuthScreen();

        // 2. Jeśli zalogowany, ale mail niezweryfikowany -> Ekran Czekania (wewnątrz AuthScreen)
        if (!user.emailVerified) return const AuthScreen();

        // 3. Jeśli mail zweryfikowany, sprawdź dokument w Firestore
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
            }

            // Jeśli dokument nie istnieje -> Wyloguj (bo to zombie konto po usunięciu)
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // Używamy microtask, aby nie zmieniać stanu podczas budowania widgetu
              Future.microtask(() => FirebaseAuth.instance.signOut());
              return const AuthScreen();
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const AuthScreen();

            // 4. Sprawdź czy ukończono ustawienia mapy i premium
            final bool hasCompletedOnboarding = data['hasCompletedOnboarding'] ?? false;

            if (!hasCompletedOnboarding) {
              return const OnboardingScreen();
            }

            // 5. Wszystko gotowe -> Mapa główna
            return const MainScreen();
          },
        );
      },
    );
  }
}
