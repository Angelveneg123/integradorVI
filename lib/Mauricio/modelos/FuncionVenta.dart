import '../../Henry/controladores/codigos_sucursal.dart';

class CRUDVentas {
  String? id;
  String codigoV;
  String estado;
  String sucursalU;
  String fecha;
  List<ProductList> productos;

  // Usuario que registró la venta
  String NombreUsuarioV;

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
    this.NombreUsuarioV = '',
  });
}

class ProductList {
  String codigo;
  String nombre;
  double cantidad;
  double precio;

  // Id del producto en Firestore
  String productoId;

  /// Sucursal a la que pertenece el producto en Firestore (solo se usa para
  /// filtrar los productos disponibles al registrar una venta).
  String sucursal;

  // Existencia actual (solo informativa, se lee al cargar el catálogo)
  double stock;

  ProductList({
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    this.productoId = '',
    this.sucursal = '',
    this.stock = 0,
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
    if (venta.NombreUsuarioV.isNotEmpty) 'NombreUsuarioV': venta.NombreUsuarioV,
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
    // `sucursal` es el campo que leen Reportes y Sucursales; `sucursalU` se
    // conserva por compatibilidad con las ventas ya guardadas.
    'sucursal': venta.sucursalU,
    'sucursalU': venta.sucursalU,
    'total': venta.total,
  };
}

// Código de la siguiente venta con el prefijo de la sucursal (N001, S001...).
// Se calcula con la lista que ya está en pantalla; al guardar se vuelve a
// calcular con los datos del servidor.
String generarCodigoVenta(List<CRUDVentas> listventas, String prefijo) {
  return CodigosSucursal.siguienteDeLista(
    listventas.map((v) => v.codigoV),
    prefijo,
  );
}
