import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// Configuración de Firebase por plataforma
class DefaultFirebaseOptions {
  // Opciones según la plataforma actual
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android
        return android;

      default:
        throw UnsupportedError(
          'Esta plataforma todavía no está configurada para Firebase.',
        );
    }
  }

  // Datos de Firebase para web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCGM1OMV2pW2-iTKO3v0eZhoRb6pylZLHA',
    authDomain: 'panaderia-romero.firebaseapp.com',
    databaseURL: 'https://panaderia-romero-default-rtdb.firebaseio.com',
    projectId: 'panaderia-romero',
    storageBucket: 'panaderia-romero.firebasestorage.app',
    messagingSenderId: '433448139971',
    appId: '1:433448139971:web:1f88d87e760de6ce757676',
  );

  // Datos de Firebase para Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCwKAXnrGaJK14MIvyXZP-Qq15UGM-24oA',
    projectId: 'panaderia-romero',
    storageBucket: 'panaderia-romero.firebasestorage.app',
    messagingSenderId: '433448139971',
    appId: '1:433448139971:android:b22c5af4d3a031a9757676',
  );
}