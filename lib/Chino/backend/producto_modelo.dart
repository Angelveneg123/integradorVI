import 'package:cloud_firestore/cloud_firestore.dart';

/// Nombre de la colección de Firestore que debe llenar el módulo de
/// Productos (Chino depende de ella para Stock y para el reporte de
/// "Inventario actual").
const String kColeccionProductos = 'productos';

/// Un ingrediente del producto (según el formulario "Nuevo producto" del
/// Figma: pares Ingrediente + Cantidad, con cantidad como texto libre
/// porque incluye la unidad, ej. "100 gm", "20 ml").
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

/// Modelo de un producto, con los campos reales del módulo CRUD de
/// Productos (Figma: Productos / Nuevo producto / Información producto /
/// Editar producto), más el `id` del documento de Firestore.
///
/// Documento en `productos/{id}`:
/// ```
/// {
///   "codigo": "P001",
///   "nombre": "Donas de chocolate",
///   "categoria": "Repostería",
///   "precio": 29.0,
///   "stock": 37,
///   "stockMinimo": 10,
///   "sucursal": "Norte",
///   "estado": "Activo",
///   "ingredientes": [ { "nombre": "Harina", "cantidad": "100 gm" }, ... ],
///   "actualizadoEn": <Timestamp>
/// }
/// ```
class Producto {
  final String id; // id del documento en Firestore
  final String codigo; // folio interno autogenerado por el CRUD, ej. "P001"
  final String nombre;
  final String categoria;
  final double precio;
  final int stock; // "Stock actual" / "Cantidad" en el Figma
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
      stock: ((data['stock'] ?? 0) as num).toInt(),
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
