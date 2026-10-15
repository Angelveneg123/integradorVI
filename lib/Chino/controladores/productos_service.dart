import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/producto_modelo.dart';

// Lectura de productos
class ProductosService {
  ProductosService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionProductos);

  // Productos en tiempo real
  Stream<List<Producto>> streamProductos() {
    return _coleccion.orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(Producto.fromDoc).toList(),
        );
  }

  // Un producto en tiempo real
  Stream<Producto?> streamProducto(String id) {
    return _coleccion.doc(id).snapshots().map(
          (doc) => doc.exists ? Producto.fromDoc(doc) : null,
        );
  }

  // Lectura de todos los productos
  Future<List<Producto>> obtenerProductos({String? sucursal}) async {
    Query<Map<String, dynamic>> query = _coleccion;
    if (sucursal != null && sucursal.trim().isNotEmpty) {
      query = query.where('sucursal', isEqualTo: sucursal);
    }
    final snap = await query.orderBy('nombre').get();
    return snap.docs.map(Producto.fromDoc).toList();
  }

  // Productos con stock bajo
  Future<List<Producto>> obtenerProductosBajoStock({String? sucursal}) async {
    final productos = await obtenerProductos(sucursal: sucursal);
    return productos.where((p) => p.bajoStock).toList();
  }
}
