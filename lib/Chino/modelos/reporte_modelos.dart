import 'package:intl/intl.dart';

import '../../Henry/modelos/sucursal_modelo.dart' show etiquetaSucursal;

// Valores de "sin filtrar"
const String kTodasLasSucursales = 'Todas las sucursales';
const String kTodosLosProductos = 'Todos los productos';
const String kTodasLasCategorias = 'Todas las categorías';
const String kTodosLosEstados = 'Todos los estados';
const String kTodosLosMetodos = 'Todos los métodos';

// Estado inicial del filtro
const String kEstadoVentaPredeterminado = kTodosLosEstados;

const List<String> kPeriodos = [
  'Últimos 7 días',
  'Últimos 30 días',
  'Este mes',
  'Este año',
  'Personalizado',
];

enum CategoriaReporte { ventas, inventario, administracion }

extension CategoriaReporteX on CategoriaReporte {
  String get titulo => switch (this) {
        CategoriaReporte.ventas => 'Ventas',
        CategoriaReporte.inventario => 'Inventario',
        CategoriaReporte.administracion => 'Administración',
      };
}

// Filtros disponibles
enum FiltroReporte { fechas, sucursal, producto, categoria, estado, metodoPago }

const Set<FiltroReporte> _fVentas = {
  FiltroReporte.fechas,
  FiltroReporte.sucursal,
  FiltroReporte.producto,
  FiltroReporte.categoria,
  FiltroReporte.estado,
  FiltroReporte.metodoPago,
};
const Set<FiltroReporte> _fInventario = {
  FiltroReporte.sucursal,
  FiltroReporte.producto,
  FiltroReporte.categoria,
  FiltroReporte.estado,
};
const Set<FiltroReporte> _fMovimientos = {
  FiltroReporte.fechas,
  FiltroReporte.sucursal,
  FiltroReporte.producto,
  FiltroReporte.categoria,
};

// Tipos de reporte
enum TipoReporte {
  // Ventas
  ventasDetalle(CategoriaReporte.ventas, 'Detalle de ventas',
      'Cada venta con su código (comprobante), fecha, sucursal, estado e importe.', _fVentas),
  ventasPorDia(CategoriaReporte.ventas, 'Ventas por día',
      'Cantidad de ventas e importe de cada día del período.', _fVentas),
  ventasPorSemana(CategoriaReporte.ventas, 'Ventas por semana',
      'Ventas agrupadas por semana (lunes a domingo).', _fVentas),
  ventasPorMes(CategoriaReporte.ventas, 'Ventas por mes',
      'Ventas agrupadas por mes.', _fVentas),
  ventasPorSucursal(CategoriaReporte.ventas, 'Ventas por sucursal',
      'Ventas e importe por sucursal, con su porcentaje del total (compara sucursales).', _fVentas),
  ventasPorProducto(CategoriaReporte.ventas, 'Ventas por producto',
      'Unidades vendidas e importe de cada producto.', _fVentas),
  productosMasVendidos(CategoriaReporte.ventas, 'Productos más vendidos',
      'Los 10 productos con más unidades vendidas en el período.', _fVentas),
  productosMenosVendidos(CategoriaReporte.ventas, 'Productos menos vendidos',
      'Los 10 productos con menos unidades vendidas (solo productos con al menos una venta).', _fVentas),
  ventasPorMetodoPago(CategoriaReporte.ventas, 'Ventas por método de pago',
      'Ventas e importe por método de pago (requiere que las ventas lo registren).', _fVentas),

  // Inventario
  catalogoProductos(CategoriaReporte.inventario, 'Catálogo de productos',
      'Productos registrados con su categoría, sucursal, precio y estado.', _fInventario),
  existencias(CategoriaReporte.inventario, 'Existencias actuales',
      'Stock actual de cada producto y su situación frente al stock mínimo.', _fInventario),
  stockBajo(CategoriaReporte.inventario, 'Productos con stock bajo',
      'Productos con stock por debajo o igual a su stock mínimo (sin contar agotados).', _fInventario),
  agotados(CategoriaReporte.inventario, 'Productos agotados',
      'Productos sin existencias.', _fInventario),
  productosPorCategoria(CategoriaReporte.inventario, 'Productos por categoría',
      'Cantidad de productos, unidades y valor de inventario por categoría.', _fInventario),
  inventarioPorSucursal(CategoriaReporte.inventario, 'Inventario por sucursal',
      'Productos, unidades y valor de inventario de cada sucursal.', _fInventario),
  comparacionExistencias(CategoriaReporte.inventario, 'Comparación de existencias',
      'Stock de cada producto en cada sucursal, lado a lado.', _fInventario),
  movimientosInventario(CategoriaReporte.inventario, 'Movimientos de inventario',
      'Entradas y salidas de stock registradas (usa el filtro de producto para ver su historial).', _fMovimientos),

  // Administración
  resumenGeneral(CategoriaReporte.administracion, 'Resumen general',
      'Indicadores de ventas, productos y sucursales del período.',
      {FiltroReporte.fechas, FiltroReporte.sucursal}),
  disponibilidadProductos(CategoriaReporte.administracion, 'Disponibilidad de productos',
      'Productos registrados según estén activos, disponibles, con stock bajo o agotados.',
      {FiltroReporte.sucursal, FiltroReporte.categoria, FiltroReporte.estado}),
  auditoria(CategoriaReporte.administracion, 'Actividad de usuarios (auditoría)',
      'Bitácora de acciones de los usuarios. Solo para administradores.',
      {FiltroReporte.fechas}, soloAdmin: true);

  const TipoReporte(this.categoria, this.titulo, this.descripcion, this.filtros,
      {this.soloAdmin = false});

  final CategoriaReporte categoria;
  final String titulo;
  final String descripcion;
  final Set<FiltroReporte> filtros;
  final bool soloAdmin;

  bool usa(FiltroReporte f) => filtros.contains(f);

  // Solo el admin puede verlo
  bool get restringido => soloAdmin || _reportesGlobales.contains(this);

  String get etiquetaEstado => categoria == CategoriaReporte.ventas
      ? 'Estado de venta'
      : 'Estado del producto';
}

// Filtros elegidos
class FiltrosReporte {
  final String periodo;
  final DateTime desde;
  final DateTime hasta;
  final String sucursal;
  final String producto;
  final String categoria;
  final String estado;
  final String metodoPago;

  const FiltrosReporte({
    required this.periodo,
    required this.desde,
    required this.hasta,
    this.sucursal = kTodasLasSucursales,
    this.producto = kTodosLosProductos,
    this.categoria = kTodasLasCategorias,
    this.estado = kEstadoVentaPredeterminado,
    this.metodoPago = kTodosLosMetodos,
  });

  factory FiltrosReporte.predeterminados([DateTime? ahora]) {
    const periodo = 'Últimos 30 días';
    final r = rangoPara(periodo, ahora ?? DateTime.now());
    return FiltrosReporte(periodo: periodo, desde: r.$1, hasta: r.$2);
  }

  // Rango de fechas del período
  static (DateTime, DateTime) rangoPara(String periodo, DateTime ahora) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    switch (periodo) {
      case 'Últimos 7 días':
        return (DateTime(hoy.year, hoy.month, hoy.day - 6), hoy);
      case 'Este mes':
        return (DateTime(hoy.year, hoy.month, 1), hoy);
      case 'Este año':
        return (DateTime(hoy.year, 1, 1), hoy);
      case 'Últimos 30 días':
      default:
        return (DateTime(hoy.year, hoy.month, hoy.day - 29), hoy);
    }
  }

  // Inicio del día
  DateTime get inicio => DateTime(desde.year, desde.month, desde.day);

  // Fin del día
  DateTime get fin =>
      DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999);

  String? get errorFechas => inicio.isAfter(fin)
      ? 'La fecha inicial no puede ser posterior a la fecha final.'
      : null;

  bool incluyeFecha(DateTime f) => !f.isBefore(inicio) && !f.isAfter(fin);

  FiltrosReporte copyWith({
    String? periodo,
    DateTime? desde,
    DateTime? hasta,
    String? sucursal,
    String? producto,
    String? categoria,
    String? estado,
    String? metodoPago,
  }) =>
      FiltrosReporte(
        periodo: periodo ?? this.periodo,
        desde: desde ?? this.desde,
        hasta: hasta ?? this.hasta,
        sucursal: sucursal ?? this.sucursal,
        producto: producto ?? this.producto,
        categoria: categoria ?? this.categoria,
        estado: estado ?? this.estado,
        metodoPago: metodoPago ?? this.metodoPago,
      );

  // ¿El filtro está activo?
  bool activo(TipoReporte tipo, FiltroReporte f) {
    if (!tipo.usa(f)) return false;
    switch (f) {
      case FiltroReporte.fechas:
        return true;
      case FiltroReporte.sucursal:
        return sucursal != kTodasLasSucursales;
      case FiltroReporte.producto:
        return producto != kTodosLosProductos;
      case FiltroReporte.categoria:
        return categoria != kTodasLasCategorias;
      case FiltroReporte.estado:
        return estado != kTodosLosEstados;
      case FiltroReporte.metodoPago:
        return metodoPago != kTodosLosMetodos;
    }
  }

  // Descripción de los filtros
  List<String> descripcion(TipoReporte tipo) {
    final f = DateFormat('dd/MM/yyyy');
    final l = <String>[];
    if (tipo.usa(FiltroReporte.fechas)) {
      l.add('Período: ${f.format(desde)} al ${f.format(hasta)}');
    }
    if (tipo.usa(FiltroReporte.sucursal)) {
      l.add('Sucursal: ${sucursal == kTodasLasSucursales ? 'Todas las sucursales' : etiquetaSucursal(sucursal)}');
    }
    if (tipo.usa(FiltroReporte.producto)) {
      l.add('Producto: ${producto == kTodosLosProductos ? 'Todos' : producto}');
    }
    if (tipo.usa(FiltroReporte.categoria)) {
      l.add('Categoría: ${categoria == kTodasLasCategorias ? 'Todas' : categoria}');
    }
    if (tipo.usa(FiltroReporte.estado)) {
      l.add('${tipo.etiquetaEstado}: ${estado == kTodosLosEstados ? 'Todos' : estado}');
    }
    if (tipo.usa(FiltroReporte.metodoPago)) {
      l.add('Método de pago: ${metodoPago == kTodosLosMetodos ? 'Todos' : metodoPago}');
    }
    return l;
  }
}

// Opciones de los selectores
class OpcionesFiltros {
  final List<String> sucursales;
  final List<String> productos;
  final List<String> categorias;
  final List<String> estadosVenta;
  final List<String> estadosProducto;
  final List<String> metodosPago;

  const OpcionesFiltros({
    this.sucursales = const [],
    this.productos = const [],
    this.categorias = const [],
    this.estadosVenta = const [],
    this.estadosProducto = const [],
    this.metodosPago = const [],
  });
}

// Movimiento de inventario
class MovimientoInventario {
  final DateTime fecha;
  final String producto;
  final String sucursal;
  final String categoria;
  final String tipo; // 'Entrada' | 'Salida'
  final int cantidad;
  final int stockAnterior;
  final int stockNuevo;
  final String motivo;
  final String autor;

  const MovimientoInventario({
    required this.fecha,
    required this.producto,
    required this.sucursal,
    required this.categoria,
    required this.tipo,
    required this.cantidad,
    required this.stockAnterior,
    required this.stockNuevo,
    this.motivo = '',
    this.autor = '',
  });
}

// Reporte no disponible
class ReporteNoDisponible implements Exception {
  final String mensaje;
  const ReporteNoDisponible(this.mensaje);
  @override
  String toString() => mensaje;
}

enum TipoColumna { texto, entero, cantidad, moneda, porcentaje }

class ColumnaReporte {
  final String titulo;
  final TipoColumna tipo;
  const ColumnaReporte(this.titulo, [this.tipo = TipoColumna.texto]);

  bool get numerica => tipo != TipoColumna.texto;
}

class Indicador {
  final String etiqueta;
  final String valor;
  const Indicador(this.etiqueta, this.valor);
}

// Resultado del reporte
class TablaReporte {
  final TipoReporte tipo;
  final List<ColumnaReporte> columnas;

  // Filas del reporte
  final List<List<Object?>> filas;

  // Fila de totales
  final List<Object?>? totales;
  final List<Indicador> resumen;
  final List<String> filtrosAplicados;
  final List<String> advertencias;
  final DateTime generadoEn;

  const TablaReporte({
    required this.tipo,
    required this.columnas,
    required this.filas,
    this.totales,
    this.resumen = const [],
    this.filtrosAplicados = const [],
    this.advertencias = const [],
    required this.generadoEn,
  });

  bool get tieneDatos => filas.isNotEmpty;

  static final NumberFormat _fmtMoneda =
      NumberFormat.currency(symbol: 'C\$ ', decimalDigits: 2);
  static final NumberFormat _fmtEntero = NumberFormat('#,##0');
  static final NumberFormat _fmtCantidad = NumberFormat('#,##0.##');
  static final NumberFormat _fmtPct = NumberFormat('0.0');

  static String formatearMoneda(num v) => _fmtMoneda.format(v);
  static String formatearCantidad(num v) => _fmtCantidad.format(v);
  static String formatearEntero(num v) => _fmtEntero.format(v);

  String formatear(int col, Object? valor) {
    if (valor == null) return '-';
    if (valor is! num) return valor.toString();
    switch (columnas[col].tipo) {
      case TipoColumna.entero:
        return _fmtEntero.format(valor);
      case TipoColumna.cantidad:
        return _fmtCantidad.format(valor);
      case TipoColumna.moneda:
        return _fmtMoneda.format(valor);
      case TipoColumna.porcentaje:
        return '${_fmtPct.format(valor)}%';
      case TipoColumna.texto:
        return valor.toString();
    }
  }

  List<String> filaFormateada(List<Object?> fila) =>
      [for (var i = 0; i < fila.length; i++) formatear(i, fila[i])];
}

// Reportes solo para admin
const Set<TipoReporte> _reportesGlobales = {
  TipoReporte.ventasPorSucursal,
  TipoReporte.inventarioPorSucursal,
  TipoReporte.comparacionExistencias,
  TipoReporte.movimientosInventario,
  TipoReporte.resumenGeneral,
  TipoReporte.disponibilidadProductos,
  TipoReporte.auditoria,
};
