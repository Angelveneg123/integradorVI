class CRUDVentas {
  String? id;
  String codigoV;
  String estado;
  String sucursalU;
  String fecha;
  List<ProductList> productos;

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

  ProductList({
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precio,
  });
}

class SucursalList {
  String nombreU;

  SucursalList({
    required this.nombreU,
  });
}

class UsuarioData {
  String sucursalUsuario;

  UsuarioData({
    required this.sucursalUsuario,
  });
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
        'nombre': p.nombre,
        'cantidad': p.cantidad,
        'precioUnitario': p.precio,
      };
    }).toList(),
    'sucursalU': venta.sucursalU,
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
