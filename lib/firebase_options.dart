import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCaKFbl6UfrJByJC0DlXh1TJ4YNzEHS1ZM",
    appId: "1:489298115604:web:0512b96327fb9dab683b01",
    messagingSenderId: "489298115604",
    projectId: "joinme-app-9a6da",
    authDomain: "joinme-app-9a6da.firebaseapp.com",
    storageBucket: "joinme-app-9a6da.appspot.com",
    measurementId: "G-CGDG5RNRWH",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyCaKFbl6UfrJByJC0DlXh1TJ4YNzEHS1ZM",
    appId: "1:489298115604:android:PLACEHOLDER",
    messagingSenderId: "489298115604",
    projectId: "joinme-app-9a6da",
    storageBucket: "joinme-app-9a6da.appspot.com",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyCaKFbl6UfrJByJC0DlXh1TJ4YNzEHS1ZM",
    appId: "1:489298115604:ios:PLACEHOLDER",
    messagingSenderId: "489298115604",
    projectId: "joinme-app-9a6da",
    storageBucket: "joinme-app-9a6da.appspot.com",
    iosBundleId: 'com.joinme2.app',
  );
}
