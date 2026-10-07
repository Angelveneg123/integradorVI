class Producto {
  String? id;
  String codigo;
  String nombre;
  String categoria;
  double precio;
  double cantidad;
  double stockMinimo;
  String estado;
  String sucursal;
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

class Ingrediente {
  String nombre;
  String cantidad;

  Ingrediente({
    required this.nombre,
    required this.cantidad,
  });
}