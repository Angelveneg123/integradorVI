import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'auditoria_service.dart';
import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/usuario_modelo.dart';
import 'permisos_service.dart';

// CRUD de usuarios
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

 

  // Usuarios en vivo (sin eliminados)
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

  // Un usuario en vivo
  Stream<Usuario?> streamUsuario(String id) {
    return _coleccion.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final u = Usuario.fromDoc(doc);
      return u.estado == kEstadoEliminado ? null : u;
    });
  }

  

  // Crear usuario
  Future<String> crear({
    required String nombre,
    required String correo,
    required String password,
    required String telefono,
    required String rol,
    required String sucursal,
    required String estado,
  }) async {
    Permisos.instance.exigir(Permisos.instance.esAdmin, 'crear usuarios');
    nombre = nombre.trim();
    correo = correo.trim().toLowerCase();
    // Authentication valida si el correo ya existe

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

  // Actualizar usuario
  Future<void> actualizar({
    required Usuario original,
    required String nombre,
    required String telefono,
    required String rol,
    required String sucursal,
    required String estado,
  }) async {
    Permisos.instance.exigir(Permisos.instance.esAdmin, 'editar usuarios');
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
    Permisos.instance.exigir(Permisos.instance.esAdmin, 'cambiar el estado de usuarios');
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

  // Enviar enlace para cambiar la contraseña
  Future<void> enviarRestablecimientoPassword(Usuario usuario) async {
    Permisos.instance.exigir(Permisos.instance.esAdmin, 'restablecer contraseñas');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: usuario.correo);
    } on FirebaseAuthException catch (e) {
      throw StateError(switch (e.code) {
        'invalid-email' => 'El correo del usuario no es válido.',
        'user-not-found' =>
          'Ese correo no tiene cuenta en Authentication.',
        'too-many-requests' =>
          'Demasiados intentos. Espera unos minutos e inténtalo otra vez.',
        'network-request-failed' => 'No hay conexión a Internet.',
        _ => 'No se pudo enviar el correo (${e.code}).',
      });
    }

    await _registrarAuditoria(
      tipo: TipoEvento.editar,
      descripcion:
          'Se envió correo para restablecer la contraseña de "${usuario.nombre}"',
      usuario: usuario,
      detalle: 'Enviado a ${usuario.correo}',
    );
  }

  // Eliminar usuario (borrado lógico)
  Future<void> eliminar(Usuario usuario) async {
    Permisos.instance.exigir(Permisos.instance.esAdmin, 'eliminar usuarios');
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

  // Crear cuenta sin cerrar la sesión del admin
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
          'Ese correo ya tiene una cuenta en Authentication. Si es de un '
              'usuario eliminado, bórrala en la consola de Firebase o usa otro correo.',
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

  // Registrar auditoría sin bloquear
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