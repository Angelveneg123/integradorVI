import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auditoria_service.dart';
import '../../Henry/controladores/codigos_sucursal.dart';
import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/materia_prima_modelo.dart';
import 'permisos_service.dart';

class MateriaPrimaService {
  MateriaPrimaService({
    FirebaseFirestore? firestore,
    AuditoriaService? auditoriaService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auditoria = auditoriaService ?? AuditoriaService(firestore: firestore);

// Conexión a Firestore
  final FirebaseFirestore _db;

  final AuditoriaService _auditoria;

// Módulo para la auditoría
  static const String _modulo = 'Ingredientes';

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionMateriaPrima);

  // Autor para la auditoría
  String get _autor {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Usuario del sistema';
    final nombre = user.displayName?.trim() ?? '';
    if (nombre.isNotEmpty) return nombre;
    final correo = user.email ?? '';
    if (correo.isNotEmpty) return correo.split('@').first;
    return 'Usuario del sistema';
  }

 

  // Materias primas en vivo
  Stream<List<MateriaPrima>> streamMateriasPrimas() {
    return _coleccion.orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(MateriaPrima.fromDoc).toList(),
        );
  }

  // Una materia prima en vivo
  Stream<MateriaPrima?> streamMateriaPrima(String id) {
    return _coleccion.doc(id).snapshots().map(
          (doc) => doc.exists ? MateriaPrima.fromDoc(doc) : null,
        );
  }



  // Crear materia prima
  Future<String> crear({
    required String nombre,
    required double cantidad,
    required String unidadMedida,
    required String sucursal,
    required String estado,
  }) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarIngredientes, 'crear ingredientes');
    nombre = nombre.trim();
    await _validarDuplicado(nombre: nombre, sucursal: sucursal);

    final codigo = await _siguienteCodigo(sucursal);
    // Referencia al documento
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
      tx.set(ref, {
        ...nueva.toMap(),
        'creadoEn': FieldValue.serverTimestamp(),
      });
    });

    await _registrarAuditoria(
      tipo: TipoEvento.crear,
      descripcion: 'Se registró el ingrediente "$nombre"',
      materia: nueva,
    );
    return codigo;
  }

  // Actualizar materia prima
  Future<void> actualizar({
    required MateriaPrima original,
    required String nombre,
    required double cantidad,
    required String unidadMedida,
    required String sucursal,
    required String estado,
  }) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarIngredientes, 'editar ingredientes');
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
      descripcion: 'Se editó el ingrediente "${original.nombre}"',
      materia: editada,
      detalle:
          'Cantidad: ${original.cantidadConUnidad} → ${editada.cantidadConUnidad}',
    );
  }

  // Activar o desactivar
  Future<void> cambiarEstado(MateriaPrima materia, String nuevoEstado) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarIngredientes, 'cambiar el estado de ingredientes');
    await _coleccion.doc(materia.id).update({
      'estado': nuevoEstado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    await _registrarAuditoria(
      tipo: TipoEvento.editar,
      descripcion:
          '${nuevoEstado == 'Activo' ? 'Se activó' : 'Se desactivó'} el ingrediente "${materia.nombre}"',
      materia: materia,
      detalle: 'Estado: ${materia.estado} → $nuevoEstado',
    );
  }

  // Eliminar materia prima
  Future<void> eliminar(MateriaPrima materia) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarIngredientes, 'eliminar ingredientes');
    await _coleccion.doc(materia.id).delete();

    await _registrarAuditoria(
      tipo: TipoEvento.eliminar,
      descripcion: 'Se eliminó el ingrediente "${materia.nombre}"',
      materia: materia,
    );
  }


  // Siguiente código libre con el prefijo de la sucursal (N001, S001...).
  // El código es también el id del documento.
  Future<String> _siguienteCodigo(String sucursal) async {
    final prefijo = await CodigosSucursal.prefijoDe(_db, sucursal) ?? 'M';
    return CodigosSucursal.reservar(
      db: _db,
      coleccion: kColeccionMateriaPrima,
      prefijo: prefijo,
    );
  }

  // No permite nombres repetidos en la sucursal
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

  // Registrar auditoría sin bloquear
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
      debugPrint('No se pudo registrar la auditoría de ingredientes: $e');
    }
  }
}
