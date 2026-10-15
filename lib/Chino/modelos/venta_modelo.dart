import 'package:cloud_firestore/cloud_firestore.dart';

// Colección de ventas
const String kColeccionVentas = 'ventas';

double _aDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

// Convertir la fecha de la venta
DateTime? parsearFechaVenta(dynamic valor) {
  if (valor == null) return null;
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is! String) return null;

  final texto = valor.trim();
  if (texto.isEmpty) return null;

  final iso = DateTime.tryParse(texto);
  if (iso != null) return iso;

  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:[ T]+(\d{1,2}):(\d{2}))?$')
      .firstMatch(texto);
  if (m == null) return null;
  final dia = int.parse(m.group(1)!);
  final mes = int.parse(m.group(2)!);
  final anio = int.parse(m.group(3)!);
  final hora = int.tryParse(m.group(4) ?? '') ?? 0;
  final minuto = int.tryParse(m.group(5) ?? '') ?? 0;
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  return DateTime(anio, mes, dia, hora, minuto);
}

// Producto vendido
class ItemVenta {
  final String codigo;
  final String nombre;
  final double cantidad;
  final double precioUnitario;

  const ItemVenta({
    this.codigo = '',
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  // Leer un item de venta
  factory ItemVenta.fromMap(Map<String, dynamic> map) {
    return ItemVenta(
      codigo: (map['codigo'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      cantidad: _aDouble(map['cantidad']),
      precioUnitario: _aDouble(map['precioUnitario'] ?? map['precio']),
    );
  }

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
      };
}

// Modelo de venta
class Venta {
  final String id;
  final String codigoV;
  final DateTime fecha;

  // Si la fecha es válida
  final bool fechaValida;
  final String sucursal;
  final String estado;
  final String cliente;
  final String metodoPago;
  final double total;
  final List<ItemVenta> items;

  // Quién registró la venta
  final String vendedorId;
  final String vendedorNombre;

  const Venta({
    required this.id,
    this.codigoV = '',
    required this.fecha,
    this.fechaValida = true,
    required this.sucursal,
    this.estado = 'Activo',
    required this.cliente,
    required this.metodoPago,
    required this.total,
    this.items = const [],
    this.vendedorId = '',
    this.vendedorNombre = '',
  });

  // Total de los items
  double get totalItems => items.fold<double>(0, (s, i) => s + i.subtotal);

  factory Venta.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final fecha = parsearFechaVenta(data['fecha']);
    final crudos = (data['items'] ?? data['productos']) as List?;
    final items = (crudos ?? const [])
        .whereType<Map>()
        .map((e) => ItemVenta.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final codigo = (data['codigoV'] ?? '').toString().trim();

    return Venta(
      id: doc.id,
      codigoV: codigo.isNotEmpty
          ? codigo
          : doc.id.substring(0, doc.id.length >= 6 ? 6 : doc.id.length),
      fecha: fecha ?? DateTime.fromMillisecondsSinceEpoch(0),
      fechaValida: fecha != null,
      sucursal:
          (data['sucursal'] ?? data['sucursalU'] ?? '').toString().trim(),
      estado: (data['estado'] ?? 'Activo').toString().trim(),
      cliente: (data['cliente'] ?? '').toString(),
      metodoPago: (data['metodoPago'] ?? '').toString().trim(),
      total: _aDouble(data['total']),
      items: items,
      vendedorId: (data['vendedorId'] ?? '').toString().trim(),
      vendedorNombre: (data['vendedorNombre'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'codigoV': codigoV,
        'fecha': Timestamp.fromDate(fecha),
        'estado': estado,
        'sucursal': sucursal,
        'cliente': cliente,
        'metodoPago': metodoPago,
        'total': total,
        'items': items.map((i) => i.toMap()).toList(),
        if (vendedorId.isNotEmpty) 'vendedorId': vendedorId,
        if (vendedorNombre.isNotEmpty) 'vendedorNombre': vendedorNombre,
      };
}
