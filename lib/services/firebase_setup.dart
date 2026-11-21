import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../constants/firebase_config.dart';
import '../firebase_options.dart';

/// Build with `--dart-define=USE_FIREBASE_EMULATOR=true` to run against the
/// local Firebase Emulator Suite instead of the real project (integration
/// tests and CI). Off in every normal build.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Host the emulators listen on. `localhost` works for the iOS Simulator;
/// an Android emulator needs `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`.
const String _emulatorHost =
    String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

/// Project id the emulators run under. A `demo-` id can never reach a real
/// Firebase project, so emulator runs can't touch production data.
const String emulatorProjectId = 'demo-give-and-take';

Future<void> configureFirebase() async {
  // Already set up (e.g. a test re-attached to a running app): calling
  // initializeApp or the use*Emulator methods again would throw. In
  // emulator mode it must be the demo project, never the real one.
  if (Firebase.apps.isNotEmpty) {
    if (useFirebaseEmulator &&
        Firebase.app().options.projectId != emulatorProjectId) {
      throw StateError('Firebase is already set up for '
          '${Firebase.app().options.projectId}, not the emulator project.');
    }
    return;
  }
  if (!useFirebaseEmulator) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform.copyWith(
        projectId: emulatorProjectId,
        storageBucket: '$emulatorProjectId.appspot.com',
      ),
    );
  } on FirebaseException catch (e) {
    // iOS sets up the default app from GoogleService-Info.plist first. For
    // emulator runs that file must be the demo placeholder
    // (tool/e2e/placeholder_google_service_info.sh), never the real one.
    if (e.code != 'duplicate-app') rethrow;
    final projectId = Firebase.app().options.projectId;
    if (projectId != emulatorProjectId) {
      throw StateError('Emulator run with GoogleService-Info.plist for '
          '"$projectId". Use the placeholder: '
          'tool/e2e/placeholder_google_service_info.sh');
    }
  }
  // Ports match firebase.json "emulators".
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  appFunctions().useFunctionsEmulator(_emulatorHost, 5001);
  debugPrint('Firebase: using the local emulators on $_emulatorHost');
}
