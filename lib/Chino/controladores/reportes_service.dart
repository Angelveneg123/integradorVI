import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Henry/modelos/sucursal_modelo.dart';
import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/producto_modelo.dart';
import '../modelos/reporte_modelos.dart';
import '../modelos/usuario_modelo.dart';
import '../modelos/venta_modelo.dart';
import 'auditoria_service.dart';
import 'reportes_calculos.dart';

// Reexporta los modelos
export '../modelos/reporte_modelos.dart';
import 'permisos_service.dart';

// Servicio de reportes
class ReportesService {
  ReportesService({FirebaseFirestore? firestore, AuditoriaService? auditoriaService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auditoria = auditoriaService ?? AuditoriaService(firestore: firestore);

  final FirebaseFirestore _db;
  final AuditoriaService _auditoria;

  Future<({List<Venta> ventas, int omitidos})> _leerVentas() async {
    final snap = await _db.collection(kColeccionVentas).get();
    final ventas = <Venta>[];
    var omitidos = 0;
    for (final doc in snap.docs) {
      try {
        ventas.add(Venta.fromDoc(doc));
      } catch (_) {
        omitidos++;
      }
    }
    return (ventas: ventas, omitidos: omitidos);
  }

  Future<({List<Producto> productos, int omitidos})> _leerProductos() async {
    // Sin orderBy para no perder documentos
    final snap = await _db.collection(kColeccionProductos).get();
    final productos = <Producto>[];
    var omitidos = 0;
    for (final doc in snap.docs) {
      try {
        productos.add(Producto.fromDoc(doc));
      } catch (_) {
        omitidos++;
      }
    }
    return (productos: productos, omitidos: omitidos);
  }

  Future<List<Sucursal>> _leerSucursales() async {
    final snap = await _db.collection(kColeccionSucursales).get();
    final l = <Sucursal>[];
    for (final doc in snap.docs) {
      try {
        l.add(Sucursal.fromDoc(doc));
      } catch (_) {}
    }
    return l;
  }

  // Movimientos de inventario
  Future<List<MovimientoInventario>> _leerMovimientos(
      List<Producto> productos, FiltrosReporte f) async {
    final out = <MovimientoInventario>[];
    const lote = 10;
    for (var i = 0; i < productos.length; i += lote) {
      final parte = productos.skip(i).take(lote).toList();
      final resultados = await Future.wait(parte.map((p) async {
        final snap = await _db
            .collection(kColeccionProductos)
            .doc(p.id)
            .collection('movimientos')
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(f.inicio))
            .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(f.fin))
            .get();
        final l = <MovimientoInventario>[];
        for (final doc in snap.docs) {
          final data = doc.data();
          final ts = data['fecha'];
          if (ts is! Timestamp) continue;
          l.add(MovimientoInventario(
            fecha: ts.toDate(),
            producto: p.nombre,
            sucursal: p.sucursal,
            categoria: p.categoria.trim().isEmpty ? ReportesCalculos.sinCategoria : p.categoria.trim(),
            tipo: (data['tipo'] ?? '').toString(),
            cantidad: ((data['cantidad'] ?? 0) as num).toInt(),
            stockAnterior: ((data['stockAnterior'] ?? 0) as num).toInt(),
            stockNuevo: ((data['stockNuevo'] ?? 0) as num).toInt(),
            motivo: (data['motivo'] ?? '').toString(),
            autor: (data['autor'] ?? '').toString(),
          ));
        }
        return l;
      }));
      for (final r in resultados) {
        out.addAll(r);
      }
    }
    return out;
  }

  // ¿Es administrador?
  Future<bool> esAdministrador() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      final doc = await _db.collection(kColeccionUsuarios).doc(uid).get();
      if (!doc.exists) return false;
      final u = Usuario.fromDoc(doc);
      return u.esAdministrador && u.estado != kEstadoEliminado;
    } catch (_) {
      return false;
    }
  }

  // Opciones para los selectores
  Future<OpcionesFiltros> cargarOpciones() async {
    final permisos = Permisos.instance;
    final limitado = permisos.reportesLimitados;
    final todasSuc = await _leerSucursales();
    final todosProds = (await _leerProductos()).productos;
    final todasVentas = (await _leerVentas()).ventas;

    // Vendedor: solo su sucursal
    final sucursales = limitado
        ? todasSuc
            .where((s) => ReportesCalculos.mismaSucursal(s.nombre, permisos.sucursal))
            .toList()
        : todasSuc;
    final prods = limitado
        ? todosProds
            .where((p) => ReportesCalculos.mismaSucursal(p.sucursal, permisos.sucursal))
            .toList()
        : todosProds;
    final ventas = limitado
        ? todasVentas
            .where((v) =>
                v.vendedorId == permisos.uid &&
                ReportesCalculos.mismaSucursal(v.sucursal, permisos.sucursal))
            .toList()
        : todasVentas;

    String ordenar(String s) => s.toLowerCase();
    List<String> unicos(Iterable<String> it) {
      final m = <String, String>{};
      for (final s in it) {
        final t = s.trim();
        if (t.isNotEmpty) m.putIfAbsent(ReportesCalculos.norm(t), () => t);
      }
      final l = m.values.toList()..sort((a, b) => ordenar(a).compareTo(ordenar(b)));
      return l;
    }

    final nombresSuc = <String, String>{};
    for (final s in sucursales) {
      final n = s.nombre.trim();
      if (n.isNotEmpty) nombresSuc.putIfAbsent(ReportesCalculos.normSucursal(n), () => n);
    }

    return OpcionesFiltros(
      sucursales: nombresSuc.values.toList()
        ..sort((a, b) => ordenar(a).compareTo(ordenar(b))),
      productos: unicos([
        ...prods.map((p) => p.nombre),
        ...ventas.expand((v) => v.items.map((i) => i.nombre)),
      ]),
      categorias: unicos(prods.map((p) => p.categoria)),
      estadosVenta: unicos(['Activo', 'Inactivo', ...ventas.map((v) => v.estado)]),
      estadosProducto: unicos(['Activo', 'Inactivo', ...prods.map((p) => p.estado)]),
      metodosPago: unicos(ventas.map((v) => v.metodoPago)),
    );
  }

  Future<TablaReporte> generar({
    required TipoReporte tipo,
    required FiltrosReporte filtros,
  }) async {
    final error = tipo.usa(FiltroReporte.fechas) ? filtros.errorFechas : null;
    if (error != null) throw ReporteNoDisponible(error);

    final permisos = Permisos.instance;
    if (tipo.restringido && !permisos.esAdmin) {
      throw const ReporteNoDisponible(
          'No tienes permiso para consultar este reporte. Solo los administradores pueden verlo.');
    }
    if (permisos.reportesLimitados) {
      if (permisos.sucursal.isEmpty) {
        throw const ReporteNoDisponible(
            'Tu usuario no tiene sucursal asignada. Pídele al administrador que te asigne una.');
      }
      // Vendedor: siempre su sucursal
      filtros = filtros.copyWith(sucursal: permisos.sucursal);
    }

    var ventas = const <Venta>[];
    var productos = const <Producto>[];
    var sucursales = const <Sucursal>[];
    var movimientos = const <MovimientoInventario>[];
    var eventos = const <EventoAuditoria>[];
    var omitidos = 0;

    final necesitaVentas = tipo.categoria == CategoriaReporte.ventas ||
        tipo == TipoReporte.resumenGeneral;
    final necesitaProductos = tipo.categoria != CategoriaReporte.ventas
        ? tipo != TipoReporte.auditoria
        : true;

    if (necesitaVentas) {
      final r = await _leerVentas();
      ventas = r.ventas;
      omitidos += r.omitidos;
    }
    if (necesitaProductos) {
      final r = await _leerProductos();
      productos = r.productos;
      omitidos += r.omitidos;
    }
    if (permisos.reportesLimitados) {
      // Solo sus ventas
      ventas = ventas
          .where((v) =>
              v.vendedorId == permisos.uid &&
              ReportesCalculos.mismaSucursal(v.sucursal, permisos.sucursal))
          .toList();
      productos = productos
          .where((p) =>
              ReportesCalculos.mismaSucursal(p.sucursal, permisos.sucursal))
          .toList();
    }
    if (tipo == TipoReporte.resumenGeneral) {
      sucursales = await _leerSucursales();
    }
    if (tipo == TipoReporte.movimientosInventario) {
      final fSuc = filtros.activo(tipo, FiltroReporte.sucursal);
      final fProd = filtros.activo(tipo, FiltroReporte.producto);
      final fCat = filtros.activo(tipo, FiltroReporte.categoria);
      final objetivo = productos.where((p) {
        if (fSuc && !ReportesCalculos.mismaSucursal(p.sucursal, filtros.sucursal)) return false;
        if (fProd && ReportesCalculos.norm(p.nombre) != ReportesCalculos.norm(filtros.producto)) return false;
        if (fCat) {
          final c = p.categoria.trim().isEmpty ? ReportesCalculos.sinCategoria : p.categoria.trim();
          if (ReportesCalculos.norm(c) != ReportesCalculos.norm(filtros.categoria)) return false;
        }
        return true;
      }).toList();
      movimientos = await _leerMovimientos(objetivo, filtros);
    }
    if (tipo == TipoReporte.auditoria) {
      eventos = await _auditoria.obtenerEventos(desde: filtros.inicio, hasta: filtros.fin);
    }

    return ReportesCalculos.construir(
      tipo,
      filtros,
      DatosReporte(
        ventas: ventas,
        productos: productos,
        movimientos: movimientos,
        eventos: eventos,
        sucursales: sucursales,
        documentosOmitidos: omitidos,
        ahora: DateTime.now(),
      ),
    );
  }
}

// Mensaje de error entendible
String describirErrorReporte(Object e) {
  if (e is TimeoutException) {
    return 'La consulta tardó demasiado. Revisa tu conexión a internet e inténtalo de nuevo.';
  }
  if (e is FirebaseException) {
    switch (e.code) {
      case 'unavailable':
      case 'network-request-failed':
        return 'No se pudo conectar con Firebase. Revisa tu conexión a internet e inténtalo de nuevo.';
      case 'permission-denied':
        return 'No tienes permiso para leer estos datos (reglas de seguridad de Firestore).';
      case 'failed-precondition':
        if ((e.message ?? '').toLowerCase().contains('index')) {
          return 'Firestore necesita un índice para esta consulta. Abre el enlace que aparece en el '
              'registro de errores (consola) para crearlo, espera unos minutos y reintenta.';
        }
        break;
      case 'deadline-exceeded':
        return 'La consulta tardó demasiado. Inténtalo de nuevo.';
    }
    return 'Ocurrió un problema al consultar Firebase (${e.code}). Inténtalo de nuevo.';
  }
  return 'Ocurrió un problema al generar el reporte. Inténtalo de nuevo.';
}
