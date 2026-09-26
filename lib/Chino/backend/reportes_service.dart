import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'venta_modelo.dart';
import 'auditoria_service.dart';
import 'productos_service.dart';

/// Tabla genérica de resultados para mostrar en `ResultadoReporteScreen`.
class TablaReporte {
  final List<String> columnas;
  final List<List<String>> filas;

  const TablaReporte({required this.columnas, required this.filas});
}

/// Arma los 3 tipos de reporte que ofrece el formulario de Reportes:
/// "Ventas por periodo" (depende de la colección `ventas`, del módulo de
/// Ventas), "Inventario actual" (depende de `productos`, del módulo de
/// Productos) y "Auditoría de actividad" (depende de `auditoria`).
class ReportesService {
  ReportesService({
    FirebaseFirestore? firestore,
    ProductosService? productosService,
    AuditoriaService? auditoriaService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _productos = productosService ?? ProductosService(firestore: firestore),
        _auditoria = auditoriaService ?? AuditoriaService(firestore: firestore);

  final FirebaseFirestore _db;
  final ProductosService _productos;
  final AuditoriaService _auditoria;

  static final _fmtFecha = DateFormat('dd/MM/yyyy');
  static final _fmtMoneda = NumberFormat.currency(symbol: 'C\$ ', decimalDigits: 2);

  /// Traduce la opción de fecha del formulario ("Últimos 7 días", etc.) a
  /// un rango [desde, hasta].
  (DateTime, DateTime) rangoParaOpcion(String opcionFecha) {
    final ahora = DateTime.now();
    final hasta = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
    switch (opcionFecha) {
      case 'Últimos 7 días':
        return (hasta.subtract(const Duration(days: 7)), hasta);
      case 'Últimos 30 días':
        return (hasta.subtract(const Duration(days: 30)), hasta);
      case 'Este mes':
        return (DateTime(ahora.year, ahora.month, 1), hasta);
      case 'Este año':
        return (DateTime(ahora.year, 1, 1), hasta);
      default:
        return (hasta.subtract(const Duration(days: 30)), hasta);
    }
  }

  /// Convierte "Sucursal Centro" / "Sucursal Norte" / "Todas las sucursales"
  /// del formulario al valor que se guarda en los documentos.
  String? sucursalParaFiltro(String opcionSucursal) {
    if (opcionSucursal == 'Todas las sucursales') return null;
    return opcionSucursal.replaceFirst('Sucursal ', '');
  }

  Future<TablaReporte> generar({
    required String tipoReporte,
    required String fecha,
    required String sucursal,
  }) async {
    switch (tipoReporte) {
      case 'Inventario actual':
        return _reporteInventario(sucursal);
      case 'Auditoría de actividad':
        return _reporteAuditoria(fecha, sucursal);
      case 'Ventas por periodo':
      default:
        return _reporteVentas(fecha, sucursal);
    }
  }

  Future<TablaReporte> _reporteVentas(String opcionFecha, String opcionSucursal) async {
    final (desde, hasta) = rangoParaOpcion(opcionFecha);
    final sucursal = sucursalParaFiltro(opcionSucursal);

    Query<Map<String, dynamic>> query = _db
        .collection(kColeccionVentas)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta));
    if (sucursal != null) {
      query = query.where('sucursal', isEqualTo: sucursal);
    }

    final snap = await query.orderBy('fecha', descending: true).get();
    final ventas = snap.docs.map(Venta.fromDoc).toList();

    final filas = <List<String>>[];
    for (final venta in ventas) {
      if (venta.items.isEmpty) {
        filas.add([
          _fmtFecha.format(venta.fecha),
          '—',
          '—',
          _fmtMoneda.format(venta.total),
        ]);
      } else {
        for (final item in venta.items) {
          filas.add([
            _fmtFecha.format(venta.fecha),
            item.nombre,
            '${item.cantidad}',
            _fmtMoneda.format(item.subtotal),
          ]);
        }
      }
    }

    return TablaReporte(
      columnas: const ['Fecha', 'Producto', 'Cantidad', 'Total'],
      filas: filas,
    );
  }

  Future<TablaReporte> _reporteInventario(String opcionSucursal) async {
    final sucursal = sucursalParaFiltro(opcionSucursal);
    final productos = await _productos.obtenerProductos(sucursal: sucursal);

    final filas = productos
        .map((p) => [
              p.nombre,
              '${p.stock}',
              '${p.stockMinimo}',
              p.bajoStock ? 'Bajo' : 'Stock OK',
            ])
        .toList();

    return TablaReporte(
      columnas: const ['Producto', 'Stock actual', 'Stock mínimo', 'Estado'],
      filas: filas,
    );
  }

  Future<TablaReporte> _reporteAuditoria(String opcionFecha, String opcionSucursal) async {
    final (desde, hasta) = rangoParaOpcion(opcionFecha);
    final eventos = await _auditoria.obtenerEventos(desde: desde, hasta: hasta);

    final filas = eventos
        .map((e) => [
              DateFormat('dd/MM/yyyy').format(e.fecha),
              e.autor,
              e.etiqueta,
              e.modulo,
            ])
        .toList();

    return TablaReporte(
      columnas: const ['Fecha', 'Usuario', 'Acción', 'Módulo'],
      filas: filas,
    );
  }
}
