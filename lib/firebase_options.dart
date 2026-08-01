// Este archivo es un placeholder para el entorno de CI/CD.
// El archivo real con credenciales se genera localmente con FlutterFire CLI
// y está excluido del repositorio por seguridad (.gitignore).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'CI_PLACEHOLDER',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'taskai-app-placeholder',
    storageBucket: 'taskai-app-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'CI_PLACEHOLDER',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'taskai-app-placeholder',
    storageBucket: 'taskai-app-placeholder.appspot.com',
    iosBundleId: 'com.taskaiapp.taskAi',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'CI_PLACEHOLDER',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'taskai-app-placeholder',
    storageBucket: 'taskai-app-placeholder.appspot.com',
  );
}
