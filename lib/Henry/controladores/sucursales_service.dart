import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../Chino/controladores/auditoria_service.dart';
import '../../Chino/modelos/evento_auditoria_modelo.dart';
import '../../Chino/modelos/materia_prima_modelo.dart';
import '../../Chino/modelos/producto_modelo.dart';
import '../modelos/sucursal_modelo.dart';
import '../../Chino/modelos/venta_modelo.dart';

/// CRUD de la colección `sucursales` en Firestore.
///
/// Es el servicio que "alimenta" a los demás módulos: Materia Prima (y los
/// que vengan) usan [streamSucursalesActivas] para llenar su selector de
/// sucursal. Cada operación deja un registro en la bitácora `auditoria`.
class SucursalesService {
  SucursalesService({
    FirebaseFirestore? firestore,
    AuditoriaService? auditoriaService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auditoria = auditoriaService ?? AuditoriaService(firestore: firestore);

  final FirebaseFirestore _db;
  final AuditoriaService _auditoria;

  static const String _modulo = 'Sucursales';

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionSucursales);

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

  /// Todas las sucursales (activas e inactivas), ordenadas por nombre.
  Stream<List<Sucursal>> streamSucursales() {
    return _coleccion.orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(Sucursal.fromDoc).toList(),
        );
  }

  /// Solo las sucursales activas: es lo que deben usar los selectores de
  /// otros módulos. (Se filtra en el cliente para no requerir un índice
  /// compuesto en Firestore.)
  Stream<List<Sucursal>> streamSucursalesActivas() {
    return streamSucursales().map(
      (lista) => lista.where((s) => s.activo).toList(),
    );
  }

  /// Una sola sucursal en tiempo real. Emite `null` si fue eliminada.
  Stream<Sucursal?> streamSucursal(String id) {
    return _coleccion.doc(id).snapshots().map(
          (doc) => doc.exists ? Sucursal.fromDoc(doc) : null,
        );
  }

  /// Cuántos productos tiene asignados una sucursal (por nombre).
  Future<int> contarProductos(String nombreSucursal) =>
      _contar(_db.collection(kColeccionProductos)
          .where('sucursal', isEqualTo: nombreSucursal));

  /// Cuántas materias primas tiene asignadas una sucursal (por nombre).
  Future<int> contarMateriasPrimas(String nombreSucursal) =>
      _contar(_db.collection(kColeccionMateriaPrima)
          .where('sucursal', isEqualTo: nombreSucursal));

  /// Cuántas ventas tiene una sucursal. Las ventas pueden guardar el nombre
  /// como "Centro" o como "Sucursal Centro", así que se cuentan ambas formas.
  Future<int> contarVentas(String nombreSucursal) =>
      _contar(_db.collection(kColeccionVentas).where(
            'sucursal',
            whereIn: variantesNombreSucursal(nombreSucursal),
          ));

  Future<int> _contar(Query<Map<String, dynamic>> query) async {
    final r = await query.count().get();
    return r.count ?? 0;
  }

  // ---------------------------------------------------------------- Escritura

  /// Crea una sucursal con código autogenerado (S001, S002, ...).
  Future<String> crear({
    required String nombre,
    required String encargado,
    required String ciudad,
    required String direccion,
    required int cantidadPersonal,
    required String estado,
  }) async {
    nombre = nombre.trim();
    await _validarDuplicado(nombre);

    final codigo = await _siguienteCodigo();
    final ref = _coleccion.doc(codigo);
    final nueva = Sucursal(
      id: codigo,
      codigo: codigo,
      nombre: nombre,
      encargado: encargado.trim(),
      ciudad: ciudad,
      direccion: direccion.trim(),
      cantidadPersonal: cantidadPersonal,
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
      descripcion: 'Se registró la sucursal "$nombre"',
      sucursal: nueva,
    );
    return codigo;
  }

  /// Guarda los cambios. Si cambia el nombre, actualiza también las materias
  /// primas y productos que apuntaban a la sucursal con el nombre anterior.
  Future<void> actualizar({
    required Sucursal original,
    required String nombre,
    required String encargado,
    required String ciudad,
    required String direccion,
    required int cantidadPersonal,
    required String estado,
  }) async {
    nombre = nombre.trim();
    await _validarDuplicado(nombre, excluirId: original.id);

    final editada = Sucursal(
      id: original.id,
      codigo: original.codigo,
      nombre: nombre,
      encargado: encargado.trim(),
      ciudad: ciudad,
      direccion: direccion.trim(),
      cantidadPersonal: cantidadPersonal,
      estado: estado,
    );

    final batch = _db.batch();
    batch.update(_coleccion.doc(original.id), editada.toMap());

    if (nombre != original.nombre) {
      for (final coleccion in [kColeccionMateriaPrima, kColeccionProductos]) {
        final snap = await _db
            .collection(coleccion)
            .where('sucursal', isEqualTo: original.nombre)
            .get();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'sucursal': nombre});
        }
      }
    }
    await batch.commit();

    await _registrarAuditoria(
      tipo: TipoEvento.editar,
      descripcion: 'Se editó la sucursal "${original.nombre}"',
      sucursal: editada,
      detalle: nombre != original.nombre
          ? 'Nombre: ${original.nombre} → $nombre'
          : null,
    );
  }

  Future<void> cambiarEstado(Sucursal sucursal, String nuevoEstado) async {
    await _coleccion.doc(sucursal.id).update({
      'estado': nuevoEstado,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    await _registrarAuditoria(
      tipo: TipoEvento.editar,
      descripcion:
          '${nuevoEstado == 'Activo' ? 'Se activó' : 'Se desactivó'} la sucursal "${sucursal.nombre}"',
      sucursal: sucursal,
      detalle: 'Estado: ${sucursal.estado} → $nuevoEstado',
    );
  }

  /// Elimina la sucursal. Se bloquea si todavía tiene productos o materia
  /// prima asignados, para no dejar documentos apuntando a una sucursal que
  /// ya no existe (en ese caso conviene desactivarla).
  Future<void> eliminar(Sucursal sucursal) async {
    final productos = await contarProductos(sucursal.nombre);
    final materias = await contarMateriasPrimas(sucursal.nombre);
    if (productos > 0 || materias > 0) {
      throw StateError(
        'No se puede eliminar: tiene $productos producto(s) y $materias '
        'materia(s) prima asignados. Desactívala en su lugar.',
      );
    }

    await _coleccion.doc(sucursal.id).delete();

    await _registrarAuditoria(
      tipo: TipoEvento.eliminar,
      descripcion: 'Se eliminó la sucursal "${sucursal.nombre}"',
      sucursal: sucursal,
    );
  }

  // ---------------------------------------------------------------- Helpers

  Future<String> _siguienteCodigo() async {
    final snap = await _coleccion.get();
    var maximo = 0;
    for (final doc in snap.docs) {
      final numero = int.tryParse(doc.id.replaceAll(RegExp(r'[^0-9]'), ''));
      if (numero != null && numero > maximo) maximo = numero;
    }
    return 'S${(maximo + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _validarDuplicado(String nombre, {String? excluirId}) async {
    final snap = await _coleccion.get();
    final repetido = snap.docs.any(
      (d) =>
          d.id != excluirId &&
          ((d.data()['nombre'] ?? '') as String).trim().toLowerCase() ==
              nombre.toLowerCase(),
    );
    if (repetido) {
      throw StateError('Ya existe una sucursal llamada "$nombre".');
    }
  }

  /// La auditoría nunca debe impedir que la operación principal termine.
  Future<void> _registrarAuditoria({
    required TipoEvento tipo,
    required String descripcion,
    required Sucursal sucursal,
    String? detalle,
  }) async {
    try {
      await _auditoria.registrarEvento(
        titulo: _modulo,
        tipo: tipo,
        descripcion: descripcion,
        autor: _autor,
        modulo: _modulo,
        idReferencia: sucursal.codigo,
        datosAdicionales: [
          CampoInfo('Sucursal', sucursal.nombre),
          CampoInfo('Encargado', sucursal.encargado),
          CampoInfo('Ciudad', sucursal.ciudad),
          if (detalle != null) CampoInfo('Detalle', detalle),
        ],
      );
    } catch (e) {
      debugPrint('No se pudo registrar la auditoría de sucursales: $e');
    }
  }
}
