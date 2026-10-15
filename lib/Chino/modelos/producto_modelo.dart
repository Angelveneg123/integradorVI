import 'package:cloud_firestore/cloud_firestore.dart';

// Colección de productos
const String kColeccionProductos = 'productos';

// Existencia del producto
int existenciaDeDocumento(Map<String, dynamic> data) {
  final v = data['stock'] ?? data['cantidad'];
  if (v is num) return v.toInt();
  if (v is String) {
    return (double.tryParse(v.trim().replaceAll(',', '.')) ?? 0).toInt();
  }
  return 0;
}

// Ingrediente del producto
class Ingrediente {
  final String nombre;
  final String cantidad;

  const Ingrediente({required this.nombre, required this.cantidad});

  factory Ingrediente.fromMap(Map<String, dynamic> map) {
    return Ingrediente(
      nombre: (map['nombre'] ?? '') as String,
      cantidad: (map['cantidad'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'cantidad': cantidad,
      };
}

// Modelo de producto
class Producto {
  final String id; // id del documento en Firestore
  final String codigo; // ej. P001
  final String nombre;
  final String categoria;
  final double precio;
  final int stock; // existencia
  final int stockMinimo;
  final String sucursal;
  final String estado; // 'Activo' o 'Inactivo'
  final List<Ingrediente> ingredientes;

  const Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.precio,
    required this.stock,
    required this.stockMinimo,
    required this.sucursal,
    this.estado = 'Activo',
    this.ingredientes = const [],
  });

  bool get activo => estado == 'Activo';
  bool get bajoStock => stock <= stockMinimo;

  factory Producto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Producto(
      id: doc.id,
      codigo: (data['codigo'] ?? doc.id) as String,
      nombre: (data['nombre'] ?? '') as String,
      categoria: (data['categoria'] ?? '') as String,
      precio: ((data['precio'] ?? 0) as num).toDouble(),
      stock: existenciaDeDocumento(data),
      stockMinimo: ((data['stockMinimo'] ?? 0) as num).toInt(),
      sucursal: (data['sucursal'] ?? '') as String,
      estado: (data['estado'] ?? 'Activo') as String,
      ingredientes: ((data['ingredientes'] as List?) ?? const [])
          .map((e) => Ingrediente.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'categoria': categoria,
        'precio': precio,
        'stock': stock,
        // cantidad igual a stock
        'cantidad': stock,
        'stockMinimo': stockMinimo,
        'sucursal': sucursal,
        'estado': estado,
        'ingredientes': ingredientes.map((i) => i.toMap()).toList(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      };

  Producto copyWith({int? stock, String? estado}) => Producto(
        id: id,
        codigo: codigo,
        nombre: nombre,
        categoria: categoria,
        precio: precio,
        stock: stock ?? this.stock,
        stockMinimo: stockMinimo,
        sucursal: sucursal,
        estado: estado ?? this.estado,
        ingredientes: ingredientes,
      );
}
