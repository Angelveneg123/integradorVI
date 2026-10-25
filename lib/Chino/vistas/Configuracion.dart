import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controladores/apariencia_service.dart';
import '../controladores/permisos_service.dart';
import '../controladores/solicitudes_password_service.dart';
import '../modelos/usuario_modelo.dart';
import 'SolicitudesPassword.dart';

const String kVersionApp = '1.0.0';

Color get _textoOscuro => Apariencia.instance.textoOscuro;
Color get _textoClaro => Apariencia.instance.textoClaro;
Color get _borde => Apariencia.instance.bordeSuave;

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final SolicitudesPasswordService _solicitudes = SolicitudesPasswordService();
  late final Stream<int> _cantidad = _solicitudes.streamCantidad();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _perfil = () {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection(kColeccionUsuarios)
        .doc(uid)
        .snapshots();
  }();

  Future<void> _guardar({
    String? modo,
    String? acento,
    String? fondo,
    String? texto,
  }) async {
    try {
      await Apariencia.instance
          .guardar(modo: modo, acento: acento, fondo: fondo, texto: texto);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo guardar la preferencia. Revisa las reglas de '
            'Firestore (preferencias). $e',
          ),
        ),
      );
    }
  }

  Future<void> _restablecer() async {
    try {
      await Apariencia.instance.restablecer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo restablecer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Apariencia.instance.superficie,
        foregroundColor: _textoOscuro,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: Apariencia.instance,
        builder: (context, _) {
          final ap = Apariencia.instance;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _tarjetaSesion(),
              _administracion(),

              const _Titulo('Apariencia'),
              _Tarjeta(
                hijos: [
                  const _Subtitulo('Modo de pantalla'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in kModos)
                        ChoiceChip(
                          avatar: Icon(o.icono, size: 18),
                          label: Text(o.nombre),
                          selected: ap.modoId == o.id,
                          onSelected: (_) => _guardar(modo: o.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _Subtitulo('Color de acento'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final o in kColoresAcento)
                        _Muestra(
                          opcion: o,
                          seleccionada: ap.acentoId == o.id,
                          onTap: () => _guardar(acento: o.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _Subtitulo('Color de fondo'),
                  if (ap.oscuro)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'En modo oscuro el fondo es automático.',
                        style: TextStyle(fontSize: 12, color: _textoClaro),
                      ),
                    ),
                  Opacity(
                    opacity: ap.oscuro ? 0.4 : 1,
                    child: IgnorePointer(
                      ignoring: ap.oscuro,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final o in kColoresFondo)
                            _Muestra(
                              opcion: o,
                              seleccionada: ap.fondoId == o.id,
                              onTap: () => _guardar(fondo: o.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _Subtitulo('Tamaño de letra'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in kTamanosTexto)
                        ChoiceChip(
                          label: Text(o.nombre),
                          selected: ap.textoId == o.id,
                          onSelected: (_) => _guardar(texto: o.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Así se verá el texto en toda la app.',
                    style: TextStyle(color: tema.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _restablecer,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Restablecer apariencia'),
                    ),
                  ),
                ],
              ),

              const _Titulo('Acerca de'),
              _Tarjeta(
                hijos: [
                  Text(
                    'Panadería Romero',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _textoOscuro,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Versión $kVersionApp',
                    style: TextStyle(color: _textoClaro),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Sistema de gestión de operaciones: ventas, productos, '
                    'inventario, usuarios, sucursales, reportes y auditoría.',
                    style: TextStyle(color: _textoClaro, fontSize: 13),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Hecho con Flutter, Firebase Authentication y Cloud '
                    'Firestore (base de datos NoSQL).',
                    style: TextStyle(color: _textoClaro, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  // Rol con el que se están aplicando los permisos
  String _rolAplicado() {
    final p = Permisos.instance;
    if (p.perfil == null) return 'Administrador (sin perfil en Firestore)';
    if (p.esAdmin) return 'Administrador';
    return p.esEncargado ? 'Encargado' : 'Vendedor';
  }

  // Datos de la sesión
  Widget _tarjetaSesion() {
    final user = FirebaseAuth.instance.currentUser;
    final perfil = _perfil;
    if (user == null || perfil == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: perfil,
      builder: (context, snap) {
        final data = snap.data?.data();
        final nombre = ((data?['nombre'] ?? '') as String).trim();
        final rol = (data?['rol'] ?? '') as String;
        final correo = user.email ?? '';
        final inicial = (nombre.isNotEmpty ? nombre : correo).isEmpty
            ? '?'
            : (nombre.isNotEmpty ? nombre : correo)[0].toUpperCase();

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _Tarjeta(
            hijos: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      inicial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre.isEmpty ? 'Mi sesión' : nombre,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _textoOscuro,
                          ),
                        ),
                        Text(
                          correo,
                          style: TextStyle(
                            color: _textoClaro,
                            fontSize: 13,
                          ),
                        ),
                        if (rol.isNotEmpty)
                          Text(
                            'Rol guardado: $rol',
                            style: TextStyle(
                              color: _textoClaro,
                              fontSize: 12,
                            ),
                          ),
                        // Rol que la app está aplicando
                        Text(
                          'Permisos aplicados: ${_rolAplicado()}',
                          style: TextStyle(
                            color: _textoClaro,
                            fontSize: 12,
                          ),
                        ),
                        if (Permisos.instance.error != null)
                          Text(
                            'No se pudo leer tu perfil: ${Permisos.instance.error}',
                            style: const TextStyle(
                              color: Color(0xFFB3261E),
                              fontSize: 12,
                            ),
                          ),
                        SelectableText(
                          'ID: ${user.uid}',
                          style: TextStyle(
                            color: _textoClaro,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Solo para administradores
  Widget _administracion() {
    final perfil = _perfil;
    if (perfil == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: perfil,
      builder: (context, snap) {
        final data = snap.data?.data();
        final esAdmin = data != null &&
            normalizarRol(data['rol']) == 'Administrador' &&
            (data['estado'] ?? 'Activo') == 'Activo';
        if (!esAdmin) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Titulo('Administración'),
            StreamBuilder<int>(
              stream: _cantidad,
              builder: (context, snapCant) {
                final n = snapCant.data ?? 0;
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Apariencia.instance.superficie,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _borde),
                  ),
                  child: ListTile(
                    leading: Badge(
                      isLabelVisible: n > 0,
                      label: Text('$n'),
                      child: const Icon(Icons.lock_reset),
                    ),
                    title: const Text('Solicitudes de contraseña'),
                    subtitle: Text(
                      n > 0
                          ? '$n pendiente(s) por atender'
                          : 'No hay solicitudes pendientes',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SolicitudesPasswordScreen(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _textoOscuro,
          ),
        ),
      );
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textoClaro,
          ),
        ),
      );
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.hijos});
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Apariencia.instance.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: hijos,
        ),
      );
}

class _Muestra extends StatelessWidget {
  const _Muestra({
    required this.opcion,
    required this.seleccionada,
    required this.onTap,
  });

  final OpcionColor opcion;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oscuro =
        ThemeData.estimateBrightnessForColor(opcion.color) == Brightness.dark;
    return Tooltip(
      message: opcion.nombre,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: opcion.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: seleccionada ? Colors.black87 : Colors.black26,
              width: seleccionada ? 2.5 : 1,
            ),
          ),
          child: seleccionada
              ? Icon(
                  Icons.check,
                  size: 20,
                  color: oscuro ? Colors.white : Colors.black87,
                )
              : null,
        ),
      ),
    );
  }
}