import 'package:intl/intl.dart';

import '../../Henry/modelos/sucursal_modelo.dart';
import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/producto_modelo.dart';
import '../modelos/reporte_modelos.dart';
import '../modelos/venta_modelo.dart';

// Datos del reporte
class DatosReporte {
  final List<Venta> ventas;
  final List<Producto> productos;
  final List<MovimientoInventario> movimientos;
  final List<EventoAuditoria> eventos;
  final List<Sucursal> sucursales;

  // Documentos omitidos
  final int documentosOmitidos;
  final DateTime ahora;

  const DatosReporte({
    this.ventas = const [],
    this.productos = const [],
    this.movimientos = const [],
    this.eventos = const [],
    this.sucursales = const [],
    this.documentosOmitidos = 0,
    required this.ahora,
  });
}

// Línea de venta
class LineaVenta {
  final String ventaId;
  final String codigoVenta;
  final DateTime fecha;
  final String sucursal;
  final String estado;
  final String producto;
  final String categoria;
  final double cantidad;
  final double subtotal;
  final double precioUnitario;
  final String cliente;
  final String vendedor;

  // Venta sin detalle
  final bool sinDetalle;

  const LineaVenta({
    required this.ventaId,
    required this.codigoVenta,
    required this.fecha,
    required this.sucursal,
    required this.estado,
    required this.producto,
    required this.categoria,
    required this.cantidad,
    required this.subtotal,
    this.precioUnitario = 0,
    this.cliente = '',
    this.vendedor = '',
    this.sinDetalle = false,
  });
}

class _Acum {
  final String etiqueta;
  final Set<String> ventas = {};
  double cantidad = 0;
  double importe = 0;
  String extra = '';
  final List<LineaVenta> lineas = [];
  _Acum(this.etiqueta);
}

// Cálculos de los reportes
class ReportesCalculos {
  ReportesCalculos._();

  static const String sinCategoria = 'Sin categoría';
  static const List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
    'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  // Utilidades

  static String norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String normSucursal(String s) =>
      norm(s).replaceFirst(RegExp(r'^sucursal\s+'), '');

  static bool mismaSucursal(String a, String b) =>
      normSucursal(a) == normSucursal(b);

  static double r2(double v) => (v * 100).roundToDouble() / 100;

  static String _catDe(Producto p) =>
      p.categoria.trim().isEmpty ? sinCategoria : p.categoria.trim();

  static String _etiquetaSuc(String s) =>
      s.trim().isEmpty ? 'Sin sucursal' : etiquetaSucursal(s);

  static final DateFormat _fDia = DateFormat('dd/MM/yyyy');
  static final DateFormat _fHora = DateFormat('dd/MM/yyyy HH:mm');

  // Líneas de venta filtradas
  static ({List<LineaVenta> lineas, int sinFecha, int totalDistinto})
      lineasDeVentas(DatosReporte d, FiltrosReporte f, TipoReporte tipo) {
    final catPorCodigo = <String, String>{};
    final catPorNombre = <String, String>{};
    for (final p in d.productos) {
      final c = _catDe(p);
      if (p.codigo.trim().isNotEmpty) catPorCodigo.putIfAbsent(p.codigo.trim(), () => c);
      if (p.nombre.trim().isNotEmpty) catPorNombre.putIfAbsent(norm(p.nombre), () => c);
    }

    final fSuc = f.activo(tipo, FiltroReporte.sucursal);
    final fEst = f.activo(tipo, FiltroReporte.estado);
    final fProd = f.activo(tipo, FiltroReporte.producto);
    final fCat = f.activo(tipo, FiltroReporte.categoria);
    final usaFechas = tipo.usa(FiltroReporte.fechas);

    final lineas = <LineaVenta>[];
    var sinFecha = 0;
    var totalDistinto = 0;

    for (final v in d.ventas) {
      if (fSuc && !mismaSucursal(v.sucursal, f.sucursal)) continue;
      if (fEst && norm(v.estado) != norm(f.estado)) continue;
      // Las ventas anuladas no cuentan, salvo que se filtre por ese estado
      if (!fEst && norm(v.estado) == 'inactivo') continue;
      if (usaFechas) {
        if (!v.fechaValida) {
          sinFecha++;
          continue;
        }
        if (!f.incluyeFecha(v.fecha)) continue;
      }

      final codigo = v.codigoV.isNotEmpty ? v.codigoV : v.id;

      if (v.items.isEmpty) {
        // Sin detalle no se filtra por producto
        if (fProd || fCat) continue;
        lineas.add(LineaVenta(
          ventaId: v.id, codigoVenta: codigo, fecha: v.fecha,
          sucursal: v.sucursal, estado: v.estado,
          producto: '(sin detalle)', categoria: sinCategoria,
          cantidad: 0, subtotal: r2(v.total), sinDetalle: true,
          cliente: v.cliente, vendedor: v.vendedorNombre,
        ));
        continue;
      }

      var agregadas = 0;
      var sumaLineas = 0.0;
      for (final i in v.items) {
        final categoria = catPorCodigo[i.codigo.trim()] ??
            catPorNombre[norm(i.nombre)] ??
            sinCategoria;
        if (fProd && norm(i.nombre) != norm(f.producto)) continue;
        if (fCat && norm(categoria) != norm(f.categoria)) continue;
        final sub = r2(i.subtotal);
        lineas.add(LineaVenta(
          ventaId: v.id, codigoVenta: codigo, fecha: v.fecha,
          sucursal: v.sucursal, estado: v.estado,
          producto: i.nombre.trim().isEmpty ? '(sin nombre)' : i.nombre.trim(),
          categoria: categoria, cantidad: i.cantidad, subtotal: sub,
          precioUnitario: i.precioUnitario,
          cliente: v.cliente, vendedor: v.vendedorNombre,
        ));
        agregadas++;
        sumaLineas += sub;
      }
      if (agregadas == v.items.length &&
          v.total != 0 &&
          (r2(sumaLineas) - r2(v.total)).abs() > 0.01) {
        totalDistinto++;
      }
    }
    return (lineas: lineas, sinFecha: sinFecha, totalDistinto: totalDistinto);
  }

  static TablaReporte construir(
      TipoReporte tipo, FiltrosReporte f, DatosReporte d) {
    switch (tipo) {
      case TipoReporte.ventasDetalle:
        return _ventasDetalle(tipo, f, d);
      case TipoReporte.ventasPorDia:
      case TipoReporte.ventasPorSemana:
      case TipoReporte.ventasPorMes:
        return _ventasPorPeriodo(tipo, f, d);
      case TipoReporte.ventasPorSucursal:
        return _ventasPorSucursal(tipo, f, d);
      case TipoReporte.ventasPorProducto:
      case TipoReporte.productosMasVendidos:
      case TipoReporte.productosMenosVendidos:
        return _ventasPorProducto(tipo, f, d);
      case TipoReporte.catalogoProductos:
        return _catalogo(tipo, f, d);
      case TipoReporte.existencias:
        return _existencias(tipo, f, d);
      case TipoReporte.stockBajo:
        return _stockBajo(tipo, f, d);
      case TipoReporte.agotados:
        return _agotados(tipo, f, d);
      case TipoReporte.productosPorCategoria:
        return _porCategoria(tipo, f, d);
      case TipoReporte.inventarioPorSucursal:
        return _porSucursalInv(tipo, f, d);
      case TipoReporte.comparacionExistencias:
        return _comparacion(tipo, f, d);
      case TipoReporte.movimientosInventario:
        return _movimientos(tipo, f, d);
      case TipoReporte.resumenGeneral:
        return _resumenGeneral(tipo, f, d);
      case TipoReporte.disponibilidadProductos:
        return _disponibilidad(tipo, f, d);
      case TipoReporte.auditoria:
        return _auditoria(tipo, f, d);
    }
  }

  static TablaReporte _tabla(
    TipoReporte tipo,
    FiltrosReporte f,
    DatosReporte d,
    List<ColumnaReporte> columnas,
    List<List<Object?>> filas, {
    List<Object?>? totales,
    List<DetalleReporte?> detalles = const [],
    List<Indicador> resumen = const [],
    List<String> advertencias = const [],
  }) {
    final adv = [...advertencias];
    if (d.documentosOmitidos > 0) {
      adv.add('${d.documentosOmitidos} documento(s) con datos ilegibles se omitieron.');
    }
    return TablaReporte(
      tipo: tipo,
      columnas: columnas,
      filas: filas,
      totales: filas.isEmpty ? null : totales,
      detalles: filas.isEmpty ? const [] : detalles,
      resumen: filas.isEmpty ? const [] : resumen,
      filtrosAplicados: f.descripcion(tipo),
      advertencias: adv,
      generadoEn: d.ahora,
    );
  }

  static List<String> _advVentas(
          ({List<LineaVenta> lineas, int sinFecha, int totalDistinto}) r) =>
      [
        if (r.sinFecha > 0)
          '${r.sinFecha} venta(s) sin fecha válida se omitieron del período.',
        if (r.totalDistinto > 0)
          '${r.totalDistinto} venta(s) tienen un total guardado distinto a la suma de sus productos; '
              'el reporte usa la suma de los productos.',
      ];

  // Detalle: cada venta con sus productos
  static DetalleReporte? _detalleVentas(List<LineaVenta> lineas, String titulo) {
    if (lineas.isEmpty) return null;
    final porVenta = <String, List<LineaVenta>>{};
    for (final l in lineas) {
      porVenta.putIfAbsent(l.ventaId, () => []).add(l);
    }
    final ventas = porVenta.values.toList()
      ..sort((a, b) {
        final c = a.first.fecha.compareTo(b.first.fecha);
        return c != 0 ? c : a.first.codigoVenta.compareTo(b.first.codigoVenta);
      });

    final filas = <List<Object?>>[];
    final subtotales = <int>{};
    var cantTotal = 0.0;
    var impTotal = 0.0;
    for (final g in ventas) {
      final h = g.first;
      var cant = 0.0;
      var imp = 0.0;
      for (var i = 0; i < g.length; i++) {
        final l = g[i];
        cant += l.cantidad;
        imp += l.subtotal;
        filas.add([
          i == 0 ? h.codigoVenta : '',
          i == 0 ? _fHora.format(h.fecha) : '',
          i == 0 ? _etiquetaSuc(h.sucursal) : '',
          l.producto,
          l.sinDetalle ? null : l.cantidad,
          l.sinDetalle ? null : r2(l.precioUnitario),
          l.subtotal,
        ]);
      }
      cantTotal += cant;
      impTotal += imp;
      // Total de cada venta
      subtotales.add(filas.length);
      filas.add(['', '', '', 'Total de la venta', cant, null, r2(imp)]);
    }
    if (ventas.length > 1) {
      subtotales.add(filas.length);
      filas.add([
        '', '', '', 'TOTAL (${ventas.length} ventas)', cantTotal, null, r2(impTotal),
      ]);
    }
    return DetalleReporte(
      titulo: titulo,
      columnas: const [
        ColumnaReporte('Venta'),
        ColumnaReporte('Fecha y hora'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Cantidad', TipoColumna.cantidad),
        ColumnaReporte('Precio (C\$)', TipoColumna.moneda),
        ColumnaReporte('Subtotal (C\$)', TipoColumna.moneda),
      ],
      filas: filas,
      subtotales: subtotales,
    );
  }

  // Detalle: ventas donde se vendió un producto
  static DetalleReporte? _detalleProducto(List<LineaVenta> lineas, String titulo) {
    if (lineas.isEmpty) return null;
    final ls = [...lineas]..sort((a, b) => a.fecha.compareTo(b.fecha));
    var cant = 0.0;
    var imp = 0.0;
    final filas = <List<Object?>>[];
    for (final l in ls) {
      cant += l.cantidad;
      imp += l.subtotal;
      filas.add([
        _fHora.format(l.fecha), l.codigoVenta, _etiquetaSuc(l.sucursal),
        l.cantidad, r2(l.precioUnitario), l.subtotal,
      ]);
    }
    final subtotales = <int>{};
    if (ls.length > 1) {
      subtotales.add(filas.length);
      filas.add(['', '', 'Total', cant, null, r2(imp)]);
    }
    return DetalleReporte(
      titulo: titulo,
      columnas: const [
        ColumnaReporte('Fecha y hora'),
        ColumnaReporte('Venta'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Cantidad', TipoColumna.cantidad),
        ColumnaReporte('Precio (C\$)', TipoColumna.moneda),
        ColumnaReporte('Subtotal (C\$)', TipoColumna.moneda),
      ],
      filas: filas,
      subtotales: subtotales,
    );
  }

  // Detalle: ingredientes de un producto
  static DetalleReporte? _detalleIngredientes(Producto p) {
    if (p.ingredientes.isEmpty) return null;
    return DetalleReporte(
      titulo: 'Ingredientes de ${p.nombre}',
      columnas: const [ColumnaReporte('Ingrediente'), ColumnaReporte('Cantidad')],
      filas: [
        for (final i in p.ingredientes) [i.nombre, i.cantidad],
      ],
    );
  }

  // Detalle: lista de productos
  static DetalleReporte? _detalleProductos(
    List<Producto> lista,
    String titulo, {
    bool conValor = false,
    String? dimTitulo,
    String Function(Producto)? dim,
  }) {
    if (lista.isEmpty) return null;
    final ps = [...lista]
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final columnas = <ColumnaReporte>[
      const ColumnaReporte('Código'),
      const ColumnaReporte('Producto'),
      if (dim != null)
        ColumnaReporte(dimTitulo ?? '')
      else ...const [ColumnaReporte('Categoría'), ColumnaReporte('Sucursal')],
      const ColumnaReporte('Stock', TipoColumna.entero),
      const ColumnaReporte('Stock mínimo', TipoColumna.entero),
      if (conValor) ...const [
        ColumnaReporte('Precio (C\$)', TipoColumna.moneda),
        ColumnaReporte('Valor (C\$)', TipoColumna.moneda),
      ],
      const ColumnaReporte('Situación'),
    ];
    final filas = <List<Object?>>[
      for (final p in ps)
        [
          p.codigo,
          p.nombre,
          if (dim != null) dim(p) else ...[_catDe(p), _etiquetaSuc(p.sucursal)],
          p.stock,
          p.stockMinimo,
          if (conValor) ...[r2(p.precio), r2(p.stock > 0 ? p.stock * p.precio : 0.0)],
          situacion(p),
        ],
    ];
    final subtotales = <int>{};
    if (conValor) {
      final uni = ps.fold<int>(0, (s, p) => s + p.stock);
      final val = r2(ps.fold<double>(0, (s, p) => s + (p.stock > 0 ? p.stock * p.precio : 0.0)));
      subtotales.add(filas.length);
      filas.add([
        '', 'Total (${ps.length})',
        if (dim != null) '' else ...['', ''],
        uni, null, null, val, '',
      ]);
    }
    return DetalleReporte(
      titulo: titulo,
      columnas: columnas,
      filas: filas,
      subtotales: subtotales,
    );
  }

  static TablaReporte _ventasDetalle(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final r = lineasDeVentas(d, f, t);
    final porVenta = <String, List<LineaVenta>>{};
    for (final l in r.lineas) {
      porVenta.putIfAbsent(l.ventaId, () => []).add(l);
    }
    final grupos = porVenta.values.toList()
      ..sort((a, b) => b.first.fecha.compareTo(a.first.fecha));

    var sumProd = 0;
    var sumCant = 0.0;
    var sumImp = 0.0;
    final filas = <List<Object?>>[];
    final detalles = <DetalleReporte?>[];
    for (final g in grupos) {
      final h = g.first;
      final prod = g.where((l) => !l.sinDetalle).length;
      final cant = g.fold<double>(0, (s, l) => s + l.cantidad);
      final imp = r2(g.fold<double>(0, (s, l) => s + l.subtotal));
      sumProd += prod;
      sumCant += cant;
      sumImp += imp;
      filas.add([
        _fHora.format(h.fecha),
        h.codigoVenta,
        _etiquetaSuc(h.sucursal),
        h.vendedor.trim().isEmpty ? '-' : h.vendedor.trim(),
        h.cliente.trim().isEmpty ? '-' : h.cliente.trim(),
        h.estado,
        prod,
        cant,
        imp,
      ]);
      // Productos de la venta
      detalles.add(DetalleReporte(
        titulo: 'Productos de la venta ${h.codigoVenta}',
        columnas: const [
          ColumnaReporte('Producto'),
          ColumnaReporte('Categoría'),
          ColumnaReporte('Cantidad', TipoColumna.cantidad),
          ColumnaReporte('Precio unitario (C\$)', TipoColumna.moneda),
          ColumnaReporte('Subtotal (C\$)', TipoColumna.moneda),
        ],
        filas: [
          for (final l in g)
            [
              l.producto,
              l.categoria,
              l.sinDetalle ? null : l.cantidad,
              l.sinDetalle ? null : r2(l.precioUnitario),
              l.subtotal,
            ],
        ],
      ));
    }
    sumImp = r2(sumImp);
    final n = grupos.length;
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Fecha'),
        ColumnaReporte('Código'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Vendedor'),
        ColumnaReporte('Cliente'),
        ColumnaReporte('Estado'),
        ColumnaReporte('Productos', TipoColumna.entero),
        ColumnaReporte('Unidades', TipoColumna.cantidad),
        ColumnaReporte('Importe (C\$)', TipoColumna.moneda),
      ],
      filas,
      totales: [
        'TOTAL ($n ventas)', null, null, null, null, null,
        sumProd, sumCant, sumImp,
      ],
      detalles: detalles,
      resumen: [
        Indicador('Ventas', TablaReporte.formatearEntero(n)),
        Indicador('Unidades', TablaReporte.formatearCantidad(sumCant)),
        Indicador('Importe total', TablaReporte.formatearMoneda(sumImp)),
        Indicador('Promedio por venta',
            TablaReporte.formatearMoneda(n == 0 ? 0 : r2(sumImp / n))),
      ],
      advertencias: _advVentas(r),
    );
  }

  static TablaReporte _ventasPorPeriodo(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final r = lineasDeVentas(d, f, t);
    String clave(LineaVenta l) {
      final x = l.fecha;
      switch (t) {
        case TipoReporte.ventasPorSemana:
          final lunes = DateTime(x.year, x.month, x.day - (x.weekday - 1));
          return DateFormat('yyyy-MM-dd').format(lunes);
        case TipoReporte.ventasPorMes:
          return DateFormat('yyyy-MM').format(x);
        default:
          return DateFormat('yyyy-MM-dd').format(x);
      }
    }

    String etiqueta(LineaVenta l) {
      final x = l.fecha;
      switch (t) {
        case TipoReporte.ventasPorSemana:
          final lunes = DateTime(x.year, x.month, x.day - (x.weekday - 1));
          final dom = DateTime(lunes.year, lunes.month, lunes.day + 6);
          return '${_fDia.format(lunes)} al ${_fDia.format(dom)}';
        case TipoReporte.ventasPorMes:
          return '${_meses[x.month - 1]} ${x.year}';
        default:
          return _fDia.format(x);
      }
    }

    final g = _agrupar(r.lineas, clave, etiqueta);
    final claves = g.keys.toList()..sort();
    return _tablaAgrupadaVentas(t, f, d, r, 'Período', claves.map((k) => g[k]!).toList(),
        conPorcentaje: true);
  }

  static TablaReporte _ventasPorSucursal(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final r = lineasDeVentas(d, f, t);
    final g = _agrupar(r.lineas, (l) => normSucursal(l.sucursal),
        (l) => _etiquetaSuc(l.sucursal));
    final lista = g.values.toList()..sort((a, b) => b.importe.compareTo(a.importe));
    return _tablaAgrupadaVentas(t, f, d, r, 'Sucursal', lista, conPorcentaje: true);
  }

  static Map<String, _Acum> _agrupar(
    Iterable<LineaVenta> lineas,
    String Function(LineaVenta) clave,
    String Function(LineaVenta) etiqueta,
  ) {
    final m = <String, _Acum>{};
    for (final l in lineas) {
      final a = m.putIfAbsent(clave(l), () => _Acum(etiqueta(l)));
      a.ventas.add(l.ventaId);
      a.lineas.add(l);
      a.cantidad += l.cantidad;
      a.importe += l.subtotal;
    }
    return m;
  }

  // Tabla agrupada de ventas
  static TablaReporte _tablaAgrupadaVentas(
    TipoReporte t,
    FiltrosReporte f,
    DatosReporte d,
    ({List<LineaVenta> lineas, int sinFecha, int totalDistinto}) r,
    String titulo,
    List<_Acum> grupos, {
    bool conPorcentaje = false,
  }) {
    final totalImp = r2(grupos.fold<double>(0, (s, a) => s + a.importe));
    final totalVentas = grupos.fold<int>(0, (s, a) => s + a.ventas.length);
    final totalCant = grupos.fold<double>(0, (s, a) => s + a.cantidad);

    final filas = <List<Object?>>[
      for (final a in grupos)
        [
          a.etiqueta,
          a.ventas.length,
          a.cantidad,
          r2(a.importe),
          r2(a.importe / a.ventas.length),
          if (conPorcentaje) (totalImp == 0 ? 0.0 : a.importe / totalImp * 100),
        ],
    ];
    // Cada grupo con sus ventas y productos
    final detalles = <DetalleReporte?>[
      for (final a in grupos) _detalleVentas(a.lineas, 'Ventas de ${a.etiqueta}'),
    ];
    final mejor = grupos.isEmpty
        ? null
        : grupos.reduce((a, b) => b.importe > a.importe ? b : a);
    return _tabla(
      t, f, d,
      [
        ColumnaReporte(titulo),
        const ColumnaReporte('N° de ventas', TipoColumna.entero),
        const ColumnaReporte('Unidades', TipoColumna.cantidad),
        const ColumnaReporte('Importe (C\$)', TipoColumna.moneda),
        const ColumnaReporte('Promedio por venta (C\$)', TipoColumna.moneda),
        if (conPorcentaje) const ColumnaReporte('% del total', TipoColumna.porcentaje),
      ],
      filas,
      totales: [
        'TOTAL',
        totalVentas,
        totalCant,
        totalImp,
        totalVentas == 0 ? 0.0 : r2(totalImp / totalVentas),
        if (conPorcentaje) 100.0,
      ],
      detalles: detalles,
      resumen: [
        Indicador('Ventas', TablaReporte.formatearEntero(totalVentas)),
        Indicador('Unidades', TablaReporte.formatearCantidad(totalCant)),
        Indicador('Importe total', TablaReporte.formatearMoneda(totalImp)),
        Indicador('Promedio por venta',
            TablaReporte.formatearMoneda(totalVentas == 0 ? 0 : r2(totalImp / totalVentas))),
        if (mejor != null)
          Indicador('Mayor importe',
              '${mejor.etiqueta}: ${TablaReporte.formatearMoneda(r2(mejor.importe))}'),
      ],
      advertencias: _advVentas(r),
    );
  }

  static TablaReporte _ventasPorProducto(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final r = lineasDeVentas(d, f, t);
    final conDetalle = r.lineas.where((l) => !l.sinDetalle).toList();
    final sinDetalle =
        r.lineas.where((l) => l.sinDetalle).map((l) => l.ventaId).toSet().length;

    final g = _agrupar(conDetalle, (l) => norm(l.producto), (l) => l.producto);
    for (final l in conDetalle) {
      g[norm(l.producto)]!.extra = l.categoria;
    }
    var lista = g.values.toList();
    // Importe de todos los productos (base del porcentaje)
    final importeGeneral = r2(lista.fold<double>(0, (s, a) => s + a.importe));

    int porImporte(_Acum a, _Acum b) {
      final c = b.importe.compareTo(a.importe);
      return c != 0 ? c : a.etiqueta.compareTo(b.etiqueta);
    }

    int porCantidad(_Acum a, _Acum b, {required bool desc}) {
      final c = desc ? b.cantidad.compareTo(a.cantidad) : a.cantidad.compareTo(b.cantidad);
      return c != 0 ? c : porImporte(a, b);
    }

    final ranking = t != TipoReporte.ventasPorProducto;
    if (t == TipoReporte.productosMasVendidos) {
      lista.sort((a, b) => porCantidad(a, b, desc: true));
      lista = lista.take(10).toList();
    } else if (t == TipoReporte.productosMenosVendidos) {
      lista.sort((a, b) => porCantidad(a, b, desc: false));
      lista = lista.take(10).toList();
    } else {
      lista.sort(porImporte);
    }

    final totalCant = lista.fold<double>(0, (s, a) => s + a.cantidad);
    final totalImp = r2(lista.fold<double>(0, (s, a) => s + a.importe));
    final filas = <List<Object?>>[
      for (var i = 0; i < lista.length; i++)
        [
          if (ranking) i + 1,
          lista[i].etiqueta,
          lista[i].extra,
          lista[i].cantidad,
          lista[i].ventas.length,
          lista[i].cantidad == 0 ? 0.0 : r2(lista[i].importe / lista[i].cantidad),
          r2(lista[i].importe),
          importeGeneral == 0 ? 0.0 : lista[i].importe / importeGeneral * 100,
        ],
    ];
    // Cada producto con las ventas donde salió
    final detalles = <DetalleReporte?>[
      for (final a in lista) _detalleProducto(a.lineas, 'Ventas de ${a.etiqueta}'),
    ];
    final etiquetaTotal = ranking ? 'TOTAL (${lista.length} productos)' : 'TOTAL';
    return _tabla(
      t, f, d,
      [
        if (ranking) const ColumnaReporte('#', TipoColumna.entero),
        const ColumnaReporte('Producto'),
        const ColumnaReporte('Categoría'),
        const ColumnaReporte('Unidades', TipoColumna.cantidad),
        const ColumnaReporte('N° de ventas', TipoColumna.entero),
        const ColumnaReporte('Precio promedio (C\$)', TipoColumna.moneda),
        const ColumnaReporte('Importe (C\$)', TipoColumna.moneda),
        const ColumnaReporte('% del importe', TipoColumna.porcentaje),
      ],
      filas,
      totales: [
        if (ranking) null,
        etiquetaTotal,
        null,
        totalCant,
        null,
        null,
        totalImp,
        importeGeneral == 0 ? 0.0 : totalImp / importeGeneral * 100,
      ],
      detalles: detalles,
      resumen: [
        Indicador(ranking ? 'Productos mostrados' : 'Productos vendidos',
            TablaReporte.formatearEntero(lista.length)),
        Indicador('Unidades', TablaReporte.formatearCantidad(totalCant)),
        Indicador('Importe', TablaReporte.formatearMoneda(totalImp)),
      ],
      advertencias: [
        ..._advVentas(r),
        if (sinDetalle > 0)
          '$sinDetalle venta(s) sin detalle de productos no se incluyen en este reporte.',
      ],
    );
  }

  static List<Producto> _prodFiltrados(DatosReporte d, FiltrosReporte f, TipoReporte t) {
    final fSuc = f.activo(t, FiltroReporte.sucursal);
    final fProd = f.activo(t, FiltroReporte.producto);
    final fCat = f.activo(t, FiltroReporte.categoria);
    final fEst = f.activo(t, FiltroReporte.estado);
    final l = d.productos.where((p) {
      if (fSuc && !mismaSucursal(p.sucursal, f.sucursal)) return false;
      if (fProd && norm(p.nombre) != norm(f.producto)) return false;
      if (fCat && norm(_catDe(p)) != norm(f.categoria)) return false;
      if (fEst && norm(p.estado) != norm(f.estado)) return false;
      return true;
    }).toList();
    l.sort((a, b) {
      final c = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      return c != 0 ? c : a.sucursal.compareTo(b.sucursal);
    });
    return l;
  }

  static String situacion(Producto p) =>
      p.stock <= 0 ? 'Agotado' : (p.stock <= p.stockMinimo ? 'Stock bajo' : 'Disponible');

  static TablaReporte _catalogo(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final activos = ps.where((p) => norm(p.estado) == 'activo').length;
    final sinIng = ps.where((p) => p.ingredientes.isEmpty).length;
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Código'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Categoría'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Precio (C\$)', TipoColumna.moneda),
        ColumnaReporte('Stock', TipoColumna.entero),
        ColumnaReporte('Estado'),
        ColumnaReporte('Ingredientes', TipoColumna.entero),
      ],
      [
        for (final p in ps)
          [
            p.codigo, p.nombre, _catDe(p), _etiquetaSuc(p.sucursal),
            r2(p.precio), p.stock, p.estado, p.ingredientes.length,
          ],
      ],
      detalles: [for (final p in ps) _detalleIngredientes(p)],
      resumen: [
        Indicador('Productos', TablaReporte.formatearEntero(ps.length)),
        Indicador('Activos', TablaReporte.formatearEntero(activos)),
        Indicador('Inactivos', TablaReporte.formatearEntero(ps.length - activos)),
        Indicador('Sin ingredientes', TablaReporte.formatearEntero(sinIng)),
      ],
    );
  }

  static TablaReporte _existencias(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final unidades = ps.fold<int>(0, (s, p) => s + p.stock);
    final valor = r2(ps.fold<double>(0, (s, p) => s + (p.stock > 0 ? p.stock * p.precio : 0.0)));
    final ago = ps.where((p) => p.stock <= 0).length;
    final bajo = ps.where((p) => p.stock > 0 && p.stock <= p.stockMinimo).length;
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Código'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Categoría'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Precio (C\$)', TipoColumna.moneda),
        ColumnaReporte('Stock', TipoColumna.entero),
        ColumnaReporte('Stock mínimo', TipoColumna.entero),
        ColumnaReporte('Dif. vs mínimo', TipoColumna.entero),
        ColumnaReporte('Valor en stock (C\$)', TipoColumna.moneda),
        ColumnaReporte('Situación'),
      ],
      [
        for (final p in ps)
          [
            p.codigo, p.nombre, _catDe(p), _etiquetaSuc(p.sucursal), r2(p.precio),
            p.stock, p.stockMinimo, p.stock - p.stockMinimo,
            r2(p.stock > 0 ? p.stock * p.precio : 0.0), situacion(p),
          ],
      ],
      totales: ['TOTAL', null, null, null, null, unidades, null, null, valor, null],
      detalles: [for (final p in ps) _detalleIngredientes(p)],
      resumen: [
        Indicador('Productos', TablaReporte.formatearEntero(ps.length)),
        Indicador('Unidades en stock', TablaReporte.formatearEntero(unidades)),
        Indicador('Valor del inventario', TablaReporte.formatearMoneda(valor)),
        Indicador('Stock bajo', TablaReporte.formatearEntero(bajo)),
        Indicador('Agotados', TablaReporte.formatearEntero(ago)),
      ],
      advertencias: const [
        'Valor en stock = stock x precio de venta. Dif. vs mínimo negativa = por debajo del mínimo.',
      ],
    );
  }

  static TablaReporte _stockBajo(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t)
        .where((p) => p.stock > 0 && p.stock <= p.stockMinimo)
        .toList()
      ..sort((a, b) => (b.stockMinimo - b.stock).compareTo(a.stockMinimo - a.stock));
    final unidades = ps.fold<int>(0, (s, p) => s + p.stock);
    final faltante = ps.fold<int>(0, (s, p) => s + (p.stockMinimo - p.stock));
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Código'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Categoría'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Precio (C\$)', TipoColumna.moneda),
        ColumnaReporte('Stock', TipoColumna.entero),
        ColumnaReporte('Stock mínimo', TipoColumna.entero),
        ColumnaReporte('Faltante', TipoColumna.entero),
        ColumnaReporte('% del mínimo', TipoColumna.porcentaje),
      ],
      [
        for (final p in ps)
          [
            p.codigo, p.nombre, _catDe(p), _etiquetaSuc(p.sucursal), r2(p.precio),
            p.stock, p.stockMinimo, p.stockMinimo - p.stock,
            p.stockMinimo == 0 ? 0.0 : p.stock / p.stockMinimo * 100,
          ],
      ],
      totales: ['TOTAL', null, null, null, null, unidades, null, faltante, null],
      // Ingredientes para reponer
      detalles: [for (final p in ps) _detalleIngredientes(p)],
      resumen: [
        Indicador('Productos con stock bajo', TablaReporte.formatearEntero(ps.length)),
        Indicador('Unidades en stock', TablaReporte.formatearEntero(unidades)),
        Indicador('Unidades faltantes', TablaReporte.formatearEntero(faltante)),
      ],
    );
  }

  static TablaReporte _agotados(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t).where((p) => p.stock <= 0).toList();
    final activos = ps.where((p) => norm(p.estado) == 'activo').length;
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Código'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Categoría'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Precio (C\$)', TipoColumna.moneda),
        ColumnaReporte('Stock mínimo', TipoColumna.entero),
        ColumnaReporte('Estado'),
        ColumnaReporte('Ingredientes', TipoColumna.entero),
      ],
      [
        for (final p in ps)
          [
            p.codigo, p.nombre, _catDe(p), _etiquetaSuc(p.sucursal), r2(p.precio),
            p.stockMinimo, p.estado, p.ingredientes.length,
          ],
      ],
      detalles: [for (final p in ps) _detalleIngredientes(p)],
      resumen: [
        Indicador('Productos agotados', TablaReporte.formatearEntero(ps.length)),
        Indicador('Agotados activos', TablaReporte.formatearEntero(activos)),
      ],
    );
  }

  static TablaReporte _porCategoria(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final g = <String, List<Producto>>{};
    for (final p in ps) {
      g.putIfAbsent(_catDe(p), () => []).add(p);
    }
    final claves = g.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _tablaInv(t, f, d, 'Categoría', claves, g, 'Sucursal',
        (p) => _etiquetaSuc(p.sucursal));
  }

  static TablaReporte _porSucursalInv(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final g = <String, List<Producto>>{};
    for (final p in ps) {
      g.putIfAbsent(_etiquetaSuc(p.sucursal), () => []).add(p);
    }
    final claves = g.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _tablaInv(t, f, d, 'Sucursal', claves, g, 'Categoría', _catDe);
  }

  static TablaReporte _tablaInv(TipoReporte t, FiltrosReporte f, DatosReporte d,
      String titulo, List<String> claves, Map<String, List<Producto>> g,
      String dimTitulo, String Function(Producto) dim) {
    double valorDe(List<Producto> l) => r2(
        l.fold<double>(0, (s, p) => s + (p.stock > 0 ? p.stock * p.precio : 0.0)));
    final valorTotal = r2(claves.fold<double>(0, (s, k) => s + valorDe(g[k]!)));

    var nProd = 0, uni = 0, disp = 0, bajo = 0, ago = 0;
    final filas = <List<Object?>>[];
    final detalles = <DetalleReporte?>[];
    for (final k in claves) {
      final l = g[k]!;
      final u = l.fold<int>(0, (s, p) => s + p.stock);
      final v = valorDe(l);
      final b = l.where((p) => p.stock > 0 && p.stock <= p.stockMinimo).length;
      final a = l.where((p) => p.stock <= 0).length;
      final di = l.length - a - b;
      nProd += l.length;
      uni += u;
      disp += di;
      bajo += b;
      ago += a;
      filas.add([
        k, l.length, u, v, di, b, a,
        valorTotal == 0 ? 0.0 : v / valorTotal * 100,
      ]);
      // Productos del grupo
      detalles.add(_detalleProductos(l, 'Productos de $k',
          conValor: true, dimTitulo: dimTitulo, dim: dim));
    }
    return _tabla(
      t, f, d,
      [
        ColumnaReporte(titulo),
        const ColumnaReporte('Productos', TipoColumna.entero),
        const ColumnaReporte('Unidades en stock', TipoColumna.entero),
        const ColumnaReporte('Valor de inventario (C\$)', TipoColumna.moneda),
        const ColumnaReporte('Disponibles', TipoColumna.entero),
        const ColumnaReporte('Stock bajo', TipoColumna.entero),
        const ColumnaReporte('Agotados', TipoColumna.entero),
        const ColumnaReporte('% del valor', TipoColumna.porcentaje),
      ],
      filas,
      totales: ['TOTAL', nProd, uni, valorTotal, disp, bajo, ago, valorTotal == 0 ? 0.0 : 100.0],
      detalles: detalles,
      resumen: [
        Indicador('Productos', TablaReporte.formatearEntero(nProd)),
        Indicador('Unidades', TablaReporte.formatearEntero(uni)),
        Indicador('Valor de inventario', TablaReporte.formatearMoneda(valorTotal)),
        Indicador('Stock bajo', TablaReporte.formatearEntero(bajo)),
        Indicador('Agotados', TablaReporte.formatearEntero(ago)),
      ],
      advertencias: const [
        'Valor de inventario = stock x precio de venta de cada producto.',
      ],
    );
  }

  static TablaReporte _comparacion(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final sucs = <String, String>{}; // norm -> etiqueta
    for (final p in ps) {
      sucs.putIfAbsent(normSucursal(p.sucursal), () => _etiquetaSuc(p.sucursal));
    }
    final clavesSuc = sucs.keys.toList()
      ..sort((a, b) => sucs[a]!.toLowerCase().compareTo(sucs[b]!.toLowerCase()));

    final porProd = <String, Map<String, int>>{};
    final nombre = <String, String>{};
    for (final p in ps) {
      final k = norm(p.nombre);
      nombre.putIfAbsent(k, () => p.nombre.trim());
      final m = porProd.putIfAbsent(k, () => {});
      final s = normSucursal(p.sucursal);
      m[s] = (m[s] ?? 0) + p.stock;
    }
    final claves = porProd.keys.toList()
      ..sort((a, b) => nombre[a]!.toLowerCase().compareTo(nombre[b]!.toLowerCase()));

    final sumas = {for (final s in clavesSuc) s: 0};
    var granTotal = 0;
    final filas = <List<Object?>>[];
    for (final k in claves) {
      final m = porProd[k]!;
      var tot = 0;
      final fila = <Object?>[nombre[k]];
      for (final s in clavesSuc) {
        final v = m[s];
        fila.add(v);
        if (v != null) {
          tot += v;
          sumas[s] = sumas[s]! + v;
        }
      }
      fila.add(tot);
      granTotal += tot;
      filas.add(fila);
    }
    return _tabla(
      t, f, d,
      [
        const ColumnaReporte('Producto'),
        for (final s in clavesSuc) ColumnaReporte(sucs[s]!, TipoColumna.entero),
        const ColumnaReporte('Total', TipoColumna.entero),
      ],
      filas,
      totales: ['TOTAL', for (final s in clavesSuc) sumas[s], granTotal],
      resumen: [
        Indicador('Productos', TablaReporte.formatearEntero(claves.length)),
        Indicador('Sucursales', TablaReporte.formatearEntero(clavesSuc.length)),
        Indicador('Unidades', TablaReporte.formatearEntero(granTotal)),
      ],
      advertencias: const [
        'Un guion (-) indica que el producto no está registrado en esa sucursal.',
      ],
    );
  }

  static TablaReporte _movimientos(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final fSuc = f.activo(t, FiltroReporte.sucursal);
    final fProd = f.activo(t, FiltroReporte.producto);
    final fCat = f.activo(t, FiltroReporte.categoria);
    final ms = d.movimientos.where((m) {
      if (!f.incluyeFecha(m.fecha)) return false;
      if (fSuc && !mismaSucursal(m.sucursal, f.sucursal)) return false;
      if (fProd && norm(m.producto) != norm(f.producto)) return false;
      if (fCat && norm(m.categoria) != norm(f.categoria)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final entradas = ms.where((m) => m.tipo == 'Entrada').fold<int>(0, (s, m) => s + m.cantidad);
    final salidas = ms.where((m) => m.tipo != 'Entrada').fold<int>(0, (s, m) => s + m.cantidad);
    final productos = ms.map((m) => norm(m.producto)).toSet().length;
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Fecha'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Categoría'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Tipo'),
        ColumnaReporte('Cantidad', TipoColumna.entero),
        ColumnaReporte('Stock anterior', TipoColumna.entero),
        ColumnaReporte('Stock nuevo', TipoColumna.entero),
        ColumnaReporte('Motivo'),
        ColumnaReporte('Autor'),
      ],
      [
        for (final m in ms)
          [
            _fHora.format(m.fecha), m.producto,
            m.categoria.trim().isEmpty ? sinCategoria : m.categoria.trim(),
            _etiquetaSuc(m.sucursal), m.tipo,
            m.cantidad, m.stockAnterior, m.stockNuevo, m.motivo, m.autor,
          ],
      ],
      resumen: [
        Indicador('Movimientos', TablaReporte.formatearEntero(ms.length)),
        Indicador('Productos distintos', TablaReporte.formatearEntero(productos)),
        Indicador('Entradas (unid.)', TablaReporte.formatearEntero(entradas)),
        Indicador('Salidas (unid.)', TablaReporte.formatearEntero(salidas)),
        Indicador('Saldo neto (unid.)', TablaReporte.formatearEntero(entradas - salidas)),
      ],
    );
  }

  static TablaReporte _resumenGeneral(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final r = lineasDeVentas(d, f, t);
    final ventasIds = r.lineas.map((l) => l.ventaId).toSet();
    final importe = r2(r.lineas.fold<double>(0, (s, l) => s + l.subtotal));
    final ps = _prodFiltrados(d, f, t);
    final lAgo = ps.where((p) => p.stock <= 0).toList();
    final lBajo = ps.where((p) => p.stock > 0 && p.stock <= p.stockMinimo).toList();
    final activos = ps.where((p) => norm(p.estado) == 'activo').length;

    final filas = <List<Object?>>[];
    final detalles = <DetalleReporte?>[];
    void agregar(String concepto, String valor, [DetalleReporte? det]) {
      filas.add([concepto, valor]);
      detalles.add(det);
    }

    final adv = <String>[..._advVentas(r)];
    if (ventasIds.isNotEmpty) {
      // Ventas por sucursal
      DetalleReporte? detSuc;
      final porSuc = _agrupar(
          r.lineas, (l) => normSucursal(l.sucursal), (l) => _etiquetaSuc(l.sucursal));
      if (porSuc.length > 1) {
        final lista = porSuc.values.toList()..sort((a, b) => b.importe.compareTo(a.importe));
        detSuc = DetalleReporte(
          titulo: 'Ventas por sucursal',
          columnas: const [
            ColumnaReporte('Sucursal'),
            ColumnaReporte('Ventas', TipoColumna.entero),
            ColumnaReporte('Importe (C\$)', TipoColumna.moneda),
            ColumnaReporte('% del total', TipoColumna.porcentaje),
          ],
          filas: [
            for (final a in lista)
              [
                a.etiqueta, a.ventas.length, r2(a.importe),
                importe == 0 ? 0.0 : a.importe / importe * 100,
              ],
          ],
        );
      }
      agregar('Ventas en el período', TablaReporte.formatearEntero(ventasIds.length));
      agregar('Importe vendido', TablaReporte.formatearMoneda(importe), detSuc);
      agregar('Promedio por venta',
          TablaReporte.formatearMoneda(r2(importe / ventasIds.length)));
      agregar('Unidades vendidas',
          TablaReporte.formatearCantidad(r.lineas.fold<double>(0, (s, l) => s + l.cantidad)));

      // Venta más alta
      final porVenta = <String, double>{};
      final codigoDe = <String, String>{};
      for (final l in r.lineas) {
        porVenta[l.ventaId] = (porVenta[l.ventaId] ?? 0) + l.subtotal;
        codigoDe[l.ventaId] = l.codigoVenta;
      }
      final mayor = porVenta.entries.reduce((a, b) => b.value > a.value ? b : a);
      agregar('Venta más alta',
          '${TablaReporte.formatearMoneda(r2(mayor.value))} (${codigoDe[mayor.key]})');

      // Mejor día, con sus ventas
      final porDia = _agrupar(r.lineas, (l) => DateFormat('yyyy-MM-dd').format(l.fecha),
          (l) => _fDia.format(l.fecha));
      final mejorDia = porDia.values.reduce((a, b) => b.importe > a.importe ? b : a);
      agregar(
          'Día con más ventas',
          '${mejorDia.etiqueta} (${TablaReporte.formatearMoneda(r2(mejorDia.importe))})',
          _detalleVentas(mejorDia.lineas, 'Ventas de ${mejorDia.etiqueta}'));

      // Productos más vendidos
      final conDet = r.lineas.where((l) => !l.sinDetalle).toList();
      if (conDet.isNotEmpty) {
        final porProd =
            _agrupar(conDet, (l) => norm(l.producto), (l) => l.producto).values.toList()
              ..sort((a, b) => b.cantidad.compareTo(a.cantidad));
        final top = porProd.first;
        agregar(
          'Producto más vendido',
          '${top.etiqueta} (${TablaReporte.formatearCantidad(top.cantidad)} unid.)',
          DetalleReporte(
            titulo: 'Top 5 productos más vendidos',
            columnas: const [
              ColumnaReporte('#', TipoColumna.entero),
              ColumnaReporte('Producto'),
              ColumnaReporte('Unidades', TipoColumna.cantidad),
              ColumnaReporte('Importe (C\$)', TipoColumna.moneda),
            ],
            filas: [
              for (var i = 0; i < porProd.length && i < 5; i++)
                [i + 1, porProd[i].etiqueta, porProd[i].cantidad, r2(porProd[i].importe)],
            ],
          ),
        );
      }

      final inactivas = r.lineas
          .where((l) => norm(l.estado) != 'activo')
          .map((l) => l.ventaId)
          .toSet()
          .length;
      if (inactivas > 0) {
        adv.add('Se están mostrando ventas anuladas o inactivas ($inactivas).');
      }
    } else {
      adv.add('No hubo ventas en el período seleccionado.');
    }

    if (ps.isNotEmpty) {
      final unidades = ps.fold<int>(0, (s, p) => s + p.stock);
      final valor = r2(ps.fold<double>(0, (s, p) => s + (p.stock > 0 ? p.stock * p.precio : 0.0)));
      agregar('Productos registrados', TablaReporte.formatearEntero(ps.length));
      agregar('Productos activos', TablaReporte.formatearEntero(activos));
      agregar('Unidades en stock', TablaReporte.formatearEntero(unidades));
      agregar('Valor del inventario', TablaReporte.formatearMoneda(valor));
      agregar('Productos con stock bajo', TablaReporte.formatearEntero(lBajo.length),
          _detalleProductos(lBajo, 'Productos con stock bajo'));
      agregar('Productos agotados', TablaReporte.formatearEntero(lAgo.length),
          _detalleProductos(lAgo, 'Productos agotados'));
    }
    if (!f.activo(t, FiltroReporte.sucursal) && d.sucursales.isNotEmpty) {
      agregar('Sucursales registradas', TablaReporte.formatearEntero(d.sucursales.length));
      agregar('Sucursales activas',
          TablaReporte.formatearEntero(d.sucursales.where((s) => s.activo).length));
    }
    return _tabla(
      t, f, d,
      const [ColumnaReporte('Indicador'), ColumnaReporte('Valor')],
      filas,
      detalles: detalles,
      advertencias: adv,
    );
  }

  static TablaReporte _disponibilidad(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final lAct = ps.where((p) => norm(p.estado) == 'activo').toList();
    final lInact = ps.where((p) => norm(p.estado) != 'activo').toList();
    final lAgo = ps.where((p) => p.stock <= 0).toList();
    final lBajo = ps.where((p) => p.stock > 0 && p.stockMinimo >= p.stock).toList();
    final lDisp = ps.where((p) => p.stock > 0 && p.stockMinimo < p.stock).toList();

    double pct(int n) => ps.isEmpty ? 0.0 : n / ps.length * 100;
    final filas = <List<Object?>>[];
    final detalles = <DetalleReporte?>[];
    void agregar(String concepto, List<Producto> l, {bool detalle = true}) {
      filas.add([concepto, l.length, pct(l.length)]);
      detalles.add(detalle ? _detalleProductos(l, concepto) : null);
    }

    if (ps.isNotEmpty) {
      agregar('Productos registrados', ps, detalle: false);
      agregar('Activos', lAct);
      agregar('Inactivos', lInact);
      agregar('Disponibles (sobre el stock mínimo)', lDisp);
      agregar('Con stock bajo', lBajo);
      agregar('Agotados', lAgo);
    }
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Concepto'),
        ColumnaReporte('Productos', TipoColumna.entero),
        ColumnaReporte('% del total', TipoColumna.porcentaje),
      ],
      filas,
      detalles: detalles,
      advertencias: const [
        'Disponibilidad, stock bajo y agotados se calculan sobre todos los productos '
            'filtrados, estén activos o no.',
      ],
    );
  }

  // Detalle: datos y productos del evento
  static DetalleReporte? _detalleEvento(EventoAuditoria e) {
    final filas = <List<Object?>>[
      for (final c in e.datosAdicionales) [c.etiqueta, c.valor],
    ];
    for (final p in e.productos) {
      final extra = (p.detalle ?? '').trim();
      filas.add([
        'Producto: ${p.nombre}',
        'Cantidad: ${p.cantidad}${extra.isEmpty ? '' : ' - $extra'}',
      ]);
    }
    if (filas.isEmpty) return null;
    return DetalleReporte(
      titulo: 'Datos del evento',
      columnas: const [ColumnaReporte('Concepto'), ColumnaReporte('Detalle')],
      filas: filas,
    );
  }

  static String _masFrecuente(Iterable<String> valores) {
    final m = <String, int>{};
    for (final v in valores) {
      final k = v.trim().isEmpty ? '(sin dato)' : v.trim();
      m[k] = (m[k] ?? 0) + 1;
    }
    if (m.isEmpty) return '-';
    final top = m.entries.reduce((a, b) => b.value > a.value ? b : a);
    return '${top.key} (${top.value})';
  }

  static TablaReporte _auditoria(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final es = d.eventos.where((e) => f.incluyeFecha(e.fecha)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final usuarios = es.map((e) => norm(e.autor)).toSet().length;
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Fecha'),
        ColumnaReporte('Usuario'),
        ColumnaReporte('Acción'),
        ColumnaReporte('Módulo'),
        ColumnaReporte('Folio'),
        ColumnaReporte('Descripción'),
      ],
      [
        for (final e in es)
          [
            _fHora.format(e.fecha), e.autor, e.etiqueta, e.modulo,
            e.idReferencia.isEmpty ? '-' : e.idReferencia, e.descripcion,
          ],
      ],
      detalles: [for (final e in es) _detalleEvento(e)],
      resumen: [
        Indicador('Eventos', TablaReporte.formatearEntero(es.length)),
        Indicador('Usuarios distintos', TablaReporte.formatearEntero(usuarios)),
        Indicador('Usuario más activo', _masFrecuente(es.map((e) => e.autor))),
        Indicador('Módulo más usado', _masFrecuente(es.map((e) => e.modulo))),
      ],
    );
  }

}