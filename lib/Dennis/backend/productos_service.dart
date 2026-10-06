import 'package:cloud_firestore/cloud_firestore.dart';
import 'productos_modelos.dart';

class ProductosService {
  final CollectionReference<Map<String, dynamic>> productosRef =
  FirebaseFirestore.instance.collection('productos');

  // ============================================================
  // OBTENER PRODUCTOS
  // ============================================================

  Future<List<Producto>> obtenerProductos() async {
    final snapshot = await productosRef.orderBy('codigo').get();

    final lista = snapshot.docs.map((doc) {
      final data = doc.data();

      final ingredientesData = data['ingredientes'];
      final listaIngredientes = <Ingrediente>[];

      if (ingredientesData is List) {
        for (final item in ingredientesData) {
          if (item is Map) {
            listaIngredientes.add(
              Ingrediente(
                nombre: item['nombre']?.toString() ?? '',
                cantidad: item['cantidad']?.toString() ?? '',
              ),
            );
          }
        }
      }

      return Producto(
        id: doc.id,
        codigo: data['codigo']?.toString() ?? '',
        nombre: data['nombre']?.toString() ?? '',
        categoria: data['categoria']?.toString() ?? 'Pan',
        precio: (data['precio'] as num?)?.toDouble() ?? 0,
        cantidad: (data['cantidad'] as num?)?.toDouble() ?? 0,
        stockMinimo: (data['stockMinimo'] as num?)?.toDouble() ?? 0,
        estado: data['estado']?.toString() ?? 'Activo',
        sucursal: data['sucursal']?.toString() ?? 'Norte',
        ingredientes: listaIngredientes,
      );
    }).toList();

    return lista;
  }

  // ============================================================
  // CONVERTIR PRODUCTO A MAP
  // ============================================================

  Map<String, dynamic> productoToMap(Producto producto) {
    return {
      'codigo': producto.codigo,
      'nombre': producto.nombre,
      'categoria': producto.categoria,
      'precio': producto.precio,
      'cantidad': producto.cantidad,
      'stockMinimo': producto.stockMinimo,
      'estado': producto.estado,
      'sucursal': producto.sucursal,
      'ingredientes': producto.ingredientes.map((ingrediente) {
        return {
          'nombre': ingrediente.nombre,
          'cantidad': ingrediente.cantidad,
        };
      }).toList(),
    };
  }

  // ============================================================
  // AGREGAR PRODUCTO
  // ============================================================

  Future<String> agregarProducto(Producto producto) async {
    final docRef = await productosRef.add(
      productoToMap(producto),
    );

    return docRef.id;
  }

  // ============================================================
  // ACTUALIZAR PRODUCTO
  // ============================================================

  Future<void> actualizarProducto(Producto producto) async {
    if (producto.id == null) {
      throw Exception('El producto no tiene ID de Firestore');
    }

    await productosRef.doc(producto.id).update(
      productoToMap(producto),
    );
  }

  // ============================================================
  // ELIMINAR PRODUCTO
  // ============================================================

  Future<void> eliminarProducto(String id) async {
    await productosRef.doc(id).delete();
  }

  // ============================================================
  // CAMBIAR ESTADO
  // ============================================================

  Future<void> cambiarEstado(
      String id,
      String nuevoEstado,
      ) async {
    await productosRef.doc(id).update({
      'estado': nuevoEstado,
    });
  }

  // ============================================================
  // PROBAR CONEXIÓN CON FIREBASE
  // ============================================================

  Future<void> probarFirebase() async {
    await productosRef.limit(1).get();

    print('FIREBASE CONECTADO CORRECTAMENTE');
  }
}