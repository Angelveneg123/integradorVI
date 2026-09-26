# Firebase listo para conectar

Este proyecto ya tiene el flujo Login -> Lobby. Para activar Firebase Auth + Firestore:

1. En Firebase Console crea/selecciona el proyecto y registra Android y Web.
2. En la raíz del proyecto ejecuta:
   flutter pub add firebase_core firebase_auth cloud_firestore
   dart pub global activate flutterfire_cli
   flutterfire configure
3. El comando genera `lib/firebase_options.dart` y configura las plataformas.
4. Inicializa Firebase en `main.dart` antes de `runApp`:
   WidgetsFlutterBinding.ensureInitialized();
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
5. Sustituye el botón de login por `FirebaseAuth.instance.signInWithEmailAndPassword(...)`.
6. Usa colecciones sugeridas: `usuarios`, `productos`, `ventas`, `inventario`, `sucursales`, `auditoria`.

No se incluyen claves inventadas: `flutterfire configure` coloca las credenciales reales del proyecto Firebase elegido.
