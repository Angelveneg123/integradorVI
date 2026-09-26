import 'package:cloud_firestore/cloud_firestore.dart';

import 'producto_modelo.dart';

/// Acceso de solo lectura (desde Chino) a la colección `productos`.
///
/// El CRUD real (crear/editar/eliminar producto) vive en el módulo de
/// Productos; Stock y Reportes solo leen de aquí. Así, en cuanto el módulo
/// de Productos escriba en Firestore, Stock y Reportes se actualizan solos.
class ProductosService {
  ProductosService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionProductos);

  /// Stream en tiempo real de todos los productos, ordenados por nombre.
  Stream<List<Producto>> streamProductos() {
    return _coleccion.orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(Producto.fromDoc).toList(),
        );
  }

  /// Stream en tiempo real de un solo producto (para pantallas de detalle).
  Stream<Producto?> streamProducto(String id) {
    return _coleccion.doc(id).snapshots().map(
          (doc) => doc.exists ? Producto.fromDoc(doc) : null,
        );
  }

  /// Lectura puntual de todos los productos (usado por Reportes al generar
  /// el reporte de "Inventario actual").
  Future<List<Producto>> obtenerProductos({String? sucursal}) async {
    Query<Map<String, dynamic>> query = _coleccion;
    if (sucursal != null && sucursal.trim().isNotEmpty) {
      query = query.where('sucursal', isEqualTo: sucursal);
    }
    final snap = await query.orderBy('nombre').get();
    return snap.docs.map(Producto.fromDoc).toList();
  }

  /// Productos cuyo stock actual está en o por debajo del stock mínimo.
  Future<List<Producto>> obtenerProductosBajoStock({String? sucursal}) async {
    final productos = await obtenerProductos(sucursal: sucursal);
    return productos.where((p) => p.bajoStock).toList();
  }
}
