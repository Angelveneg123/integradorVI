import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/FuncionVenta.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Chino/modelos/usuario_modelo.dart' show kColeccionUsuarios;
import '../../Henry/modelos/sucursal_modelo.dart' show kColeccionSucursales;

// Referencia a ventas
final CollectionReference<Map<String, dynamic>> VentasRef = FirebaseFirestore
    .instance
    .collection('ventas');

// Documento de venta a objeto
CRUDVentas _ventaDesdeDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  // Productos de la venta

  // Acepta items o productos
  final itemsFirestore = (data['items'] ?? data['productos']) as List?;

  List<ProductList> listaProductos = [];

  if (itemsFirestore != null) {
    listaProductos = itemsFirestore.map((item) {
      final precioVal = (item['precioUnitario'] ?? item['precio']) as num?;
      return ProductList(
        codigo: item['codigo']?.toString() ?? '',
        nombre: item['nombre']?.toString() ?? '',
        cantidad: (item['cantidad'] as num?)?.toDouble() ?? 0.0,
        precio: precioVal?.toDouble() ?? 0.0,
        productoId: item['productoId']?.toString() ?? '',
      );
    }).toList();
  }

  return CRUDVentas(
    id: doc.id,
    codigoV:
        data['codigoV']?.toString() ??
        doc.id.substring(0, doc.id.length >= 6 ? 6 : doc.id.length),
    estado: data['estado']?.toString() ?? 'Activo',
    sucursalU:
        data['sucursal']?.toString() ??
        data['sucursalU']?.toString() ??
        'Norte',
    fecha: data['fecha']?.toString() ?? '',
    productos: listaProductos,
  );
}

// Cargar ventas (una sola vez)
Future<List<CRUDVentas>> cargarVentaDb() async {
  try {
    final snapshot = await VentasRef.get();
    return snapshot.docs.map(_ventaDesdeDoc).toList();
  } catch (e) {
    debugPrint('ERROR AL CARGAR REGISTRO: $e');
    return [];
  }
}

// Ventas en tiempo real
Stream<List<CRUDVentas>> streamVentasDb() {
  return VentasRef.snapshots().map(
    (snapshot) => snapshot.docs.map(_ventaDesdeDoc).toList(),
  );
}

Future<void> probarFirebase() async {
  try {
    await VentasRef.limit(1).get();
    debugPrint('FIREBASE CONECTADO CORRECTAMENTE');
  } catch (e) {
    debugPrint('ERROR FIREBASE: $e');
  }
}

// Valor a número
double _aNumero(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

// Productos activos
Future<List<ProductList>> cargarProductosDb() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('productos')
      .get();
  return _productosDesdeSnapshot(snapshot);
}

// Productos en tiempo real
Stream<List<ProductList>> streamProductosDb() {
  return FirebaseFirestore.instance
      .collection('productos')
      .snapshots()
      .map(_productosDesdeSnapshot);
}

List<ProductList> _productosDesdeSnapshot(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final lista = <ProductList>[];
  for (final doc in snapshot.docs) {
    try {
      final data = doc.data();

      final estado = (data['estado'] ?? 'Activo').toString().trim().toLowerCase();
      if (estado == 'inactivo') continue;

      final nombre = (data['nombre'] ?? '').toString().trim();
      if (nombre.isEmpty) continue;

      lista.add(
        ProductList(
          codigo: (data['codigo'] ?? doc.id).toString(),
          nombre: nombre,
          cantidad: 1.0,
          precio: _aNumero(data['precio']),
          productoId: doc.id,
          sucursal: (data['sucursal'] ?? '').toString().trim(),
        ),
      );
    } catch (e) {
      debugPrint('Producto ${doc.id} omitido: $e');
    }
  }

  lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  return lista;
}

// Sucursales activas
Future<List<String>> cargarSucursalesDb() async {
  final snapshot = await FirebaseFirestore.instance
      .collection(kColeccionSucursales)
      .get();

  final nombres = snapshot.docs
      .where((doc) => (doc.data()['estado'] ?? 'Activo') == 'Activo')
      .map((doc) => (doc.data()['nombre'] ?? '').toString().trim())
      .where((nombre) => nombre.isNotEmpty)
      .toSet()
      .toList();

  nombres.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return nombres;
}

// Sucursal del usuario
Future<String> cargarSucursalUsuarioDb() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';

    final doc = await FirebaseFirestore.instance
        .collection(kColeccionUsuarios)
        .doc(uid)
        .get();

    return (doc.data()?['sucursal'] ?? '').toString().trim();
  } catch (e) {
    debugPrint('Error cargando sucursal de usuario: $e');
    return '';
  }
}