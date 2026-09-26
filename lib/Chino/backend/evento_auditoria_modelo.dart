import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Nombre de la colección de Firestore para la bitácora de auditoría.
/// Todos los módulos (Ventas, Stock, Usuarios, Accesos, Productos...)
/// escriben aquí cuando hacen crear/editar/eliminar/ingresar.
const String kColeccionAuditoria = 'auditoria';

/// Tipos de evento que puede registrar la bitácora de auditoría.
enum TipoEvento { crear, editar, eliminar, ingresar }

TipoEvento tipoEventoDesdeTexto(String texto) {
  return TipoEvento.values.firstWhere(
    (t) => t.name == texto,
    orElse: () => TipoEvento.editar,
  );
}

/// Color asociado a cada tipo de evento (se deriva en la UI, no se guarda
/// en Firestore, para no acoplar el color exacto a los datos).
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

/// Etiqueta legible para cada tipo de evento.
String etiquetaParaTipoEvento(TipoEvento tipo) {
  switch (tipo) {
    case TipoEvento.crear:
      return 'Crear';
    case TipoEvento.editar:
      return 'Editar';
    case TipoEvento.eliminar:
      return 'Eliminar';
    case TipoEvento.ingresar:
      return 'Ingreso';
  }
}

/// Un producto/artículo afectado por el evento, con su cantidad.
/// Ej: al eliminar una venta, aquí van los productos que la componían.
class ProductoMovimiento {
  final String nombre;
  final int cantidad;
  final String? detalle; // texto libre opcional, ej. "Stock: 45 → 55"

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

/// Un dato adicional de "clave: valor" que varía según el tipo de evento.
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

/// Modelo de un evento del registro de auditoría.
///
/// Documento en `auditoria/{id}`:
/// ```
/// {
///   "titulo": "Stock",
///   "tipo": "editar",              // crear | editar | eliminar | ingresar
///   "descripcion": "Ajuste de inventario (entrada de stock)",
///   "autor": "Juan Pérez",
///   "fecha": <Timestamp>,
///   "modulo": "Stock",
///   "idReferencia": "S-00210",
///   "productos": [ { "nombre": "Croissant", "cantidad": 10, "detalle": "..." } ],
///   "datosAdicionales": [ { "etiqueta": "Motivo", "valor": "Producción" } ]
/// }
/// ```
class EventoAuditoria {
  final String id;
  final String titulo;
  final TipoEvento tipo;
  final String descripcion;
  final String autor;
  final DateTime fecha;
  final String modulo; // Ventas, Accesos, Stock, Usuarios, Productos...
  final String idReferencia; // folio/ID interno del evento, para rastreo
  final List<ProductoMovimiento> productos;
  final List<CampoInfo> datosAdicionales;

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
  });

  String get etiqueta => etiquetaParaTipoEvento(tipo);
  Color get colorEtiqueta => colorParaTipoEvento(tipo);

  String get fechaFormateada => DateFormat("dd/MM/yyyy - hh:mm a").format(fecha);

  factory EventoAuditoria.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['fecha'];
    return EventoAuditoria(
      id: doc.id,
      titulo: (data['titulo'] ?? data['modulo'] ?? '') as String,
      tipo: tipoEventoDesdeTexto((data['tipo'] ?? 'editar') as String),
      descripcion: (data['descripcion'] ?? '') as String,
      autor: (data['autor'] ?? '') as String,
      fecha: ts is Timestamp ? ts.toDate() : DateTime.now(),
      modulo: (data['modulo'] ?? '') as String,
      idReferencia: (data['idReferencia'] ?? doc.id) as String,
      productos: ((data['productos'] as List?) ?? const [])
          .map((e) => ProductoMovimiento.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      datosAdicionales: ((data['datosAdicionales'] as List?) ?? const [])
          .map((e) => CampoInfo.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
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
      };
}
