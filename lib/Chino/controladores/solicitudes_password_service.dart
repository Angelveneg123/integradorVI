import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auditoria_service.dart';
import '../modelos/evento_auditoria_modelo.dart';

// Colección de solicitudes
const String kColeccionSolicitudesPassword = 'solicitudes_password';

class SolicitudPassword {
  final String id;
  final String correo;
  final DateTime? creadaEn;

  const SolicitudPassword({
    required this.id,
    required this.correo,
    required this.creadaEn,
  });

  factory SolicitudPassword.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SolicitudPassword(
      id: doc.id,
      correo: (data['correo'] ?? doc.id) as String,
      creadaEn: (data['creadoEn'] as Timestamp?)?.toDate(),
    );
  }
}

// Servicio de solicitudes de contraseña
class SolicitudesPasswordService {
  SolicitudesPasswordService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionSolicitudesPassword);

  static String _idDe(String correo) =>
      correo.trim().toLowerCase().replaceAll('/', '_');

  String get _autor {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Usuario del sistema';
    final nombre = user.displayName?.trim() ?? '';
    if (nombre.isNotEmpty) return nombre;
    final correo = user.email ?? '';
    if (correo.isNotEmpty) return correo.split('@').first;
    return 'Usuario del sistema';
  }

  // Solicitar ayuda (desde el login)
  Future<void> solicitar(String correo) async {
    correo = correo.trim().toLowerCase();
    try {
      await _coleccion.doc(_idDe(correo)).set({
        'correo': correo,
        'estado': 'Pendiente',
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw StateError(switch (e.code) {
        'permission-denied' =>
          'No se pudo enviar la solicitud (revisa las reglas de Firestore).',
        'unavailable' => 'No hay conexión a Internet.',
        _ => 'No se pudo enviar la solicitud (${e.code}).',
      });
    }
  }

  // Solicitudes pendientes

  Stream<List<SolicitudPassword>> streamPendientes() {
    return _coleccion.snapshots().map((snap) {
      final lista = snap.docs.map(SolicitudPassword.fromDoc).toList();
      lista.sort((a, b) {
        final fa = a.creadaEn ?? DateTime.now();
        final fb = b.creadaEn ?? DateTime.now();
        return fb.compareTo(fa); // más recientes primero
      });
      return lista;
    });
  }

  Stream<int> streamCantidad() => _coleccion.snapshots().map((s) => s.size);

  // Enviar correo de restablecimiento
  Future<void> enviarCorreo(SolicitudPassword solicitud) async {
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: solicitud.correo);
    } on FirebaseAuthException catch (e) {
      throw StateError(switch (e.code) {
        'invalid-email' => 'El correo no es válido. Puedes descartar la solicitud.',
        'user-not-found' =>
          'Ese correo no tiene cuenta en Authentication. Puedes descartar la solicitud.',
        'too-many-requests' =>
          'Demasiados intentos. Espera unos minutos e inténtalo otra vez.',
        'network-request-failed' => 'No hay conexión a Internet.',
        _ => 'No se pudo enviar el correo (${e.code}).',
      });
    }

    await _coleccion.doc(solicitud.id).delete();
    await _registrarAuditoria(
      'Se envió correo para restablecer la contraseña (solicitud desde el login)',
      solicitud.correo,
    );
  }

  Future<void> descartar(SolicitudPassword solicitud) async {
    await _coleccion.doc(solicitud.id).delete();
    await _registrarAuditoria(
      'Se descartó una solicitud de restablecimiento de contraseña',
      solicitud.correo,
    );
  }

  // Registrar auditoría sin bloquear
  Future<void> _registrarAuditoria(String descripcion, String correo) async {
    try {
      await AuditoriaService().registrarEvento(
        titulo: 'Usuarios',
        tipo: TipoEvento.editar,
        descripcion: descripcion,
        autor: _autor,
        modulo: 'Usuarios',
        idReferencia: correo,
        datosAdicionales: [CampoInfo('Correo', correo)],
      );
    } catch (e) {
      debugPrint('No se pudo registrar la auditoría de la solicitud: $e');
    }
  }
}
