import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/FuncionVenta.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Chino/modelos/usuario_modelo.dart' show kColeccionUsuarios;
import '../../Henry/modelos/sucursal_modelo.dart' show kColeccionSucursales;

////////////////////////////FUNCIONES DE CARGAR DATOS EN LA BD//////////////////////////
final CollectionReference<Map<String, dynamic>> VentasRef = FirebaseFirestore
    .instance
    .collection('ventas');

//Elementos de carga de datos----------------------------
Future<List<CRUDVentas>> cargarVentaDb() async {
  try {
    final snapshot = await VentasRef.get();

    final lista = snapshot.docs.map((doc) {
      final data = doc.data();
      ////////////////////////////////////////ME SIRVE PARA AÑADIR MAS DE 1 PRODUCTO AL REGISTRO

      // Soporta tanto 'items' (como en Firestore) como 'productos'
      final itemsFirestore = (data['items'] ?? data['productos']) as List?;

      List<ProductList> listaProductos = [];

      if (itemsFirestore != null) {
        listaProductos = itemsFirestore.map((item) {
          final precioVal =
              (item['precioUnitario'] ?? item['precio']) as num?;
          return ProductList(
            codigo: item['codigo']?.toString() ?? '',
            nombre: item['nombre']?.toString() ?? '',
            cantidad: (item['cantidad'] as num?)?.toDouble() ?? 0.0,
            precio: precioVal?.toDouble() ?? 0.0,
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
    }).toList();

    return lista;
  } catch (e) {
    debugPrint('ERROR AL CARGAR REGISTRO: $e');
    return [];
  }
}

Future<void> probarFirebase() async {
  try {
    await VentasRef.limit(1).get();
    debugPrint('FIREBASE CONECTADO CORRECTAMENTE');
  } catch (e) {
    debugPrint('ERROR FIREBASE: $e');
  }
}

// cargar Productos/////////////////////////////////////////////////////////////////
/// Convierte un valor de Firestore a número aunque venga como texto ("12,50").
double _aNumero(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

/// Productos de la colección `productos` que NO estén inactivos, ordenados por
/// nombre.
///
/// - No usa `orderBy` (dejaba fuera los documentos sin ese campo).
/// - Cada documento se lee por separado: uno con datos raros se omite en vez
///   de tumbar toda la lista.
/// - Los errores de Firestore (permisos, red) NO se tragan: llegan a la
///   pantalla para mostrarlos.
Future<List<ProductList>> cargarProductosDb() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('productos')
      .get();

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

// cargar Sucursales////////////////////////////////////////////////////////////////
/// Nombres de las sucursales ACTIVAS de la colección `sucursales` (la misma
/// que administra el módulo de Sucursales).
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

// Cargar Sucursal de Usuario //////////////////////////////////////////////////
/// Sucursal del usuario que inició sesión (`usuarios/{uid}`). Devuelve '' si no
/// hay sesión o el usuario no tiene sucursal asignada.
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