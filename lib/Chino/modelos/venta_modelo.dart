import 'package:cloud_firestore/cloud_firestore.dart';

/// Nombre de la colección de Firestore que debe llenar el módulo de Ventas.
/// El módulo de Reportes depende de ella para "Ventas por periodo".
const String kColeccionVentas = 'ventas';

/// Un producto vendido dentro de una venta.
class ItemVenta {
  final String nombre;
  final int cantidad;
  final double precioUnitario;

  const ItemVenta({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  factory ItemVenta.fromMap(Map<String, dynamic> map) {
    return ItemVenta(
      nombre: (map['nombre'] ?? '') as String,
      cantidad: ((map['cantidad'] ?? 0) as num).toInt(),
      precioUnitario: ((map['precioUnitario'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
      };
}

/// Modelo de una venta, usado por el reporte "Ventas por periodo".
///
/// Documento en `ventas/{id}`:
/// ```
/// {
///   "fecha": <Timestamp>,
///   "sucursal": "Sucursal Centro",
///   "cliente": "Consumidor final",
///   "metodoPago": "Efectivo",
///   "total": 6800.0,
///   "items": [ { "nombre": "Pan Integral", "cantidad": 4500, "precioUnitario": 1.2 } ]
/// }
/// ```
class Venta {
  final String id;
  final DateTime fecha;
  final String sucursal;
  final String cliente;
  final String metodoPago;
  final double total;
  final List<ItemVenta> items;

  const Venta({
    required this.id,
    required this.fecha,
    required this.sucursal,
    required this.cliente,
    required this.metodoPago,
    required this.total,
    this.items = const [],
  });

  factory Venta.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['fecha'];
    return Venta(
      id: doc.id,
      fecha: ts is Timestamp ? ts.toDate() : DateTime.now(),
      sucursal: (data['sucursal'] ?? '') as String,
      cliente: (data['cliente'] ?? '') as String,
      metodoPago: (data['metodoPago'] ?? '') as String,
      total: ((data['total'] ?? 0) as num).toDouble(),
      items: ((data['items'] as List?) ?? const [])
          .map((e) => ItemVenta.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fecha': Timestamp.fromDate(fecha),
        'sucursal': sucursal,
        'cliente': cliente,
        'metodoPago': metodoPago,
        'total': total,
        'items': items.map((i) => i.toMap()).toList(),
      };
}
