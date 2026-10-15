import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../Chino/modelos/evento_auditoria_modelo.dart';
import '../Chino/modelos/producto_modelo.dart';
import '../Chino/modelos/venta_modelo.dart';

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
    this.error,
  });

  final bool cargandoVentas;
  final bool cargandoProductos;
  final bool cargandoActividad;

  // Ingresos de hoy
  final double ingresosHoy;

  // Ventas de hoy
  final int ventasHoy;

  // Stock bajo
  final List<Producto> stockBajo;

  // Actividad reciente
  final List<EventoAuditoria> actividad;

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
  final Map<String, String> _errores = {};
  void Function(LobbyDatos)? _alCambiar;
  bool _activo = false;

  // Empezar a escuchar
  void iniciar(void Function(LobbyDatos) alCambiar) {
    detener();
    _alCambiar = alCambiar;
    _activo = true;
    _datos = const LobbyDatos();
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

  // Ventas
  void _alVentas(QuerySnapshot<Map<String, dynamic>> snap) {
    final ahora = DateTime.now();
    var ingresos = 0.0;
    var cantidad = 0;

    for (final doc in snap.docs) {
      try {
        final v = Venta.fromDoc(doc);
        if (!v.fechaValida) continue;
        if (v.estado.trim().toLowerCase() != 'activo') continue;
        if (!_mismoDia(v.fecha, ahora)) continue;
        cantidad++;
        // Usa el total o lo calcula
        ingresos += v.total > 0 ? v.total : v.totalItems;
      } catch (e) {
        debugPrint('Lobby: venta ${doc.id} omitida: $e');
      }
    }

    _errores.remove('ventas');
    _emitir(_datos.copyWith(
      cargandoVentas: false,
      ingresosHoy: ingresos,
      ventasHoy: cantidad,
      error: _textoError,
      limpiarError: _errores.isEmpty,
    ));
  }

  // Productos
  void _alProductos(QuerySnapshot<Map<String, dynamic>> snap) {
    final bajos = <Producto>[];

    for (final doc in snap.docs) {
      try {
        final p = Producto.fromDoc(doc);
        if (p.estado.trim().toLowerCase() != 'activo') continue;
        if (p.bajoStock) bajos.add(p);
      } catch (e) {
        debugPrint('Lobby: producto ${doc.id} omitido: $e');
      }
    }

    // Más críticos primero
    bajos.sort((a, b) =>
        (a.stock - a.stockMinimo).compareTo(b.stock - b.stockMinimo));

    _errores.remove('productos');
    _emitir(_datos.copyWith(
      cargandoProductos: false,
      stockBajo: bajos,
      error: _textoError,
      limpiarError: _errores.isEmpty,
    ));
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

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
