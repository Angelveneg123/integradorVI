import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../Chino/modelos/evento_auditoria_modelo.dart';
import '../Chino/modelos/producto_modelo.dart';
import '../Chino/modelos/venta_modelo.dart';

// Periodo del resumen
enum PeriodoLobby { hoy, ayer, semana, mes }

extension PeriodoLobbyTexto on PeriodoLobby {
  // Texto corto para el desplegable
  String get etiqueta {
    switch (this) {
      case PeriodoLobby.hoy:
        return 'Hoy';
      case PeriodoLobby.ayer:
        return 'Ayer';
      case PeriodoLobby.semana:
        return '7 días';
      case PeriodoLobby.mes:
        return 'Este mes';
    }
  }
}

// Filtros del lobby ('' = sin filtrar)
class LobbyFiltros {
  const LobbyFiltros({
    this.sucursal = '',
    this.periodo = PeriodoLobby.hoy,
  });

  final String sucursal;
  final PeriodoLobby periodo;

  bool get esPorDefecto =>
      sucursal.isEmpty && periodo == PeriodoLobby.hoy;

  LobbyFiltros copyWith({
    String? sucursal,
    PeriodoLobby? periodo,
  }) {
    return LobbyFiltros(
      sucursal: sucursal ?? this.sucursal,
      periodo: periodo ?? this.periodo,
    );
  }
}

// Datos del lobby
class LobbyDatos {
  const LobbyDatos({
    this.cargandoVentas = true,
    this.cargandoProductos = true,
    this.cargandoActividad = true,
    this.ingresosHoy = 0,
    this.ventasHoy = 0,
    this.stockBajo = const [],
    this.actividad = const [],
    this.filtros = const LobbyFiltros(),
    this.sucursales = const [],
    this.error,
  });

  final bool cargandoVentas;
  final bool cargandoProductos;
  final bool cargandoActividad;

  // Ingresos del periodo filtrado
  final double ingresosHoy;

  // Ventas del periodo filtrado
  final int ventasHoy;

  // Stock bajo (filtrado por sucursal)
  final List<Producto> stockBajo;

  // Actividad reciente
  final List<EventoAuditoria> actividad;

  // Filtros activos y opciones para los desplegables
  final LobbyFiltros filtros;
  final List<String> sucursales;

  // Último error
  final String? error;

  LobbyDatos copyWith({
    bool? cargandoVentas,
    bool? cargandoProductos,
    bool? cargandoActividad,
    double? ingresosHoy,
    int? ventasHoy,
    List<Producto>? stockBajo,
    List<EventoAuditoria>? actividad,
    LobbyFiltros? filtros,
    List<String>? sucursales,
    String? error,
    bool limpiarError = false,
  }) {
    return LobbyDatos(
      cargandoVentas: cargandoVentas ?? this.cargandoVentas,
      cargandoProductos: cargandoProductos ?? this.cargandoProductos,
      cargandoActividad: cargandoActividad ?? this.cargandoActividad,
      ingresosHoy: ingresosHoy ?? this.ingresosHoy,
      ventasHoy: ventasHoy ?? this.ventasHoy,
      stockBajo: stockBajo ?? this.stockBajo,
      actividad: actividad ?? this.actividad,
      filtros: filtros ?? this.filtros,
      sucursales: sucursales ?? this.sucursales,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

// Servicio del lobby en tiempo real
class LobbyService {
  LobbyService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final List<StreamSubscription<dynamic>> _subs = [];

  LobbyDatos _datos = const LobbyDatos();
  LobbyFiltros _filtros = const LobbyFiltros();
  List<Venta> _ventas = const [];
  List<Producto> _productos = const [];
  final Map<String, String> _errores = {};
  void Function(LobbyDatos)? _alCambiar;
  bool _activo = false;

  // Empezar a escuchar
  void iniciar(void Function(LobbyDatos) alCambiar) {
    detener();
    _alCambiar = alCambiar;
    _activo = true;
    _datos = LobbyDatos(filtros: _filtros);
    _ventas = const [];
    _productos = const [];
    _errores.clear();

    _subs.add(_db.collection(kColeccionVentas).snapshots().listen(
          _alVentas,
          onError: (Object e) => _alError('ventas', e),
        ));
    _subs.add(_db.collection(kColeccionProductos).snapshots().listen(
          _alProductos,
          onError: (Object e) => _alError('productos', e),
        ));
    _subs.add(_db
        .collection(kColeccionAuditoria)
        .orderBy('fecha', descending: true)
        .limit(5)
        .snapshots()
        .listen(
          _alActividad,
          onError: (Object e) => _alError('actividad', e),
        ));
  }

  void detener() {
    _activo = false;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _alCambiar = null;
  }

  void _emitir(LobbyDatos nuevos) {
    _datos = nuevos;
    if (_activo) _alCambiar?.call(_datos);
  }

  // Un error por origen
  String? get _textoError =>
      _errores.isEmpty ? null : _errores.values.join('\n');

  void _alError(String origen, Object e) {
    debugPrint('Lobby: error leyendo $origen: $e');
    _errores[origen] = 'No se pudo leer $origen: $e';
    _emitir(_datos.copyWith(
      // Deja de mostrar "cargando"
      cargandoVentas: origen == 'ventas' ? false : null,
      cargandoProductos: origen == 'productos' ? false : null,
      cargandoActividad: origen == 'actividad' ? false : null,
      error: _textoError,
    ));
  }

  // Cambiar filtros y recalcular
  void aplicarFiltros(LobbyFiltros filtros) {
    _filtros = filtros;
    if (_activo) _publicar();
  }

  // Ventas
  void _alVentas(QuerySnapshot<Map<String, dynamic>> snap) {
    final lista = <Venta>[];
    for (final doc in snap.docs) {
      try {
        lista.add(Venta.fromDoc(doc));
      } catch (e) {
        debugPrint('Lobby: venta ${doc.id} omitida: $e');
      }
    }
    _ventas = lista;
    _errores.remove('ventas');
    _publicar(cargandoVentas: false);
  }

  // Productos
  void _alProductos(QuerySnapshot<Map<String, dynamic>> snap) {
    final lista = <Producto>[];
    for (final doc in snap.docs) {
      try {
        final p = Producto.fromDoc(doc);
        if (p.estado.trim().toLowerCase() != 'activo') continue;
        lista.add(p);
      } catch (e) {
        debugPrint('Lobby: producto ${doc.id} omitido: $e');
      }
    }
    _productos = lista;
    _errores.remove('productos');
    _publicar(cargandoProductos: false);
  }

  // Recalcula las métricas con los filtros actuales
  void _publicar({bool? cargandoVentas, bool? cargandoProductos}) {
    final ahora = DateTime.now();
    final f = _filtros;
    var ingresos = 0.0;
    var cantidad = 0;

    for (final v in _ventas) {
      if (!v.fechaValida) continue;
      if (v.estado.trim().toLowerCase() != 'activo') continue;
      if (!_enPeriodo(v.fecha, ahora, f.periodo)) continue;
      if (!_coincide(v.sucursal, f.sucursal)) continue;
      cantidad++;
      // Usa el total o lo calcula
      ingresos += v.total > 0 ? v.total : v.totalItems;
    }

    final bajos = _productos
        .where((p) => p.bajoStock && _coincide(p.sucursal, f.sucursal))
        .toList();
    // Más críticos primero
    bajos.sort((a, b) =>
        (a.stock - a.stockMinimo).compareTo(b.stock - b.stockMinimo));

    _emitir(_datos.copyWith(
      cargandoVentas: cargandoVentas,
      cargandoProductos: cargandoProductos,
      ingresosHoy: ingresos,
      ventasHoy: cantidad,
      stockBajo: bajos,
      filtros: f,
      sucursales: _opciones([
        ..._ventas.map((v) => v.sucursal),
        ..._productos.map((p) => p.sucursal),
      ]),
      error: _textoError,
      limpiarError: _errores.isEmpty,
    ));
  }

  // Valores únicos, sin repetir por mayúsculas, ordenados
  static List<String> _opciones(Iterable<String> valores) {
    final vistos = <String, String>{};
    for (final v in valores) {
      final t = v.trim();
      if (t.isEmpty) continue;
      vistos.putIfAbsent(t.toLowerCase(), () => t);
    }
    final lista = vistos.values.toList();
    lista.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return lista;
  }

  static bool _coincide(String valor, String filtro) =>
      filtro.isEmpty ||
      valor.trim().toLowerCase() == filtro.trim().toLowerCase();

  static bool _enPeriodo(DateTime fecha, DateTime ahora, PeriodoLobby p) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    switch (p) {
      case PeriodoLobby.hoy:
        return dia == hoy;
      case PeriodoLobby.ayer:
        return dia == DateTime(hoy.year, hoy.month, hoy.day - 1);
      case PeriodoLobby.semana:
        final desde = DateTime(hoy.year, hoy.month, hoy.day - 6);
        return !dia.isBefore(desde) && !dia.isAfter(hoy);
      case PeriodoLobby.mes:
        return fecha.year == ahora.year && fecha.month == ahora.month;
    }
  }

  // Actividad
  void _alActividad(QuerySnapshot<Map<String, dynamic>> snap) {
    final eventos = <EventoAuditoria>[];
    for (final doc in snap.docs) {
      try {
        eventos.add(EventoAuditoria.fromDoc(doc));
      } catch (e) {
        debugPrint('Lobby: evento ${doc.id} omitido: $e');
      }
    }
    _errores.remove('actividad');
    _emitir(_datos.copyWith(
      cargandoActividad: false,
      actividad: eventos,
      error: _textoError,
      limpiarError: _errores.isEmpty,
    ));
  }
}