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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIZMnG2PqtUezF1suaINcDjLHtXZiqwZY',
    appId: '1:128684232267:web:852161d3f6bc3df63847ce',
    messagingSenderId: '128684232267',
    projectId: 'taskflow-c022a',
    authDomain: 'taskflow-c022a.firebaseapp.com',
    storageBucket: 'taskflow-c022a.firebasestorage.app',
    measurementId: 'G-Q62WF1GSSR',
  );
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAhLOkgMkDdzT0AQ4LrUtBPQgAB6_weQXM',
    appId: '1:128684232267:android:343b042b22f814a83847ce',
    messagingSenderId: '128684232267',
    projectId: 'taskflow-c022a',
    storageBucket: 'taskflow-c022a.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummyApiKey-Ios',
    appId: '1:1234567890:ios:1234567890',
    messagingSenderId: '1234567890',
    projectId: 'vehicle-booking-system-dummy',
    storageBucket: 'vehicle-booking-system-dummy.appspot.com',
    iosBundleId: 'com.example.vehicleBookingSystem',
  );
}
