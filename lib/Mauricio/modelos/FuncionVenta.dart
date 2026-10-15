class CRUDVentas {
  String? id;
  String codigoV;
  String estado;
  String sucursalU;
  String fecha;
  List<ProductList> productos;

  // Total de la venta
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

  // Id del producto en Firestore
  String productoId;

  // Sucursal del producto
  String sucursal;

  ProductList({
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    this.productoId = '',
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
        'productoId': p.productoId,
      };
    }).toList(),
    'items': venta.productos.map((p) {
      return {
        'codigo': p.codigo,
        'nombre': p.nombre,
        'cantidad': p.cantidad,
        'precioUnitario': p.precio,
        'productoId': p.productoId,
      };
    }).toList(),
    // sucursalU se mantiene por compatibilidad
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