// Configure this app with FlutterFire before using Firebase.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Run flutterfire configure for this app with your own Firebase project.',
  );
}
