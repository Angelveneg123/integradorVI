import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/usuario_modelo.dart';

// Servicio de auditoría
class AuditoriaService {
  AuditoriaService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionAuditoria);

  // Eventos en tiempo real
  Stream<List<EventoAuditoria>> streamEventos({int limite = 200}) {
    return _coleccion
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((snap) => snap.docs.map(EventoAuditoria.fromDoc).toList());
  }

  // Eventos por rango de fechas
  Future<List<EventoAuditoria>> obtenerEventos({
    required DateTime desde,
    required DateTime hasta,
    String? modulo,
  }) async {
    Query<Map<String, dynamic>> query = _coleccion
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta));
    if (modulo != null && modulo.trim().isNotEmpty) {
      query = query.where('modulo', isEqualTo: modulo);
    }
    final snap = await query.orderBy('fecha', descending: true).get();
    return snap.docs.map(EventoAuditoria.fromDoc).toList();
  }

  // Nombre del usuario actual
  static String autorActual() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Usuario del sistema';
    final nombre = user.displayName?.trim() ?? '';
    if (nombre.isNotEmpty) return nombre;
    final correo = user.email ?? '';
    if (correo.isNotEmpty) return correo.split('@').first;
    return 'Usuario del sistema';
  }

  // Registrar evento sin lanzar error
  Future<void> registrarSeguro({
    required String modulo,
    required TipoEvento tipo,
    required String descripcion,
    required String idReferencia,
    String? titulo,
    List<ProductoMovimiento> productos = const [],
    List<CampoInfo> datosAdicionales = const [],
  }) async {
    try {
      await registrarEvento(
        titulo: titulo ?? modulo,
        tipo: tipo,
        descripcion: descripcion,
        autor: autorActual(),
        modulo: modulo,
        idReferencia: idReferencia,
        productos: productos,
        datosAdicionales: datosAdicionales,
      );
    } catch (e) {
      debugPrint('No se pudo registrar la auditoría de $modulo: $e');
    }
  }

  // Registrar ingreso
  Future<void> registrarIngreso({required String correo}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var autor = autorActual();
      final datos = <CampoInfo>[CampoInfo('Correo', correo)];

      final perfil =
          await _db.collection(kColeccionUsuarios).doc(user.uid).get();
      final data = perfil.data();
      if (data != null) {
        if ((data['estado'] ?? 'Activo') != 'Activo') return;
        final nombre = (data['nombre'] ?? '').toString().trim();
        if (nombre.isNotEmpty) autor = nombre;
        final rol = (data['rol'] ?? '').toString().trim();
        if (rol.isNotEmpty) datos.add(CampoInfo('Rol', rol));
        final sucursal = (data['sucursal'] ?? '').toString().trim();
        if (sucursal.isNotEmpty) datos.add(CampoInfo('Sucursal', sucursal));
      }

      await registrarEvento(
        titulo: 'Accesos',
        tipo: TipoEvento.ingresar,
        descripcion: 'Inicio de sesión',
        autor: autor,
        modulo: 'Accesos',
        idReferencia: user.uid,
        datosAdicionales: datos,
      );
    } catch (e) {
      debugPrint('No se pudo registrar el ingreso en la auditoría: $e');
    }
  }

  // Registrar evento
  Future<void> registrarEvento({
    required String titulo,
    required TipoEvento tipo,
    required String descripcion,
    required String autor,
    required String modulo,
    required String idReferencia,
    List<ProductoMovimiento> productos = const [],
    List<CampoInfo> datosAdicionales = const [],
  }) {
    final evento = EventoAuditoria(
      id: '',
      titulo: titulo,
      tipo: tipo,
      descripcion: descripcion,
      autor: autor,
      fecha: DateTime.now(),
      modulo: modulo,
      idReferencia: idReferencia,
      productos: productos,
      datosAdicionales: datosAdicionales,
    );
    return _coleccion.add(evento.toMap());
  }
}
