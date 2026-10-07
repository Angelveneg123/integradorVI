import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auditoria_service.dart';
import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/materia_prima_modelo.dart';

/// CRUD de la colección `materia_prima` en Firestore.
///
/// Cada operación (crear / editar / eliminar / activar-desactivar) deja un
/// registro en la bitácora `auditoria`, igual que hace [StockService], para
/// que el módulo de Auditoría lo muestre.
class MateriaPrimaService {
  MateriaPrimaService({
    FirebaseFirestore? firestore,
    AuditoriaService? auditoriaService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auditoria = auditoriaService ?? AuditoriaService(firestore: firestore);

  final FirebaseFirestore _db;
  final AuditoriaService _auditoria;

  static const String _modulo = 'Materia Prima';

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionMateriaPrima);

  /// Nombre del usuario autenticado, para la bitácora de auditoría.
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

  /// Stream en tiempo real de todas las materias primas, ordenadas por nombre.
  Stream<List<MateriaPrima>> streamMateriasPrimas() {
    return _coleccion.orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(MateriaPrima.fromDoc).toList(),
        );
  }

  /// Stream en tiempo real de una sola materia prima (pantalla de detalle).
  /// Emite `null` si el documento fue eliminado.
  Stream<MateriaPrima?> streamMateriaPrima(String id) {
    return _coleccion.doc(id).snapshots().map(
          (doc) => doc.exists ? MateriaPrima.fromDoc(doc) : null,
        );
  }

  // ---------------------------------------------------------------- Escritura

  /// Crea una materia prima con código autogenerado (M001, M002, ...).
  /// Devuelve el código asignado.
  Future<String> crear({
    required String nombre,
    required double cantidad,
    required String unidadMedida,
    required String sucursal,
    required String estado,
  }) async {
    nombre = nombre.trim();
    await _validarDuplicado(nombre: nombre, sucursal: sucursal);

    final codigo = await _siguienteCodigo();
    final ref = _coleccion.doc(codigo);
    final nueva = MateriaPrima(
      id: codigo,
      codigo: codigo,
      nombre: nombre,
      cantidad: cantidad,
      unidadMedida: unidadMedida,
      sucursal: sucursal,
      estado: estado,
    );

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw StateError('El código $codigo ya existe. Intenta de nuevo.');
      }
      tx.set(ref, nueva.toMap());
    });

    await _registrarAuditoria(
      tipo: TipoEvento.crear,
      descripcion: 'Se registró la materia prima "$nombre"',
      materia: nueva,
    );
    return codigo;
  }

  /// Guarda los cambios de una materia prima existente.
  Future<void> actualizar({
    required MateriaPrima original,
    required String nombre,
    required double cantidad,
    required String unidadMedida,
    required String sucursal,
    required String estado,
  }) async {
    nombre = nombre.trim();
    await _validarDuplicado(
      nombre: nombre,
      sucursal: sucursal,
      excluirId: original.id,
    );

    final editada = MateriaPrima(
      id: original.id,
      codigo: original.codigo,
      nombre: nombre,
      cantidad: cantidad,
      unidadMedida: unidadMedida,
      sucursal: sucursal,
      estado: estado,
    );

    await _coleccion.doc(original.id).update(editada.toMap());

    await _registrarAuditoria(
      tipo: TipoEvento.editar,
      descripcion: 'Se editó la materia prima "${original.nombre}"',
      materia: editada,
      detalle:
          'Cantidad: ${original.cantidadConUnidad} → ${editada.cantidadConUnidad}',
    );
  }

  /// Activa o desactiva una materia prima.
  Future<void> cambiarEstado(MateriaPrima materia, String nuevoEstado) async {
    await _coleccion.doc(materia.id).update({
      'estado': nuevoEstado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    await _registrarAuditoria(
      tipo: TipoEvento.editar,
      descripcion:
          '${nuevoEstado == 'Activo' ? 'Se activó' : 'Se desactivó'} la materia prima "${materia.nombre}"',
      materia: materia,
      detalle: 'Estado: ${materia.estado} → $nuevoEstado',
    );
  }

  /// Elimina definitivamente una materia prima.
  Future<void> eliminar(MateriaPrima materia) async {
    await _coleccion.doc(materia.id).delete();

    await _registrarAuditoria(
      tipo: TipoEvento.eliminar,
      descripcion: 'Se eliminó la materia prima "${materia.nombre}"',
      materia: materia,
    );
  }

  // ---------------------------------------------------------------- Helpers

  /// Calcula el siguiente código libre: M001, M002, ...
  Future<String> _siguienteCodigo() async {
    final snap = await _coleccion.get();
    var maximo = 0;
    for (final doc in snap.docs) {
      final numero = int.tryParse(doc.id.replaceAll(RegExp(r'[^0-9]'), ''));
      if (numero != null && numero > maximo) maximo = numero;
    }
    return 'M${(maximo + 1).toString().padLeft(3, '0')}';
  }

  /// No permite dos materias primas con el mismo nombre en la misma sucursal.
  Future<void> _validarDuplicado({
    required String nombre,
    required String sucursal,
    String? excluirId,
  }) async {
    final snap = await _coleccion.where('sucursal', isEqualTo: sucursal).get();
    final repetido = snap.docs.any(
      (d) =>
          d.id != excluirId &&
          ((d.data()['nombre'] ?? '') as String).trim().toLowerCase() ==
              nombre.toLowerCase(),
    );
    if (repetido) {
      throw StateError('Ya existe "$nombre" en la sucursal $sucursal.');
    }
  }

  /// La auditoría nunca debe impedir que la operación principal termine.
  Future<void> _registrarAuditoria({
    required TipoEvento tipo,
    required String descripcion,
    required MateriaPrima materia,
    String? detalle,
  }) async {
    try {
      await _auditoria.registrarEvento(
        titulo: _modulo,
        tipo: tipo,
        descripcion: descripcion,
        autor: _autor,
        modulo: _modulo,
        idReferencia: materia.codigo,
        productos: [
          ProductoMovimiento(
            nombre: materia.nombre,
            cantidad: materia.cantidad.round(),
            detalle: detalle,
          ),
        ],
        datosAdicionales: [
          CampoInfo('Sucursal', materia.sucursal),
          CampoInfo('Unidad de medida', materia.unidadMedida),
          CampoInfo('Estado', materia.estado),
        ],
      );
    } catch (e) {
      debugPrint('No se pudo registrar la auditoría de materia prima: $e');
    }
  }
}
