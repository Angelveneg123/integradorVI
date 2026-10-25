import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Colección de auditoría
const String kColeccionAuditoria = 'auditoria';

// Tipos de evento
enum TipoEvento { crear, editar, eliminar, ingresar }

TipoEvento tipoEventoDesdeTexto(String texto) {
  return TipoEvento.values.firstWhere(
    (t) => t.name == texto,
    orElse: () => TipoEvento.editar,
  );
}

// Color según el tipo
Color colorParaTipoEvento(TipoEvento tipo) {
  switch (tipo) {
    case TipoEvento.crear:
    case TipoEvento.ingresar:
      return const Color(0xFF5FA45E);
    case TipoEvento.editar:
      return const Color(0xFFEFA93B);
    case TipoEvento.eliminar:
      return const Color(0xFF4A7FC1);
  }
}

// Etiqueta según el tipo
String etiquetaParaTipoEvento(TipoEvento tipo) {
  switch (tipo) {
    case TipoEvento.crear:
      return 'Crear';
    case TipoEvento.editar:
      return 'Editar';
    case TipoEvento.eliminar:
      return 'Eliminar';
    case TipoEvento.ingresar:
      return 'Inicio de sesión';
  }
}

// Producto afectado por el evento
class ProductoMovimiento {
  final String nombre;
  final int cantidad;
  final String? detalle; // texto libre opcional

  const ProductoMovimiento({
    required this.nombre,
    required this.cantidad,
    this.detalle,
  });

  factory ProductoMovimiento.fromMap(Map<String, dynamic> map) {
    return ProductoMovimiento(
      nombre: (map['nombre'] ?? '') as String,
      cantidad: ((map['cantidad'] ?? 0) as num).toInt(),
      detalle: map['detalle'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'cantidad': cantidad,
        if (detalle != null) 'detalle': detalle,
      };
}

// Dato extra (clave y valor)
class CampoInfo {
  final String etiqueta;
  final String valor;

  const CampoInfo(this.etiqueta, this.valor);

  factory CampoInfo.fromMap(Map<String, dynamic> map) {
    return CampoInfo(
      (map['etiqueta'] ?? '') as String,
      (map['valor'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {'etiqueta': etiqueta, 'valor': valor};
}

// El módulo se llamaba "Materia Prima": los eventos viejos se muestran como
// "Ingredientes"
String _moduloActual(String m) =>
    m.trim().toLowerCase() == 'materia prima' ? 'Ingredientes' : m;

// Evento de auditoría
class EventoAuditoria {
  final String id;
  final String titulo;
  final TipoEvento tipo;
  final String descripcion;
  final String autor;
  final DateTime fecha;
  final String modulo; // Ventas, Accesos, Stock, Usuarios, Productos...
  final String idReferencia; // folio del evento
  final List<ProductoMovimiento> productos;
  final List<CampoInfo> datosAdicionales;

  // Quién lo hizo (los eventos viejos no los tienen)
  final String autorId;
  final String autorCorreo;
  final String autorRol;
  final String autorSucursal;
  final String plataforma;

  const EventoAuditoria({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.descripcion,
    required this.autor,
    required this.fecha,
    required this.modulo,
    required this.idReferencia,
    this.productos = const [],
    this.datosAdicionales = const [],
    this.autorId = '',
    this.autorCorreo = '',
    this.autorRol = '',
    this.autorSucursal = '',
    this.plataforma = '',
  });

  String get etiqueta => etiquetaParaTipoEvento(tipo);
  Color get colorEtiqueta => colorParaTipoEvento(tipo);

  String get fechaFormateada => DateFormat("dd/MM/yyyy - hh:mm a").format(fecha);

  static const List<String> _dias = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];
  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  // Ej.: sábado, 24 de octubre de 2026
  String get fechaLarga =>
      '${_dias[fecha.weekday - 1]}, ${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';

  // Ej.: 03:25:10 PM
  String get horaCompleta => DateFormat('hh:mm:ss a').format(fecha);

  // Ej.: hace 3 horas
  String get hace {
    final d = DateTime.now().difference(fecha);
    if (d.isNegative || d.inSeconds < 60) return 'hace unos segundos';
    if (d.inMinutes < 60) {
      return 'hace ${d.inMinutes} ${d.inMinutes == 1 ? 'minuto' : 'minutos'}';
    }
    if (d.inHours < 24) {
      return 'hace ${d.inHours} ${d.inHours == 1 ? 'hora' : 'horas'}';
    }
    if (d.inDays < 30) {
      return 'hace ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
    }
    final meses = d.inDays ~/ 30;
    if (meses < 12) return 'hace $meses ${meses == 1 ? 'mes' : 'meses'}';
    final anios = d.inDays ~/ 365;
    return 'hace $anios ${anios == 1 ? 'año' : 'años'}';
  }

  // Qué significa el tipo de acción
  String get queSignifica {
    switch (tipo) {
      case TipoEvento.crear:
        return 'Se registró algo nuevo en el sistema';
      case TipoEvento.editar:
        return 'Se modificó un registro existente';
      case TipoEvento.eliminar:
        return 'Se eliminó o dio de baja un registro';
      case TipoEvento.ingresar:
        return 'Un usuario inició sesión en el sistema';
    }
  }

  factory EventoAuditoria.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['fecha'];
    return EventoAuditoria(
      id: doc.id,
      titulo: _moduloActual((data['titulo'] ?? data['modulo'] ?? '') as String),
      tipo: tipoEventoDesdeTexto((data['tipo'] ?? 'editar') as String),
      descripcion: ((data['descripcion'] ?? '') as String)
          .replaceAll('la materia prima "', 'el ingrediente "'),
      autor: (data['autor'] ?? '') as String,
      fecha: ts is Timestamp ? ts.toDate() : DateTime.now(),
      modulo: _moduloActual((data['modulo'] ?? '') as String),
      idReferencia: (data['idReferencia'] ?? doc.id) as String,
      productos: ((data['productos'] as List?) ?? const [])
          .map((e) => ProductoMovimiento.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      datosAdicionales: ((data['datosAdicionales'] as List?) ?? const [])
          .map((e) => CampoInfo.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      autorId: (data['autorId'] ?? '').toString(),
      autorCorreo: (data['autorCorreo'] ?? '').toString(),
      autorRol: (data['autorRol'] ?? '').toString(),
      autorSucursal: (data['autorSucursal'] ?? '').toString(),
      plataforma: (data['plataforma'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'titulo': titulo,
        'tipo': tipo.name,
        'descripcion': descripcion,
        'autor': autor,
        'fecha': FieldValue.serverTimestamp(),
        'modulo': modulo,
        'idReferencia': idReferencia,
        'productos': productos.map((p) => p.toMap()).toList(),
        'datosAdicionales': datosAdicionales.map((c) => c.toMap()).toList(),
        if (autorId.isNotEmpty) 'autorId': autorId,
        if (autorCorreo.isNotEmpty) 'autorCorreo': autorCorreo,
        if (autorRol.isNotEmpty) 'autorRol': autorRol,
        if (autorSucursal.isNotEmpty) 'autorSucursal': autorSucursal,
        if (plataforma.isNotEmpty) 'plataforma': plataforma,
      };
}