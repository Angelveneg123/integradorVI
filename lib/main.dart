import 'package:flutter/material.dart';

void main() {
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
        // Color de fondo crema claro inspirado en la imagen
        scaffoldBackgroundColor: const Color(0xFFF9F6EF), 
        fontFamily: 'Roboto', // Puedes cambiarlo por la fuente que prefieras
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos los colores principales para reutilizarlos
    const Color textoOscuro = Color(0xFF5A3E36);
    const Color textoClaro = Color(0xFF7A6B65);
    const Color colorBoton = Color(0xFFA65021);
    const Color colorBorde = Color(0xFFE8DFD8);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Logo
              Center(
                child: Image.asset(
                  'assets/images/romero.jpeg', // Asegúrate de agregar tu imagen real en pubspec.yaml
                  height: 110,
                  // Fallback en caso de que no tengas la imagen configurada aún
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.bakery_dining,
                    size: 100,
                    color: colorBoton,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Título Principal
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

              // 3. Subtítulo
              const Text(
                'Ingresar para continuar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textoClaro,
                ),
              ),
              const SizedBox(height: 40),

              // 4. Etiqueta Correo
              const Text(
                'Correo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textoOscuro,
                ),
              ),
              const SizedBox(height: 6),

              // 5. Input de Correo
              TextField(
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'juan@panaderiaromero.com',
                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: const Color(0xFFFCFAF7),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: colorBorde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: colorBoton),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 6. Etiqueta Contraseña
              const Text(
                'Contraseña',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textoOscuro,
                ),
              ),
              const SizedBox(height: 6),

              // 7. Input de Contraseña
              TextField(
                obscureText: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: const Color(0xFFFCFAF7),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: colorBorde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: colorBoton),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 8. Botón Iniciar Sesión
              ElevatedButton(
                onPressed: () {
                  // Acción al presionar iniciar sesión
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorBoton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Iniciar sesión',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 9. Enlace de contraseña olvidada
              TextButton(
                onPressed: () {
                  // Acción de recuperar contraseña
                },
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
    );
  }
}