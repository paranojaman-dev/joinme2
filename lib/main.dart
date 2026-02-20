import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:joinme2/app_state_manager.dart';
import 'package:joinme2/firebase_options.dart';
import 'package:joinme2/screens/splash_screen.dart';
import 'package:joinme2/services/database_service.dart';
import 'package:joinme2/services/notification_service.dart';
import 'package:joinme2/utils/app_localizations.dart';
import 'package:provider/provider.dart';

// Adnotacja wymagana dla powiadomień w tle
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Inicjalizacja powiadomień
    await NotificationService.initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await DatabaseService().saveUserToken(user.uid);
    }
    
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppStateManager(),
      child: Consumer<AppStateManager>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'JoinMe',
            theme: ThemeData.dark().copyWith(
              primaryColor: Colors.green.shade700,
              scaffoldBackgroundColor: const Color(0xFF121212),
            ),
            debugShowCheckedModeBanner: false,
            locale: appState.locale,
            supportedLocales: const [
              Locale('pl'),
              Locale('en'),
              Locale('de'),
              Locale('fr'),
              Locale('es'),
              Locale('it'),
              Locale('zh'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
