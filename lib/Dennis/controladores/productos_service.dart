import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/productos_modelos.dart';
import '../../Chino/controladores/permisos_service.dart';

class ProductosService {
  final CollectionReference<Map<String, dynamic>> productosRef =
  FirebaseFirestore.instance.collection('productos');


  // Obtener productos


  Future<List<Producto>> obtenerProductos() async {
    final snapshot = await productosRef.orderBy('codigo').get();
    return snapshot.docs.map(_productoDesdeDoc).toList();
  }

  // Productos en tiempo real
  Stream<List<Producto>> streamProductos() {
    return productosRef
        .orderBy('codigo')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_productoDesdeDoc).toList());
  }

  Producto _productoDesdeDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
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
      cantidad: ((data['stock'] ?? data['cantidad']) as num?)?.toDouble() ?? 0,
      stockMinimo: (data['stockMinimo'] as num?)?.toDouble() ?? 0,
      estado: data['estado']?.toString() ?? 'Activo',
      sucursal: data['sucursal']?.toString() ?? 'Norte',
      ingredientes: listaIngredientes,
    );
  }


  // Producto a mapa


  Map<String, dynamic> productoToMap(Producto producto) {
    return {
      'codigo': producto.codigo,
      'nombre': producto.nombre,
      'categoria': producto.categoria,
      'precio': producto.precio,
      'cantidad': producto.cantidad,
      'stock': producto.cantidad, // lo leen Stock y Reportes
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


  // Agregar producto


  Future<String> agregarProducto(Producto producto) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarProductos, 'crear productos');
    final docRef = await productosRef.add(
      productoToMap(producto),
    );

    return docRef.id;
  }


  // Actualizar producto


  Future<void> actualizarProducto(Producto producto) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarProductos, 'editar productos o cambiar precios');
    if (producto.id == null) {
      throw Exception('El producto no tiene ID de Firestore');
    }

    await productosRef.doc(producto.id).update(
      productoToMap(producto),
    );
  }


  // Eliminar producto


  Future<void> eliminarProducto(String id) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarProductos, 'eliminar productos');
    await productosRef.doc(id).delete();
  }

  // Cambiar estado


  Future<void> cambiarEstado(
      String id,
      String nuevoEstado,
      ) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarProductos, 'cambiar el estado de productos');
    await productosRef.doc(id).update({
      'estado': nuevoEstado,
    });
  }


  // Probar conexión


  Future<void> probarFirebase() async {
    await productosRef.limit(1).get();

    print('FIREBASE CONECTADO CORRECTAMENTE');
  }
}