import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/materia_prima_modelo.dart';

// Ingrediente descontado del stock al producir un producto
class ConsumoIngrediente {
  final String nombre;
  final double cantidad; // en la unidad del ingrediente
  final String unidad;
  final double stockAnterior;
  final double stockNuevo;

  const ConsumoIngrediente({
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.stockAnterior,
    required this.stockNuevo,
  });

  String get resumen =>
      '$nombre -${formatearCantidad(cantidad)} ${unidad.toLowerCase()}';
}

// Ingrediente que hay que descontar (cantidad total ya calculada)
class LineaConsumo {
  final DocumentReference<Map<String, dynamic>> ref;
  final String nombre;
  final String unidad; // unidad en que está guardado el ingrediente
  double necesario;

  LineaConsumo(this.ref, this.nombre, this.unidad, this.necesario);
}

// Sucursal sin mayúsculas ni la palabra "Sucursal"
String _normSucursal(String s) =>
    s.trim().toLowerCase().replaceFirst(RegExp(r'^sucursal\s+'), '');

// Descuento de ingredientes según la receta (receta por unidad de producto)
class ConsumoRecetas {
  ConsumoRecetas._();

  // Ingredientes de la receta con la cantidad total a descontar para
  // [unidades] de producto. Se busca cada ingrediente por nombre en la sucursal.
  static Future<List<LineaConsumo>> lineas({
    required FirebaseFirestore db,
    required String sucursal,
    required List<({String nombre, String cantidad})> receta,
    required double unidades,
  }) async {
    if (receta.isEmpty || unidades <= 0) return [];

    final snap = await db.collection(kColeccionMateriaPrima).get();
    final suc = _normSucursal(sucursal);
    final porNombre = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in snap.docs) {
      final data = d.data();
      if (_normSucursal((data['sucursal'] ?? '').toString()) != suc) continue;
      porNombre[(data['nombre'] ?? '').toString().trim().toLowerCase()] = d;
    }

    final lineas = <String, LineaConsumo>{};
    for (final ing in receta) {
      final cant = leerCantidadReceta(ing.cantidad);
      if (cant == null) {
        throw StateError(
          'La cantidad "${ing.cantidad}" del ingrediente "${ing.nombre}" no es válida.',
        );
      }
      final doc = porNombre[ing.nombre.trim().toLowerCase()];
      if (doc == null) {
        throw StateError(
          'El ingrediente "${ing.nombre}" no existe en la sucursal $sucursal.',
        );
      }
      final data = doc.data();
      if ((data['estado'] ?? 'Activo').toString() != 'Activo') {
        throw StateError('El ingrediente "${ing.nombre}" está inactivo.');
      }
      final unidadMateria = (data['unidadMedida'] ?? 'Kg').toString();
      final porUnidad = convertirUnidad(cant.valor, cant.unidad, unidadMateria);
      if (porUnidad == null) {
        throw StateError(
          '"${ing.nombre}" está en $unidadMateria y la receta usa ${cant.unidad}: '
          'no son unidades compatibles.',
        );
      }
      final total = porUnidad * unidades;
      final existente = lineas[doc.id];
      if (existente == null) {
        lineas[doc.id] =
            LineaConsumo(doc.reference, ing.nombre, unidadMateria, total);
      } else {
        existente.necesario += total;
      }
    }
    return lineas.values.toList();
  }

  // Dentro de una transacción: lee el stock actual de cada ingrediente y
  // falla si no alcanza. Debe llamarse antes de cualquier escritura.
  static Future<List<double>> leerActuales(
    Transaction tx,
    List<LineaConsumo> lineas, {
    required String etiqueta, // ej. 'registrar 10 de "Pan"'
  }) async {
    final actuales = <double>[];
    final faltantes = <String>[];
    for (final l in lineas) {
      final snap = await tx.get(l.ref);
      if (!snap.exists) {
        throw StateError('El ingrediente "${l.nombre}" ya no existe.');
      }
      final v = snap.data()?['cantidad'];
      final actual = v is num ? v.toDouble() : 0.0;
      actuales.add(actual);
      if (actual + 1e-9 < l.necesario) {
        faltantes.add(
          '${l.nombre} (necesitas ${formatearCantidad(l.necesario)} '
          '${l.unidad.toLowerCase()}, hay ${formatearCantidad(actual)} '
          '${l.unidad.toLowerCase()})',
        );
      }
    }
    if (faltantes.isNotEmpty) {
      throw StateError(
        'No hay suficientes ingredientes para $etiqueta: ${faltantes.join('; ')}.',
      );
    }
    return actuales;
  }

  // Dentro de una transacción: descuenta y deja el movimiento de cada ingrediente
  static List<ConsumoIngrediente> escribir(
    Transaction tx,
    List<LineaConsumo> lineas,
    List<double> actuales, {
    required String motivo,
    required String autor,
  }) {
    final resultado = <ConsumoIngrediente>[];
    for (var i = 0; i < lineas.length; i++) {
      final l = lineas[i];
      final nuevo = redondearCantidad(actuales[i] - l.necesario);
      final stockNuevo = nuevo < 0 ? 0.0 : nuevo;
      tx.update(l.ref, {
        'cantidad': stockNuevo,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      tx.set(l.ref.collection('movimientos').doc(), {
        'tipo': 'Salida',
        'cantidad': l.necesario,
        'unidad': l.unidad,
        'motivo': motivo,
        'stockAnterior': actuales[i],
        'stockNuevo': stockNuevo,
        'autor': autor,
        'fecha': FieldValue.serverTimestamp(),
      });
      resultado.add(
        ConsumoIngrediente(
          nombre: l.nombre,
          cantidad: l.necesario,
          unidad: l.unidad,
          stockAnterior: actuales[i],
          stockNuevo: stockNuevo,
        ),
      );
    }
    return resultado;
  }
}
