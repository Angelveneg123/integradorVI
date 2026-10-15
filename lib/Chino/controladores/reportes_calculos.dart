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
  final String metodoPago;
  final String producto;
  final String categoria;
  final double cantidad;
  final double subtotal;

  // Venta sin detalle
  final bool sinDetalle;

  const LineaVenta({
    required this.ventaId,
    required this.codigoVenta,
    required this.fecha,
    required this.sucursal,
    required this.estado,
    required this.metodoPago,
    required this.producto,
    required this.categoria,
    required this.cantidad,
    required this.subtotal,
    this.sinDetalle = false,
  });
}

class _Acum {
  final String etiqueta;
  final Set<String> ventas = {};
  double cantidad = 0;
  double importe = 0;
  String extra = '';
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
    final fMet = f.activo(tipo, FiltroReporte.metodoPago);
    final fProd = f.activo(tipo, FiltroReporte.producto);
    final fCat = f.activo(tipo, FiltroReporte.categoria);
    final usaFechas = tipo.usa(FiltroReporte.fechas);

    final lineas = <LineaVenta>[];
    var sinFecha = 0;
    var totalDistinto = 0;

    for (final v in d.ventas) {
      if (fSuc && !mismaSucursal(v.sucursal, f.sucursal)) continue;
      if (fEst && norm(v.estado) != norm(f.estado)) continue;
      if (fMet && norm(v.metodoPago) != norm(f.metodoPago)) continue;
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
          sucursal: v.sucursal, estado: v.estado, metodoPago: v.metodoPago,
          producto: '(sin detalle)', categoria: sinCategoria,
          cantidad: 0, subtotal: r2(v.total), sinDetalle: true,
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
          sucursal: v.sucursal, estado: v.estado, metodoPago: v.metodoPago,
          producto: i.nombre.trim().isEmpty ? '(sin nombre)' : i.nombre.trim(),
          categoria: categoria, cantidad: i.cantidad, subtotal: sub,
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
      case TipoReporte.ventasPorMetodoPago:
        return _ventasPorMetodo(tipo, f, d);
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
    for (final g in grupos) {
      final h = g.first;
      final prod = g.where((l) => !l.sinDetalle).length;
      final cant = g.fold<double>(0, (s, l) => s + l.cantidad);
      final imp = r2(g.fold<double>(0, (s, l) => s + l.subtotal));
      sumProd += prod;
      sumCant += cant;
      sumImp += imp;
      filas.add([
        _fHora.format(h.fecha), h.codigoVenta, _etiquetaSuc(h.sucursal),
        h.estado, prod, cant, imp,
      ]);
    }
    sumImp = r2(sumImp);
    final n = grupos.length;
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Fecha'),
        ColumnaReporte('Código'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Estado'),
        ColumnaReporte('Productos', TipoColumna.entero),
        ColumnaReporte('Unidades', TipoColumna.cantidad),
        ColumnaReporte('Importe (C\$)', TipoColumna.moneda),
      ],
      filas,
      totales: ['TOTAL ($n ventas)', null, null, null, sumProd, sumCant, sumImp],
      resumen: [
        Indicador('Ventas', TablaReporte.formatearEntero(n)),
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
    return _tablaAgrupadaVentas(t, f, d, r, 'Período', claves.map((k) => g[k]!).toList());
  }

  static TablaReporte _ventasPorSucursal(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final r = lineasDeVentas(d, f, t);
    final g = _agrupar(r.lineas, (l) => normSucursal(l.sucursal),
        (l) => _etiquetaSuc(l.sucursal));
    final lista = g.values.toList()..sort((a, b) => b.importe.compareTo(a.importe));
    return _tablaAgrupadaVentas(t, f, d, r, 'Sucursal', lista, conPorcentaje: true);
  }

  static TablaReporte _ventasPorMetodo(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final hay = d.ventas.any((v) => v.metodoPago.trim().isNotEmpty);
    if (!hay) {
      throw const ReporteNoDisponible(
          'Las ventas registradas no guardan el método de pago, por lo que este '
          'reporte no se puede generar. Cuando el módulo de Ventas registre ese '
          'dato, el reporte estará disponible.');
    }
    final r = lineasDeVentas(d, f, t);
    final g = _agrupar(
        r.lineas,
        (l) => norm(l.metodoPago),
        (l) => l.metodoPago.trim().isEmpty ? 'Sin especificar' : l.metodoPago.trim());
    final lista = g.values.toList()..sort((a, b) => b.importe.compareTo(a.importe));
    return _tablaAgrupadaVentas(t, f, d, r, 'Método de pago', lista, conPorcentaje: true);
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
      resumen: [
        Indicador('Ventas', TablaReporte.formatearEntero(totalVentas)),
        Indicador('Importe total', TablaReporte.formatearMoneda(totalImp)),
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
          if (!ranking) lista[i].ventas.length,
          r2(lista[i].importe),
        ],
    ];
    final etiquetaTotal = ranking ? 'TOTAL (${lista.length} productos)' : 'TOTAL';
    return _tabla(
      t, f, d,
      [
        if (ranking) const ColumnaReporte('#', TipoColumna.entero),
        const ColumnaReporte('Producto'),
        const ColumnaReporte('Categoría'),
        const ColumnaReporte('Unidades', TipoColumna.cantidad),
        if (!ranking) const ColumnaReporte('N° de ventas', TipoColumna.entero),
        const ColumnaReporte('Importe (C\$)', TipoColumna.moneda),
      ],
      filas,
      totales: [
        if (ranking) null,
        etiquetaTotal,
        null,
        totalCant,
        if (!ranking) null,
        totalImp,
      ],
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
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Código'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Categoría'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Precio (C\$)', TipoColumna.moneda),
        ColumnaReporte('Estado'),
      ],
      [
        for (final p in ps)
          [p.codigo, p.nombre, _catDe(p), _etiquetaSuc(p.sucursal), r2(p.precio), p.estado],
      ],
      resumen: [
        Indicador('Productos', TablaReporte.formatearEntero(ps.length)),
        Indicador('Activos', TablaReporte.formatearEntero(activos)),
        Indicador('Inactivos', TablaReporte.formatearEntero(ps.length - activos)),
      ],
    );
  }

  static TablaReporte _existencias(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final unidades = ps.fold<int>(0, (s, p) => s + p.stock);
    final ago = ps.where((p) => p.stock <= 0).length;
    final bajo = ps.where((p) => p.stock > 0 && p.stock <= p.stockMinimo).length;
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Código'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Categoría'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Stock', TipoColumna.entero),
        ColumnaReporte('Stock mínimo', TipoColumna.entero),
        ColumnaReporte('Situación'),
      ],
      [
        for (final p in ps)
          [p.codigo, p.nombre, _catDe(p), _etiquetaSuc(p.sucursal), p.stock, p.stockMinimo, situacion(p)],
      ],
      totales: ['TOTAL', null, null, null, unidades, null, null],
      resumen: [
        Indicador('Productos', TablaReporte.formatearEntero(ps.length)),
        Indicador('Unidades en stock', TablaReporte.formatearEntero(unidades)),
        Indicador('Stock bajo', TablaReporte.formatearEntero(bajo)),
        Indicador('Agotados', TablaReporte.formatearEntero(ago)),
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
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Stock', TipoColumna.entero),
        ColumnaReporte('Stock mínimo', TipoColumna.entero),
        ColumnaReporte('Faltante', TipoColumna.entero),
      ],
      [
        for (final p in ps)
          [p.codigo, p.nombre, _etiquetaSuc(p.sucursal), p.stock, p.stockMinimo, p.stockMinimo - p.stock],
      ],
      totales: ['TOTAL', null, null, unidades, null, faltante],
      resumen: [Indicador('Productos con stock bajo', TablaReporte.formatearEntero(ps.length))],
    );
  }

  static TablaReporte _agotados(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t).where((p) => p.stock <= 0).toList();
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Código'),
        ColumnaReporte('Producto'),
        ColumnaReporte('Categoría'),
        ColumnaReporte('Sucursal'),
        ColumnaReporte('Stock mínimo', TipoColumna.entero),
        ColumnaReporte('Estado'),
      ],
      [
        for (final p in ps)
          [p.codigo, p.nombre, _catDe(p), _etiquetaSuc(p.sucursal), p.stockMinimo, p.estado],
      ],
      resumen: [Indicador('Productos agotados', TablaReporte.formatearEntero(ps.length))],
    );
  }

  static TablaReporte _porCategoria(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final g = <String, List<Producto>>{};
    for (final p in ps) {
      g.putIfAbsent(_catDe(p), () => []).add(p);
    }
    final claves = g.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _tablaInv(t, f, d, 'Categoría', claves, g);
  }

  static TablaReporte _porSucursalInv(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final g = <String, List<Producto>>{};
    for (final p in ps) {
      g.putIfAbsent(_etiquetaSuc(p.sucursal), () => []).add(p);
    }
    final claves = g.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _tablaInv(t, f, d, 'Sucursal', claves, g);
  }

  static TablaReporte _tablaInv(TipoReporte t, FiltrosReporte f, DatosReporte d,
      String titulo, List<String> claves, Map<String, List<Producto>> g) {
    var nProd = 0, uni = 0, bajo = 0, ago = 0;
    var valor = 0.0;
    final filas = <List<Object?>>[];
    for (final k in claves) {
      final l = g[k]!;
      final u = l.fold<int>(0, (s, p) => s + p.stock);
      final v = r2(l.fold<double>(0, (s, p) => s + (p.stock > 0 ? p.stock * p.precio : 0)));
      final b = l.where((p) => p.stock > 0 && p.stock <= p.stockMinimo).length;
      final a = l.where((p) => p.stock <= 0).length;
      nProd += l.length;
      uni += u;
      valor += v;
      bajo += b;
      ago += a;
      filas.add([k, l.length, u, v, b, a]);
    }
    valor = r2(valor);
    return _tabla(
      t, f, d,
      [
        ColumnaReporte(titulo),
        const ColumnaReporte('Productos', TipoColumna.entero),
        const ColumnaReporte('Unidades en stock', TipoColumna.entero),
        const ColumnaReporte('Valor de inventario (C\$)', TipoColumna.moneda),
        const ColumnaReporte('Stock bajo', TipoColumna.entero),
        const ColumnaReporte('Agotados', TipoColumna.entero),
      ],
      filas,
      totales: ['TOTAL', nProd, uni, valor, bajo, ago],
      resumen: [
        Indicador('Productos', TablaReporte.formatearEntero(nProd)),
        Indicador('Unidades', TablaReporte.formatearEntero(uni)),
        Indicador('Valor de inventario', TablaReporte.formatearMoneda(valor)),
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
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Fecha'),
        ColumnaReporte('Producto'),
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
            _fHora.format(m.fecha), m.producto, _etiquetaSuc(m.sucursal), m.tipo,
            m.cantidad, m.stockAnterior, m.stockNuevo, m.motivo, m.autor,
          ],
      ],
      resumen: [
        Indicador('Movimientos', TablaReporte.formatearEntero(ms.length)),
        Indicador('Entradas (unid.)', TablaReporte.formatearEntero(entradas)),
        Indicador('Salidas (unid.)', TablaReporte.formatearEntero(salidas)),
      ],
    );
  }

  static TablaReporte _resumenGeneral(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final r = lineasDeVentas(d, f, t);
    final ventasIds = r.lineas.map((l) => l.ventaId).toSet();
    final importe = r2(r.lineas.fold<double>(0, (s, l) => s + l.subtotal));
    final ps = _prodFiltrados(d, f, t);
    final ago = ps.where((p) => p.stock <= 0).length;
    final bajo = ps.where((p) => p.stock > 0 && p.stock <= p.stockMinimo).length;
    final activos = ps.where((p) => norm(p.estado) == 'activo').length;

    final filas = <List<Object?>>[];
    final adv = <String>[..._advVentas(r)];
    if (ventasIds.isNotEmpty) {
      filas.add(['Ventas en el período', TablaReporte.formatearEntero(ventasIds.length)]);
      filas.add(['Importe vendido', TablaReporte.formatearMoneda(importe)]);
      filas.add([
        'Promedio por venta',
        TablaReporte.formatearMoneda(r2(importe / ventasIds.length)),
      ]);
      final inactivas = r.lineas
          .where((l) => norm(l.estado) != 'activo')
          .map((l) => l.ventaId)
          .toSet()
          .length;
      if (inactivas > 0) {
        adv.add('Las ventas incluyen todos los estados ($inactivas con estado distinto de Activo).');
      }
    } else {
      adv.add('No hubo ventas en el período seleccionado.');
    }
    if (ps.isNotEmpty) {
      filas.add(['Productos registrados', TablaReporte.formatearEntero(ps.length)]);
      filas.add(['Productos activos', TablaReporte.formatearEntero(activos)]);
      filas.add(['Productos con stock bajo', TablaReporte.formatearEntero(bajo)]);
      filas.add(['Productos agotados', TablaReporte.formatearEntero(ago)]);
    }
    if (!f.activo(t, FiltroReporte.sucursal) && d.sucursales.isNotEmpty) {
      filas.add(['Sucursales registradas', TablaReporte.formatearEntero(d.sucursales.length)]);
      filas.add([
        'Sucursales activas',
        TablaReporte.formatearEntero(d.sucursales.where((s) => s.activo).length),
      ]);
    }
    return _tabla(
      t, f, d,
      const [ColumnaReporte('Indicador'), ColumnaReporte('Valor')],
      filas,
      advertencias: adv,
    );
  }

  static TablaReporte _disponibilidad(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final ps = _prodFiltrados(d, f, t);
    final activos = ps.where((p) => norm(p.estado) == 'activo').length;
    final ago = ps.where((p) => p.stock <= 0).length;
    final bajo = ps.where((p) => p.stock > 0 && p.stockMinimo >= p.stock).length;
    final disp = ps.length - ago - bajo;
    return _tabla(
      t, f, d,
      const [ColumnaReporte('Concepto'), ColumnaReporte('Productos', TipoColumna.entero)],
      ps.isEmpty
          ? <List<Object?>>[]
          : [
              ['Productos registrados', ps.length],
              ['Activos', activos],
              ['Inactivos', ps.length - activos],
              ['Disponibles (sobre el stock mínimo)', disp],
              ['Con stock bajo', bajo],
              ['Agotados', ago],
            ],
      advertencias: const [
        'Disponibilidad, stock bajo y agotados se calculan sobre todos los productos '
            'filtrados, estén activos o no.',
      ],
    );
  }

  static TablaReporte _auditoria(TipoReporte t, FiltrosReporte f, DatosReporte d) {
    final es = d.eventos.where((e) => f.incluyeFecha(e.fecha)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return _tabla(
      t, f, d,
      const [
        ColumnaReporte('Fecha'),
        ColumnaReporte('Usuario'),
        ColumnaReporte('Acción'),
        ColumnaReporte('Módulo'),
        ColumnaReporte('Descripción'),
      ],
      [
        for (final e in es)
          [_fHora.format(e.fecha), e.autor, e.etiqueta, e.modulo, e.descripcion],
      ],
      resumen: [Indicador('Eventos', TablaReporte.formatearEntero(es.length))],
    );
  }
}
