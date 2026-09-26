import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'lobby.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PanaderiaApp());
}

class PanaderiaApp extends StatelessWidget {
  const PanaderiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Panadería Romero',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF9F6EF),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          String nombre = 'Usuario';

          if (user.displayName != null &&
              user.displayName!.trim().isNotEmpty) {
            nombre = user.displayName!.trim();
          } else if (user.email != null) {
            nombre = user.email!.split('@').first;
          }

          return LobbyScreen(
            userName: nombre,
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _cargando = false;
  bool _ocultarPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrarMensaje(
        'Ingresa tu correo y contraseña.',
      );
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      String mensaje;

      switch (e.code) {
        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido.';
          break;

        case 'user-disabled':
          mensaje = 'Este usuario está deshabilitado.';
          break;

        case 'user-not-found':
          mensaje = 'No existe un usuario con ese correo.';
          break;

        case 'wrong-password':
          mensaje = 'La contraseña es incorrecta.';
          break;

        case 'invalid-credential':
          mensaje = 'Correo o contraseña incorrectos.';
          break;

        case 'too-many-requests':
          mensaje =
              'Demasiados intentos. Intenta nuevamente más tarde.';
          break;

        case 'network-request-failed':
          mensaje = 'No hay conexión a Internet.';
          break;

        default:
          mensaje = 'No se pudo iniciar sesión.';
      }

      _mostrarMensaje(mensaje);
    } catch (e) {
      _mostrarMensaje(
        'Ocurrió un error inesperado.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _recuperarPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _mostrarMensaje(
        'Escribe primero tu correo electrónico.',
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      _mostrarMensaje(
        'Se envió un correo para recuperar tu contraseña.',
      );
    } on FirebaseAuthException catch (e) {
      String mensaje;

      switch (e.code) {
        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido.';
          break;

        case 'user-not-found':
          mensaje = 'No existe un usuario con ese correo.';
          break;

        default:
          mensaje = 'No se pudo enviar el correo.';
      }

      _mostrarMensaje(mensaje);
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color textoOscuro = Color(0xFF5A3E36);
    const Color textoClaro = Color(0xFF7A6B65);
    const Color colorBoton = Color(0xFFA65021);
    const Color colorBorde = Color(0xFFE8DFD8);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 30,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/romero.jpeg',
                    height: 110,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Icon(
                        Icons.bakery_dining,
                        size: 100,
                        color: colorBoton,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Panadería Romero',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textoOscuro,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Ingresar para continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textoClaro,
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Correo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textoOscuro,
                  ),
                ),

                const SizedBox(height: 6),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'correo@panaderiaromero.com',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                    ),
                    hintStyle: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFCFAF7),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: colorBorde,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: colorBoton,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Contraseña',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textoOscuro,
                  ),
                ),

                const SizedBox(height: 6),

                TextField(
                  controller: _passwordController,
                  obscureText: _ocultarPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_cargando) {
                      _iniciarSesion();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _ocultarPassword =
                              !_ocultarPassword;
                        });
                      },
                      icon: Icon(
                        _ocultarPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    hintStyle: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFCFAF7),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: colorBorde,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: colorBoton,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _cargando ? null : _iniciarSesion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorBoton,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          colorBoton.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _cargando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed:
                      _cargando ? null : _recuperarPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: textoClaro,
                  ),
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}