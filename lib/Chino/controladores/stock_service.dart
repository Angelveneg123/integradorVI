import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/producto_modelo.dart';
import '../modelos/materia_prima_modelo.dart';
import 'auditoria_service.dart';
import 'consumo_ingredientes.dart';
import 'permisos_service.dart';

// Resultado del ajuste
class ResultadoAjuste {
  final int stockAnterior;
  final int stockNuevo;
  // Ingredientes descontados (solo en Entradas con descuento de receta)
  final List<ConsumoIngrediente> consumos;
  const ResultadoAjuste(this.stockAnterior, this.stockNuevo,
      [this.consumos = const []]);
}

// Resultado del ajuste de un ingrediente (en la unidad del ingrediente)
class ResultadoAjusteIngrediente {
  final double stockAnterior;
  final double stockNuevo;
  final String unidad;
  const ResultadoAjusteIngrediente(
    this.stockAnterior,
    this.stockNuevo,
    this.unidad,
  );
}

// Servicio de stock
class StockService {
  StockService({
    FirebaseFirestore? firestore,
    AuditoriaService? auditoriaService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auditoria = auditoriaService ?? AuditoriaService(firestore: firestore);

  final FirebaseFirestore _db;
  final AuditoriaService _auditoria;

  CollectionReference<Map<String, dynamic>> get _productos =>
      _db.collection(kColeccionProductos);

  CollectionReference<Map<String, dynamic>> get _materias =>
      _db.collection(kColeccionMateriaPrima);

  // Ajustar el stock de un ingrediente (entrada o salida).
  // La cantidad puede venir en otra unidad del mismo tipo (ej. ml para un lt).
  Future<ResultadoAjusteIngrediente> ajustarIngrediente({
    required MateriaPrima materia,
    required String tipoAjuste, // 'Entrada' | 'Salida'
    required double cantidad,
    required String unidad,
    String motivo = '',
    String autor = 'Usuario del sistema',
  }) async {
    Permisos.instance.exigir(
      Permisos.instance.puedeAjustarStock(materia.sucursal),
      'ajustar el stock de otra sucursal',
    );
    final enUnidadDelStock =
        convertirUnidad(cantidad, unidad, materia.unidadMedida);
    if (enUnidadDelStock == null) {
      throw StateError(
        'La unidad $unidad no es compatible con ${materia.unidadMedida}.',
      );
    }
    final docRef = _materias.doc(materia.id);
    final unidadStock = materia.unidadMedida.toLowerCase();

    final resultado =
        await _db.runTransaction<ResultadoAjusteIngrediente>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('El ingrediente ${materia.nombre} ya no existe.');
      }
      final v = snap.data()?['cantidad'];
      final actual = v is num ? v.toDouble() : 0.0;

      if (tipoAjuste != 'Entrada' && actual + 1e-9 < enUnidadDelStock) {
        throw StateError(
          'No hay suficiente "${materia.nombre}": hay '
          '${formatearCantidad(actual)} $unidadStock y quieres sacar '
          '${formatearCantidad(enUnidadDelStock)} $unidadStock.',
        );
      }
      final delta = tipoAjuste == 'Entrada' ? enUnidadDelStock : -enUnidadDelStock;
      final nuevo = redondearCantidad(actual + delta);
      final stockNuevo = nuevo < 0 ? 0.0 : nuevo;

      tx.update(docRef, {
        'cantidad': stockNuevo,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      tx.set(docRef.collection('movimientos').doc(), {
        'tipo': tipoAjuste,
        'cantidad': cantidad,
        'unidad': unidad,
        'motivo': motivo,
        'stockAnterior': actual,
        'stockNuevo': stockNuevo,
        'autor': autor,
        'fecha': FieldValue.serverTimestamp(),
      });

      return ResultadoAjusteIngrediente(actual, stockNuevo, materia.unidadMedida);
    });

    // Auditoría fuera de la transacción
    await _auditoria.registrarEvento(
      titulo: 'Stock',
      tipo: TipoEvento.editar,
      descripcion:
          'Ajuste de inventario (${tipoAjuste.toLowerCase()} de stock) en el ingrediente "${materia.nombre}"',
      autor: autor,
      modulo: 'Stock',
      idReferencia: materia.codigo,
      productos: [
        ProductoMovimiento(
          nombre: materia.nombre,
          cantidad: cantidad.round(),
          detalle:
              '${tipoAjuste == 'Entrada' ? '+' : '-'}${formatearCantidad(cantidad)} ${unidad.toLowerCase()} · '
              'Stock: ${formatearCantidad(resultado.stockAnterior)} → '
              '${formatearCantidad(resultado.stockNuevo)} $unidadStock'
              '${motivo.trim().isEmpty ? '' : ' · Motivo: $motivo'}',
        ),
      ],
    );

    return resultado;
  }

  // Ajustar inventario (entrada o salida).
  // Con [descontarIngredientes] una Entrada se trata como producción: descuenta
  // los ingredientes de la receta (por unidad x cantidad). Si no alcanzan, no
  // se hace nada. Se deja en false para devoluciones o correcciones.
  Future<ResultadoAjuste> ajustarInventario({
    required Producto producto,
    required String tipoAjuste, // 'Entrada' | 'Salida'
    required int cantidad,
    String motivo = '',
    String autor = 'Usuario del sistema',
    bool descontarIngredientes = false,
  }) async {
    Permisos.instance.exigir(
      Permisos.instance.puedeAjustarStock(producto.sucursal),
      'ajustar el stock de otra sucursal',
    );
    final docRef = _productos.doc(producto.id);

    final lineas = (descontarIngredientes && tipoAjuste == 'Entrada')
        ? await ConsumoRecetas.lineas(
            db: _db,
            sucursal: producto.sucursal,
            receta: [
              for (final i in producto.ingredientes)
                (nombre: i.nombre, cantidad: i.cantidad),
            ],
            unidades: cantidad.toDouble(),
          )
        : <LineaConsumo>[];

    final resultado = await _db.runTransaction<ResultadoAjuste>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('El producto ${producto.id} ya no existe.');
      }
      final stockActual = existenciaDeDocumento(snap.data() ?? <String, dynamic>{});
      final delta = tipoAjuste == 'Entrada' ? cantidad : -cantidad;
      final stockNuevo = (stockActual + delta).clamp(0, 1 << 30);

      // Se leen los ingredientes antes de escribir nada
      final actuales = lineas.isEmpty
          ? const <double>[]
          : await ConsumoRecetas.leerActuales(
              tx,
              lineas,
              etiqueta: 'sumar $cantidad de "${producto.nombre}"',
            );

      tx.update(docRef, {
        'stock': stockNuevo,
        'cantidad': stockNuevo, // la lee el módulo de Productos
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      final movimientoRef = docRef.collection('movimientos').doc();
      tx.set(movimientoRef, {
        'tipo': tipoAjuste,
        'cantidad': cantidad,
        'motivo': motivo,
        'stockAnterior': stockActual,
        'stockNuevo': stockNuevo,
        'autor': autor,
        'fecha': FieldValue.serverTimestamp(),
      });

      final consumos = lineas.isEmpty
          ? const <ConsumoIngrediente>[]
          : ConsumoRecetas.escribir(
              tx,
              lineas,
              actuales,
              motivo: 'Producción: $cantidad x "${producto.nombre}" (entrada de stock)',
              autor: autor,
            );

      return ResultadoAjuste(stockActual, stockNuevo, consumos);
    });

    // Auditoría fuera de la transacción
    await _auditoria.registrarEvento(
      titulo: 'Stock',
      tipo: TipoEvento.editar,
      descripcion:
          'Ajuste de inventario (${tipoAjuste.toLowerCase()} de stock) en "${producto.nombre}"',
      autor: autor,
      modulo: 'Stock',
      idReferencia: producto.codigo,
      productos: [
        ProductoMovimiento(
          nombre: producto.nombre,
          cantidad: cantidad,
          detalle:
              'Stock: ${resultado.stockAnterior} → ${resultado.stockNuevo}'
              '${motivo.trim().isEmpty ? '' : ' · Motivo: $motivo'}'
              '${resultado.consumos.isEmpty ? '' : ' · Ingredientes descontados: ${resultado.consumos.map((c) => c.resumen).join(', ')}'}',
        ),
      ],
    );

    return resultado;
  }
}
