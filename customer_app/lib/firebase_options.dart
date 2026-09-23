import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Per-platform Firebase config for the `osteq-5e0fb` project, generated from
/// `firebase apps:sdkconfig` (Android/iOS each have their own apiKey and appId
/// — these are public client identifiers, meant to ship inside the app binary,
/// not secrets). Mirrors the file `flutterfire configure` would generate.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions have not been configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform: $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBe5wYCoQ7D0dlp94S4rZU1iBxJHsP3sIQ',
    appId: '1:104392907805:android:a5c5f3fe8b255aee4efaf4',
    messagingSenderId: '104392907805',
    projectId: 'osteq-5e0fb',
    storageBucket: 'osteq-5e0fb.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDqPRYHh6HcgAjxhDiYe8mbOyDG6sIBgs4',
    appId: '1:104392907805:ios:6b22ddb7c157f2014efaf4',
    messagingSenderId: '104392907805',
    projectId: 'osteq-5e0fb',
    storageBucket: 'osteq-5e0fb.firebasestorage.app',
    iosBundleId: 'com.osteq.customerApp',
  );
}
