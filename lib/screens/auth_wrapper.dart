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
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }
        
        final user = authSnapshot.data;
        
        // 1. Nikt niezalogowany -> Ekran logowania
        if (user == null) return const AuthScreen();

        // 2. Zalogowany, ale brak weryfikacji maila -> Ekran logowania (tryb czekania)
        if (!user.emailVerified) return const AuthScreen();

        // 3. Sprawdzamy dokument w Firestore
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
            }

            // KRYTYCZNA POPRAWKA BEZPIECZEŃSTWA: 
            // Jeśli jesteś w Auth, ale NIE MASZ dokumentu w Firestore (np. po usunięciu konta)
            // musimy Cię wylogować całkowicie, abyś nie utknął w pętli.
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              Future.microtask(() => FirebaseAuth.instance.signOut());
              return const AuthScreen();
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) {
              Future.microtask(() => FirebaseAuth.instance.signOut());
              return const AuthScreen();
            }

            // 4. Sprawdzamy czy użytkownik ukończył onboarding
            final bool hasCompletedOnboarding = data['hasCompletedOnboarding'] ?? false;
            final bool hasProfile = (data['firstName'] != null && data['firstName'].toString().isNotEmpty);

            if (!hasCompletedOnboarding || !hasProfile) {
              return const OnboardingScreen();
            }

            // 5. Wszystko OK -> Mapa
            return const MainScreen();
          },
        );
      },
    );
  }
}
