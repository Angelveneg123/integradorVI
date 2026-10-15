// Producto del menú
class Producto {
  String? id;
  String codigo;
  String nombre;
  String categoria;
  double precio;
  // Existencia actual
  double cantidad;
  // Mínimo antes de avisar stock bajo
  double stockMinimo;
  String estado;
  String sucursal;
  // Receta del producto
  List<Ingrediente> ingredientes;

  Producto({
    this.id,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.precio,
    required this.cantidad,
    required this.stockMinimo,
    required this.estado,
    required this.sucursal,
    required this.ingredientes,
  });
}

// Ingrediente de un producto
class Ingrediente {
  String nombre;
  // Cantidad con su unidad (ej. 100 g)
  String cantidad;

  Ingrediente({
    required this.nombre,
    required this.cantidad,
  });
}