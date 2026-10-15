import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Chino/modelos/producto_modelo.dart' show kColeccionProductos;
import '../modelos/FuncionVenta.dart';
import 'ConeccionFirebase.dart' show VentasRef;
import '../../Chino/controladores/permisos_service.dart';

// Permitir venta sin stock
const bool kPermitirVentaSinStock = false;

// Error de stock
class VentaStockException implements Exception {
  final String mensaje;
  const VentaStockException(this.mensaje);

  @override
  String toString() => mensaje;
}

// Producto y sucursal de un ajuste
class _Linea {
  final ProductList producto;
  final String sucursal;
  const _Linea(this.producto, this.sucursal);
}

// Cambio de stock de un producto
class _Ajuste {
  final DocumentReference<Map<String, dynamic>>? ref; // null = no se encontró
  final String nombre;
  double delta = 0; // negativo = sale stock, positivo = vuelve stock
  _Ajuste(this.ref, this.nombre);
}

// Registrar venta y descontar stock
Future<String> registrarVentaConStock(CRUDVentas venta) async {
  final ventaRef = VentasRef.doc(); // id generado localmente
  await _ejecutar(
    codigoVenta: venta.codigoV,
    descontar: _lineas(venta.productos, venta.sucursalU),
    devolver: const [],
    // Guarda también quién vendió
    escribirVenta: (tx) => tx.set(ventaRef, {
      ...ventaToMap(venta),
      'vendedorId': Permisos.instance.uid,
      'vendedorNombre': Permisos.instance.nombre,
      'vendedorCorreo': Permisos.instance.correo,
    }),
  );
  return ventaRef.id;
}

// Actualizar venta y ajustar stock
Future<void> actualizarVentaConStock(
  CRUDVentas venta, {
  required List<ProductList> anteriores,
  required String sucursalAnterior,
}) async {
  final ventaRef = VentasRef.doc(venta.id);
  await _ejecutar(
    codigoVenta: venta.codigoV,
    descontar: _lineas(venta.productos, venta.sucursalU),
    devolver: _lineas(anteriores, sucursalAnterior),
    escribirVenta: (tx) => tx.update(ventaRef, ventaToMap(venta)),
  );
}

// Eliminar venta y devolver stock
Future<void> eliminarVentaConStock(CRUDVentas venta) async {
  final ventaRef = VentasRef.doc(venta.id);
  await _ejecutar(
    codigoVenta: venta.codigoV,
    descontar: const [],
    devolver: _lineas(venta.productos, venta.sucursalU),
    escribirVenta: (tx) => tx.delete(ventaRef),
  );
}

List<_Linea> _lineas(List<ProductList> productos, String sucursal) =>
    productos.map((p) => _Linea(p, sucursal)).toList();

String _norm(String s) => s.trim().toLowerCase();

// Entero si no tiene decimales
num _limpio(double v) => v == v.roundToDouble() ? v.toInt() : v;

double _leerStock(Map<String, dynamic> data) {
  final v = data['stock'] ?? data['cantidad'];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0;
  return 0;
}

// Buscar el producto de la línea
Future<DocumentReference<Map<String, dynamic>>?> _resolver(
  _Linea l,
  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> cache,
) async {
  final col = FirebaseFirestore.instance.collection(kColeccionProductos);

  if (l.producto.productoId.isNotEmpty) {
    return col.doc(l.producto.productoId);
  }

  final codigo = l.producto.codigo;
  final docs = cache[codigo] ??=
      (await col.where('codigo', isEqualTo: codigo).get()).docs;

  if (docs.isNotEmpty) {
    for (final d in docs) {
      if (_norm((d.data()['sucursal'] ?? '').toString()) ==
          _norm(l.sucursal)) {
        return d.reference;
      }
    }
    return docs.first.reference;
  }

  // Sin código: se usa el id del documento
  if (codigo.isNotEmpty) {
    final porId = await col.doc(codigo).get();
    if (porId.exists) return porId.reference;
  }
  return null;
}

Future<void> _ejecutar({
  required String codigoVenta,
  required List<_Linea> descontar,
  required List<_Linea> devolver,
  required void Function(Transaction tx) escribirVenta,
}) async {
  final db = FirebaseFirestore.instance;

  // Resolver documentos y acumular cambios
  final cache = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  final ajustes = <String, _Ajuste>{};

  Future<void> acumular(_Linea l, double signo) async {
    final ref = await _resolver(l, cache);
    final clave = ref?.path ?? 'sin-doc:${l.producto.codigo}';
    final ajuste = ajustes.putIfAbsent(
      clave,
      () => _Ajuste(ref, l.producto.nombre),
    );
    ajuste.delta += signo * l.producto.cantidad;
  }

  for (final l in devolver) {
    await acumular(l, 1);
  }
  for (final l in descontar) {
    await acumular(l, -1);
  }

  final autor = FirebaseAuth.instance.currentUser?.email ?? 'Ventas';

  // Transacción: venta y stock juntos
  await db.runTransaction((tx) async {
    // Primero lecturas, luego escrituras
    final cambios = <_Cambio>[];

    for (final a in ajustes.values) {
      if (a.delta == 0) continue; // sin cambios

      if (a.ref == null) {
        if (a.delta < 0) {
          throw VentaStockException(
            'El producto "${a.nombre}" ya no existe en el inventario.',
          );
        }
        continue; // producto borrado, se omite
      }

      final snap = await tx.get(a.ref!);
      if (!snap.exists) {
        if (a.delta < 0) {
          throw VentaStockException(
            'El producto "${a.nombre}" ya no existe en el inventario.',
          );
        }
        continue;
      }

      final actual = _leerStock(snap.data() ?? <String, dynamic>{});
      var nuevo = actual + a.delta;
      if (nuevo < 0) {
        if (!kPermitirVentaSinStock) {
          throw VentaStockException(
            'Stock insuficiente de "${a.nombre}": '
            'disponible ${_limpio(actual)}, se necesitan ${_limpio(-a.delta)}.',
          );
        }
        nuevo = 0;
      }
      cambios.add(_Cambio(a, actual, nuevo));
    }

    for (final c in cambios) {
      final ref = c.ajuste.ref!;
      // stock y cantidad siempre iguales
      tx.update(ref, {
        'stock': _limpio(c.nuevo),
        'cantidad': _limpio(c.nuevo),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      // Movimiento para los reportes
      final saleStock = c.ajuste.delta < 0;
      tx.set(ref.collection('movimientos').doc(), {
        'tipo': saleStock ? 'Salida' : 'Entrada',
        'cantidad': _limpio(c.ajuste.delta.abs()),
        'motivo': saleStock
            ? 'Venta $codigoVenta'
            : 'Ajuste por venta $codigoVenta (eliminada o editada)',
        'stockAnterior': _limpio(c.anterior),
        'stockNuevo': _limpio(c.nuevo),
        'autor': autor,
        'fecha': FieldValue.serverTimestamp(),
      });
    }

    escribirVenta(tx);
  });
}

class _Cambio {
  final _Ajuste ajuste;
  final double anterior;
  final double nuevo;
  const _Cambio(this.ajuste, this.anterior, this.nuevo);
}
