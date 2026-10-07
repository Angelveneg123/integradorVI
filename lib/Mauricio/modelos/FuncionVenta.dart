class CRUDVentas {
  String? id;
  String codigoV;
  String estado;
  String sucursalU;
  String fecha;
  List<ProductList> productos;

  /// Total de la venta: suma de precio x cantidad de cada producto.
  double get total =>
      productos.fold<double>(0, (suma, p) => suma + p.precio * p.cantidad);

  CRUDVentas({
    this.id,
    required this.codigoV,
    required this.estado,
    required this.sucursalU,
    required this.fecha,
    required this.productos,
  });
}

class ProductList {
  String codigo;
  String nombre;
  double cantidad;
  double precio;

  /// Sucursal a la que pertenece el producto en Firestore (solo se usa para
  /// filtrar los productos disponibles al registrar una venta).
  String sucursal;

  ProductList({
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    this.sucursal = '',
  });
}

class SucursalList {
  String nombreU;

  SucursalList({required this.nombreU});
}

class UsuarioData {
  String SucursalUsuario;

  UsuarioData({required this.SucursalUsuario});
}

Map<String, dynamic> ventaToMap(CRUDVentas venta) {
  return {
    'codigoV': venta.codigoV,
    'estado': venta.estado,
    'fecha': venta.fecha,
    'productos': venta.productos.map((p) {
      return {
        'codigo': p.codigo,
        'nombre': p.nombre,
        'cantidad': p.cantidad,
        'precio': p.precio,
      };
    }).toList(),
    'items': venta.productos.map((p) {
      return {
        'codigo': p.codigo,
        'nombre': p.nombre,
        'cantidad': p.cantidad,
        'precioUnitario': p.precio,
      };
    }).toList(),
    // `sucursal` es el campo que leen Reportes y Sucursales; `sucursalU` se
    // conserva por compatibilidad con las ventas ya guardadas.
    'sucursal': venta.sucursalU,
    'sucursalU': venta.sucursalU,
    'total': venta.total,
  };
}

String generarCodigo(List<CRUDVentas> listventas) {
  int mayor = 0;
  for (final ventas in listventas) {
    final numero = int.tryParse(ventas.codigoV.replaceFirst('V', ''));
    if (numero != null && numero > mayor) {
      mayor = numero;
    }
  }
  return 'V${(mayor + 1).toString().padLeft(3, '0')}';
}