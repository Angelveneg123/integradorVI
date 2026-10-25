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

// La venta ya estaba guardada (por ejemplo, un segundo toque en Guardar)
class VentaDuplicadaException extends VentaStockException {
  const VentaDuplicadaException()
      : super('Esta venta ya estaba registrada. No se guardó otra vez.');
}

// Registrar venta y descontar stock.
// [ventaId] debe ser el mismo en todos los intentos de una misma venta: si el
// documento ya existe, no se vuelve a guardar ni a descontar el stock.
Future<String> registrarVentaConStock(CRUDVentas venta, {String? ventaId}) async {
  final ventaRef = ventaId == null ? VentasRef.doc() : VentasRef.doc(ventaId);
  await _ejecutar(
    codigoVenta: venta.codigoV,
    ventaNuevaRef: ventaRef,
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
  if (await _stockYaDevuelto(ventaRef)) {
    throw const VentaStockException(
      'Una venta anulada no se puede editar. Reactívala primero.',
    );
  }
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
  // Si la venta ya estaba anulada, su stock ya volvió: no se devuelve otra vez
  final yaDevuelto = await _stockYaDevuelto(ventaRef);
  await _ejecutar(
    codigoVenta: venta.codigoV,
    descontar: const [],
    devolver: yaDevuelto ? const [] : _lineas(venta.productos, venta.sucursalU),
    ventaVerificarRef: ventaRef,
    verificarVenta: (data) {
      if (data == null) {
        throw const VentaStockException('Esta venta ya fue eliminada.');
      }
    },
    escribirVenta: (tx) => tx.delete(ventaRef),
  );
}

// Anular venta: devuelve el stock y la deja Inactiva (queda en el historial)
Future<void> anularVentaConStock(CRUDVentas venta) async {
  final ventaRef = VentasRef.doc(venta.id);
  if (await _stockYaDevuelto(ventaRef)) {
    throw const VentaStockException('Esta venta ya está anulada.');
  }
  await _ejecutar(
    codigoVenta: venta.codigoV,
    descontar: const [],
    devolver: _lineas(venta.productos, venta.sucursalU),
    motivoEntrada: 'Venta ${venta.codigoV} anulada',
    ventaVerificarRef: ventaRef,
    verificarVenta: (data) {
      if (data == null) {
        throw const VentaStockException('Esta venta ya fue eliminada.');
      }
      if (data['stockDevuelto'] == true) {
        throw const VentaStockException('Esta venta ya está anulada.');
      }
    },
    escribirVenta: (tx) => tx.update(ventaRef, {
      'estado': 'Inactivo',
      'stockDevuelto': true,
    }),
  );
}

// Reactivar venta: vuelve a descontar el stock (falla si no alcanza)
Future<void> reactivarVentaConStock(CRUDVentas venta) async {
  final ventaRef = VentasRef.doc(venta.id);
  if (!await _stockYaDevuelto(ventaRef)) {
    // Venta desactivada antes de esta regla: su stock nunca volvió,
    // así que solo se cambia el estado.
    await ventaRef.update({'estado': 'Activo'});
    return;
  }
  await _ejecutar(
    codigoVenta: venta.codigoV,
    descontar: _lineas(venta.productos, venta.sucursalU),
    devolver: const [],
    motivoSalida: 'Venta ${venta.codigoV} reactivada',
    ventaVerificarRef: ventaRef,
    verificarVenta: (data) {
      if (data == null) {
        throw const VentaStockException('Esta venta ya fue eliminada.');
      }
      if (data['stockDevuelto'] != true) {
        throw const VentaStockException('Esta venta ya está activa.');
      }
    },
    escribirVenta: (tx) => tx.update(ventaRef, {
      'estado': 'Activo',
      'stockDevuelto': false,
    }),
  );
}

// ¿Esta venta ya devolvió su stock (está anulada)?
Future<bool> _stockYaDevuelto(
  DocumentReference<Map<String, dynamic>> ventaRef,
) async {
  final snap = await ventaRef.get();
  return snap.data()?['stockDevuelto'] == true;
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
  // Si se indica, falla cuando esa venta ya existe (evita duplicados)
  DocumentReference<Map<String, dynamic>>? ventaNuevaRef,
  // Comprueba el estado actual de la venta DENTRO de la transacción
  // (evita repetir una acción, p. ej. devolver el stock dos veces)
  DocumentReference<Map<String, dynamic>>? ventaVerificarRef,
  void Function(Map<String, dynamic>? data)? verificarVenta,
  String? motivoEntrada,
  String? motivoSalida,
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

    if (ventaNuevaRef != null && (await tx.get(ventaNuevaRef)).exists) {
      throw const VentaDuplicadaException();
    }
    if (ventaVerificarRef != null && verificarVenta != null) {
      final s = await tx.get(ventaVerificarRef);
      verificarVenta(s.exists ? s.data() : null);
    }

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
            ? (motivoSalida ?? 'Venta $codigoVenta')
            : (motivoEntrada ??
                'Ajuste por venta $codigoVenta (eliminada o editada)'),
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
