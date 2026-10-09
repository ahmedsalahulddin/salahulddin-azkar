import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase project "salahulddin-azkar", used only for push messages (FCM).
/// These identify the app to Firebase; they are not secrets.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform =>
      switch (defaultTargetPlatform) {
        _ when kIsWeb => null,
        TargetPlatform.android => android,
        TargetPlatform.iOS => ios,
        _ => null,
      };

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDanTndmq7ALeI-CJ15K2llQZ-Md910V-8',
    appId: '1:735466012226:android:4bd8404aa04138039c77db',
    messagingSenderId: '735466012226',
    projectId: 'salahulddin-azkar',
    storageBucket: 'salahulddin-azkar.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyC3SSIaqAjwdx9NhtaPMuWyfM2KWTCqemQ',
    appId: '1:735466012226:ios:dd7b68ad041a0e439c77db',
    messagingSenderId: '735466012226',
    projectId: 'salahulddin-azkar',
    storageBucket: 'salahulddin-azkar.firebasestorage.app',
    iosBundleId: 'com.salahulddin.azkar',
  );
}
