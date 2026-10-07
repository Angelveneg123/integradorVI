import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'auditoria_service.dart';
import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/usuario_modelo.dart';

/// CRUD de usuarios: el perfil va a Firestore (`usuarios`) y la cuenta de
/// acceso a Firebase Authentication.
///
/// Limitaciones (plan gratuito, sin servidor/Admin SDK):
/// * Crear la cuenta se hace con una segunda instancia de Firebase, para que
///   la sesión del administrador no se cierre.
/// * Desde la app no se puede borrar ni editar el correo de una cuenta de
///   Authentication. Por eso "Eliminar" es un borrado lógico (estado
///   'Eliminado'): desaparece de la lista y el login lo bloquea.
class UsuariosService {
  UsuariosService({
    FirebaseFirestore? firestore,
    AuditoriaService? auditoriaService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auditoria = auditoriaService ?? AuditoriaService(firestore: firestore);

  final FirebaseFirestore _db;
  final AuditoriaService _auditoria;

  static const String _modulo = 'Usuarios';
  static const String _nombreAppSecundaria = 'creadorDeUsuarios';

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionUsuarios);

  String? get uidActual => FirebaseAuth.instance.currentUser?.uid;

  String get _autor {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Usuario del sistema';
    final nombre = user.displayName?.trim() ?? '';
    if (nombre.isNotEmpty) return nombre;
    final correo = user.email ?? '';
    if (correo.isNotEmpty) return correo.split('@').first;
    return 'Usuario del sistema';
  }

  // ---------------------------------------------------------------- Lectura

  /// Usuarios no eliminados, ordenados por nombre.
  Stream<List<Usuario>> streamUsuarios() {
    return _coleccion.snapshots().map((snap) {
      final lista = snap.docs
          .map(Usuario.fromDoc)
          .where((u) => u.estado != kEstadoEliminado)
          .toList();
      lista.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
      return lista;
    });
  }

  /// Un usuario en tiempo real. Emite `null` si no existe o fue eliminado.
  Stream<Usuario?> streamUsuario(String id) {
    return _coleccion.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final u = Usuario.fromDoc(doc);
      return u.estado == kEstadoEliminado ? null : u;
    });
  }

  // ---------------------------------------------------------------- Escritura

  /// Crea la cuenta en Authentication y su perfil en Firestore.
  Future<String> crear({
    required String nombre,
    required String correo,
    required String password,
    required String telefono,
    required String rol,
    required String sucursal,
    required String estado,
  }) async {
    nombre = nombre.trim();
    correo = correo.trim().toLowerCase();
    await _validarCorreoLibre(correo);

    final uid = await _crearCuentaAuth(
      nombre: nombre,
      correo: correo,
      password: password,
    );

    final codigo = await _siguienteCodigo();
    final nuevo = Usuario(
      id: uid,
      codigo: codigo,
      nombre: nombre,
      correo: correo,
      telefono: telefono.trim(),
      rol: rol,
      sucursal: sucursal,
      estado: estado,
    );

    try {
      await _coleccion.doc(uid).set({
        ...nuevo.toMap(),
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw StateError(
        'La cuenta se creó en Authentication pero no se pudo guardar el '
        'perfil ($e). Revisa las reglas de Firestore.',
      );
    }

    await _registrarAuditoria(
      tipo: TipoEvento.crear,
      descripcion: 'Se registró al usuario "$nombre"',
      usuario: nuevo,
    );
    return uid;
  }

  /// Guarda los cambios del perfil. El correo no se puede cambiar desde la
  /// app (está ligado a la cuenta de Authentication).
  Future<void> actualizar({
    required Usuario original,
    required String nombre,
    required String telefono,
    required String rol,
    required String sucursal,
    required String estado,
  }) async {
    if (original.id == uidActual && estado != 'Activo') {
      throw StateError('No puedes desactivar tu propia cuenta.');
    }

    final editado = Usuario(
      id: original.id,
      codigo: original.codigo,
      nombre: nombre.trim(),
      correo: original.correo,
      telefono: telefono.trim(),
      rol: rol,
      sucursal: sucursal,
      estado: estado,
    );
    await _coleccion.doc(original.id).update(editado.toMap());

    await _registrarAuditoria(
      tipo: TipoEvento.editar,
      descripcion: 'Se editó al usuario "${original.nombre}"',
      usuario: editado,
    );
  }

  Future<void> cambiarEstado(Usuario usuario, String nuevoEstado) async {
    if (usuario.id == uidActual && nuevoEstado != 'Activo') {
      throw StateError('No puedes desactivar tu propia cuenta.');
    }

    await _coleccion.doc(usuario.id).update({
      'estado': nuevoEstado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    await _registrarAuditoria(
      tipo: TipoEvento.editar,
      descripcion:
          '${nuevoEstado == 'Activo' ? 'Se activó' : 'Se desactivó'} al usuario "${usuario.nombre}"',
      usuario: usuario,
      detalle: 'Estado: ${usuario.estado} → $nuevoEstado',
    );
  }

  /// Borrado lógico (ver nota de la clase).
  Future<void> eliminar(Usuario usuario) async {
    if (usuario.id == uidActual) {
      throw StateError('No puedes eliminar tu propia cuenta.');
    }

    await _coleccion.doc(usuario.id).update({
      'estado': kEstadoEliminado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    await _registrarAuditoria(
      tipo: TipoEvento.eliminar,
      descripcion: 'Se eliminó al usuario "${usuario.nombre}"',
      usuario: usuario,
    );
  }

  // ---------------------------------------------------------------- Helpers

  /// Crea la cuenta en una segunda instancia de Firebase para no cerrar la
  /// sesión del administrador. Devuelve el uid de la cuenta nueva.
  Future<String> _crearCuentaAuth({
    required String nombre,
    required String correo,
    required String password,
  }) async {
    FirebaseApp app;
    try {
      app = Firebase.app(_nombreAppSecundaria);
    } catch (_) {
      app = await Firebase.initializeApp(
        name: _nombreAppSecundaria,
        options: Firebase.app().options,
      );
    }

    final auth = FirebaseAuth.instanceFor(app: app);
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: correo,
        password: password,
      );
      await cred.user?.updateDisplayName(nombre);
      final uid = cred.user?.uid;
      if (uid == null) {
        throw StateError('No se pudo crear la cuenta.');
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      throw StateError(switch (e.code) {
        'email-already-in-use' =>
          'Ese correo ya tiene una cuenta. Si el usuario fue eliminado, '
              'usa otro correo.',
        'invalid-email' => 'El correo electrónico no es válido.',
        'weak-password' => 'La contraseña es muy débil (mínimo 6 caracteres).',
        'network-request-failed' => 'No hay conexión a Internet.',
        _ => 'No se pudo crear la cuenta (${e.code}).',
      });
    } finally {
      await auth.signOut();
    }
  }

  Future<String> _siguienteCodigo() async {
    final snap = await _coleccion.get();
    var maximo = 0;
    for (final doc in snap.docs) {
      final codigo = (doc.data()['codigo'] ?? '') as String;
      final numero = int.tryParse(codigo.replaceAll(RegExp(r'[^0-9]'), ''));
      if (numero != null && numero > maximo) maximo = numero;
    }
    return 'U${(maximo + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _validarCorreoLibre(String correo) async {
    final snap = await _coleccion.get();
    final repetido = snap.docs.any(
      (d) =>
          ((d.data()['correo'] ?? '') as String).trim().toLowerCase() == correo,
    );
    if (repetido) {
      throw StateError('Ya existe un usuario con el correo "$correo".');
    }
  }

  /// La auditoría nunca debe impedir que la operación principal termine.
  Future<void> _registrarAuditoria({
    required TipoEvento tipo,
    required String descripcion,
    required Usuario usuario,
    String? detalle,
  }) async {
    try {
      await _auditoria.registrarEvento(
        titulo: _modulo,
        tipo: tipo,
        descripcion: descripcion,
        autor: _autor,
        modulo: _modulo,
        idReferencia: usuario.codigo,
        datosAdicionales: [
          CampoInfo('Usuario', usuario.nombre),
          CampoInfo('Rol', usuario.rol),
          CampoInfo('Sucursal', usuario.sucursal),
          if (detalle != null) CampoInfo('Detalle', detalle),
        ],
      );
    } catch (e) {
      debugPrint('No se pudo registrar la auditoría de usuarios: $e');
    }
  }
}