import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelos/productos_modelos.dart';
import '../../Chino/controladores/permisos_service.dart';
import '../../Chino/modelos/materia_prima_modelo.dart';
import '../../Chino/controladores/consumo_ingredientes.dart';
import '../../Henry/controladores/codigos_sucursal.dart';

// ConsumoIngrediente vive en el módulo compartido de consumo de ingredientes
export '../../Chino/controladores/consumo_ingredientes.dart' show ConsumoIngrediente;

// El producto ya estaba guardado (por ejemplo, un segundo toque en Guardar)
class ProductoDuplicadoException implements Exception {
  const ProductoDuplicadoException();

  @override
  String toString() => 'Este producto ya estaba registrado. No se guardó otra vez.';
}

// Resultado de registrar un producto nuevo
class ResultadoAlta {
  final String id;
  final List<ConsumoIngrediente> consumos;
  const ResultadoAlta(this.id, this.consumos);
}

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

    // Fecha de registro; si no hay, la última actualización
    final ts = data['creadoEn'] ?? data['actualizadoEn'];

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
      fecha: ts is Timestamp ? ts.toDate() : null,
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
    final alta = await agregarProductoConIngredientes(producto);
    return alta.id;
  }

  // Reserva el siguiente código con el prefijo de la sucursal (N001, S001...)
  Future<String> siguienteCodigo(String sucursal) async {
    final db = FirebaseFirestore.instance;
    final prefijo = await CodigosSucursal.prefijoDe(db, sucursal) ?? 'P';
    return CodigosSucursal.reservar(
      db: db,
      coleccion: 'productos',
      campo: 'codigo',
      prefijo: prefijo,
    );
  }

  // Id para un alta nueva: se genera una vez por formulario
  String nuevoId() => productosRef.doc().id;

  // Agregar producto y descontar sus ingredientes del stock.
  // La receta es por unidad: cantidad del producto x cantidad de la receta.
  // [id] debe ser el mismo en todos los intentos de un mismo alta (ver
  // [nuevoId]): si ya existe, no se guarda ni se descuenta nada otra vez.
  Future<ResultadoAlta> agregarProductoConIngredientes(
    Producto producto, {
    String? id,
  }) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarProductos, 'crear productos');
    final docRef = id == null ? productosRef.doc() : productosRef.doc(id);

    final lineas = await _lineasDeConsumo(producto, producto.cantidad);

    // Sin cantidad o sin receta no hay nada que descontar
    if (lineas.isEmpty) {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        if ((await tx.get(docRef)).exists) {
          throw const ProductoDuplicadoException();
        }
        tx.set(docRef, {
          ...productoToMap(producto),
          'creadoEn': FieldValue.serverTimestamp(),
        });
      });
      return ResultadoAlta(docRef.id, const []);
    }

    final autor = FirebaseAuth.instance.currentUser?.email ?? 'Productos';
    final cant = formatearCantidad(producto.cantidad);

    final consumos = await FirebaseFirestore.instance
        .runTransaction<List<ConsumoIngrediente>>((tx) async {
      // Primero se lee todo, después se escribe
      if ((await tx.get(docRef)).exists) {
        throw const ProductoDuplicadoException();
      }
      final actuales = await ConsumoRecetas.leerActuales(
        tx,
        lineas,
        etiqueta: 'registrar $cant de "${producto.nombre}"',
      );
      tx.set(docRef, {
        ...productoToMap(producto),
        'creadoEn': FieldValue.serverTimestamp(),
      });
      return ConsumoRecetas.escribir(
        tx,
        lineas,
        actuales,
        motivo: 'Producción: $cant x "${producto.nombre}"',
        autor: autor,
      );
    });

    return ResultadoAlta(docRef.id, consumos);
  }

  // Actualizar producto. Si la cantidad AUMENTA respecto a [cantidadAnterior],
  // se descuentan los ingredientes de la diferencia (se produjo más). Si baja
  // o queda igual, no se toca el stock de ingredientes.
  Future<List<ConsumoIngrediente>> actualizarProductoConIngredientes(
    Producto producto, {
    required double cantidadAnterior,
  }) async {
    Permisos.instance.exigir(Permisos.instance.puedeEditarProductos, 'editar productos o cambiar precios');
    final id = producto.id;
    if (id == null) {
      throw Exception('El producto no tiene ID de Firestore');
    }
    final aumento = producto.cantidad - cantidadAnterior;
    final lineas = await _lineasDeConsumo(producto, aumento);

    if (lineas.isEmpty) {
      await productosRef.doc(id).update(productoToMap(producto));
      return const [];
    }

    final autor = FirebaseAuth.instance.currentUser?.email ?? 'Productos';
    final cant = formatearCantidad(aumento);

    return FirebaseFirestore.instance
        .runTransaction<List<ConsumoIngrediente>>((tx) async {
      final actuales = await ConsumoRecetas.leerActuales(
        tx,
        lineas,
        etiqueta: 'sumar $cant de "${producto.nombre}"',
      );
      tx.update(productosRef.doc(id), productoToMap(producto));
      return ConsumoRecetas.escribir(
        tx,
        lineas,
        actuales,
        motivo: 'Producción: +$cant x "${producto.nombre}" (edición)',
        autor: autor,
      );
    });
  }

  // Ingredientes de la receta con la cantidad a descontar para [unidades]
  Future<List<LineaConsumo>> _lineasDeConsumo(
    Producto producto,
    double unidades,
  ) {
    return ConsumoRecetas.lineas(
      db: FirebaseFirestore.instance,
      sucursal: producto.sucursal,
      receta: [
        for (final i in producto.ingredientes)
          (nombre: i.nombre, cantidad: i.cantidad),
      ],
      unidades: unidades,
    );
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


  // Desactivar y dar de baja el stock (merma) en una sola operación.
  // Devuelve las unidades dadas de baja.
  Future<double> desactivarConMerma({
    required String id,
    required String motivo,
  }) async {
    Permisos.instance.exigir(
      Permisos.instance.puedeEditarProductos,
      'dar de baja productos',
    );
    final ref = productosRef.doc(id);
    final autor = FirebaseAuth.instance.currentUser?.email ?? 'Productos';

    return FirebaseFirestore.instance.runTransaction<double>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('El producto ya no existe.');
      final data = snap.data() ?? <String, dynamic>{};
      final v = data['stock'] ?? data['cantidad'];
      final actual = v is num
          ? v.toDouble()
          : double.tryParse(v?.toString().trim().replaceAll(',', '.') ?? '') ??
              0;

      tx.update(ref, {
        'estado': 'Inactivo',
        'stock': 0,
        'cantidad': 0,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      if (actual > 0) {
        tx.set(ref.collection('movimientos').doc(), {
          'tipo': 'Salida',
          'cantidad': actual == actual.roundToDouble() ? actual.toInt() : actual,
          'motivo': 'Merma: $motivo',
          'stockAnterior':
              actual == actual.roundToDouble() ? actual.toInt() : actual,
          'stockNuevo': 0,
          'autor': autor,
          'fecha': FieldValue.serverTimestamp(),
        });
      }
      return actual;
    });
  }

  // Probar conexión


  Future<void> probarFirebase() async {
    await productosRef.limit(1).get();

    print('FIREBASE CONECTADO CORRECTAMENTE');
  }
}