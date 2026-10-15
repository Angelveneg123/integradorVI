import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controladores/solicitudes_password_service.dart';
import '../controladores/usuarios_service.dart';
import '../modelos/usuario_modelo.dart';
import '../controladores/permisos_service.dart';

const Color _colorAcento = Color(0xFFA65021);
const Color _fondo = Color(0xFFFAF6EE);
const Color _textoOscuro = Color(0xFF5A3E36);
const Color _textoClaro = Color(0xFF7A6B65);
const Color _rojo = Color(0xFF8D141B);

// Campana de solicitudes
class CampanaSolicitudes extends StatefulWidget {
  const CampanaSolicitudes({super.key, this.iconSize = 24, this.constraints});

  final double iconSize;
  final BoxConstraints? constraints;

  @override
  State<CampanaSolicitudes> createState() => _CampanaSolicitudesState();
}

class _CampanaSolicitudesState extends State<CampanaSolicitudes> {
  final SolicitudesPasswordService _service = SolicitudesPasswordService();
  late final Stream<int> _cantidad = _service.streamCantidad();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _perfil = () {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection(kColeccionUsuarios)
        .doc(uid)
        .snapshots();
  }();

  Widget get _campanaSimple => IconButton(
        onPressed: () {},
        constraints: widget.constraints,
        icon: Icon(Icons.notifications_none_rounded, size: widget.iconSize),
      );

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;
    if (perfil == null) return _campanaSimple;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: perfil,
      builder: (context, snapPerfil) {
        final data = snapPerfil.data?.data();
        final esAdmin = data != null &&
            data['rol'] == 'Administrador' &&
            (data['estado'] ?? 'Activo') == 'Activo';
        if (!esAdmin) return _campanaSimple;

        return StreamBuilder<int>(
          stream: _cantidad,
          builder: (context, snapCant) {
            final n = snapCant.data ?? 0;
            return IconButton(
              tooltip: n > 0
                  ? '$n solicitud(es) de contraseña pendiente(s)'
                  : 'Solicitudes de contraseña',
              constraints: widget.constraints,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SolicitudesPasswordScreen(),
                ),
              ),
              icon: Badge(
                isLabelVisible: n > 0,
                label: Text('$n'),
                child: Icon(
                  n > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: widget.iconSize,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Lista de solicitudes
class SolicitudesPasswordScreen extends StatefulWidget {
  const SolicitudesPasswordScreen({super.key});

  @override
  State<SolicitudesPasswordScreen> createState() =>
      _SolicitudesPasswordScreenState();
}

class _SolicitudesPasswordScreenState extends State<SolicitudesPasswordScreen> {
  final SolicitudesPasswordService _service = SolicitudesPasswordService();
  late final Stream<List<SolicitudPassword>> _solicitudes =
      _service.streamPendientes();
  late final Stream<List<Usuario>> _usuarios = UsuariosService().streamUsuarios();
  final Set<String> _procesando = {};

  String _mensajeError(Object e) =>
      e.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');

  Future<void> _ejecutar(
    SolicitudPassword s,
    Future<void> Function() accion,
    String exito,
  ) async {
    setState(() => _procesando.add(s.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await accion();
      messenger.showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_mensajeError(e))));
    } finally {
      if (mounted) setState(() => _procesando.remove(s.id));
    }
  }

  Future<void> _enviar(SolicitudPassword s) => _ejecutar(
        s,
        () => _service.enviarCorreo(s),
        'Correo enviado a ${s.correo}.',
      );

  Future<void> _descartar(SolicitudPassword s) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar solicitud'),
        content: Text('¿Descartar la solicitud de ${s.correo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar', style: TextStyle(color: _rojo)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _ejecutar(s, () => _service.descartar(s), 'Solicitud descartada.');
  }

  @override
  Widget build(BuildContext context) {
    // Solo admin
    if (!Permisos.instance.esAdmin) {
      return const AccesoRestringido(modulo: 'Las solicitudes de contraseña');
    }
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Solicitudes de contraseña'),
        backgroundColor: Colors.white,
        foregroundColor: _textoOscuro,
        elevation: 0,
      ),
      body: StreamBuilder<List<SolicitudPassword>>(
        stream: _solicitudes,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Mensaje(
              icono: Icons.error_outline,
              texto: 'Error al leer las solicitudes: ${snap.error}',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const _Mensaje(
              icono: Icons.mark_email_read_outlined,
              texto: 'No hay solicitudes pendientes.',
            );
          }

          return StreamBuilder<List<Usuario>>(
            stream: _usuarios,
            builder: (context, snapUsuarios) {
              final usuarios = snapUsuarios.data ?? const <Usuario>[];
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final s = lista[i];
                  final coincidencias = usuarios.where(
                    (u) =>
                        u.correo.trim().toLowerCase() == s.correo.toLowerCase(),
                  );
                  final usuario = coincidencias.isEmpty ? null : coincidencias.first;
                  return _TarjetaSolicitud(
                    solicitud: s,
                    usuario: usuario,
                    // Espera a que carguen los usuarios
                    verificado: snapUsuarios.hasData,
                    procesando: _procesando.contains(s.id),
                    onEnviar: () => _enviar(s),
                    onDescartar: () => _descartar(s),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud({
    required this.solicitud,
    required this.usuario,
    required this.verificado,
    required this.procesando,
    required this.onEnviar,
    required this.onDescartar,
  });

  final SolicitudPassword solicitud;
  final Usuario? usuario;
  final bool verificado;
  final bool procesando;
  final VoidCallback onEnviar;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final fecha = solicitud.creadaEn == null
        ? 'Hace un momento'
        : DateFormat('dd/MM/yyyy HH:mm').format(solicitud.creadaEn!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEE7E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            solicitud.correo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textoOscuro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Solicitada: $fecha',
            style: const TextStyle(fontSize: 12, color: _textoClaro),
          ),
          const SizedBox(height: 8),
          if (usuario != null)
            Text(
              'Usuario: ${usuario!.nombre} (${usuario!.rol})',
              style: const TextStyle(fontSize: 12, color: _textoOscuro),
            )
          else if (verificado)
            const Text(
              'Ningún usuario registrado tiene este correo.',
              style: TextStyle(fontSize: 12, color: _rojo),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: procesando ? null : onEnviar,
                  icon: procesando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Enviar correo'),
                  style: FilledButton.styleFrom(backgroundColor: _colorAcento),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: procesando ? null : onDescartar,
                child: const Text('Descartar', style: TextStyle(color: _rojo)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: _textoClaro),
            const SizedBox(height: 10),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textoClaro),
            ),
          ],
        ),
      ),
    );
  }
}
