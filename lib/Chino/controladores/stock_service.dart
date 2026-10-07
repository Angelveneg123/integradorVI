import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/producto_modelo.dart';
import 'auditoria_service.dart';

/// Resultado de un ajuste de inventario.
class ResultadoAjuste {
  final int stockAnterior;
  final int stockNuevo;
  const ResultadoAjuste(this.stockAnterior, this.stockNuevo);
}

/// Escribe cambios de stock sobre la colección `productos` (la que llena el
/// módulo de Productos) y deja un registro en `auditoria` por cada ajuste,
/// para que el módulo de Auditoria lo pueda ver.
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

  /// Suma o resta unidades del stock de [producto] (según [tipoAjuste]:
  /// 'Entrada' o 'Salida'), de forma atómica con una transacción, guarda un
  /// registro del movimiento en `productos/{id}/movimientos`, y crea un
  /// evento en la bitácora de auditoría.
  Future<ResultadoAjuste> ajustarInventario({
    required Producto producto,
    required String tipoAjuste, // 'Entrada' | 'Salida'
    required int cantidad,
    String motivo = '',
    String autor = 'Usuario del sistema',
  }) async {
    final docRef = _productos.doc(producto.id);

    final resultado = await _db.runTransaction<ResultadoAjuste>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('El producto ${producto.id} ya no existe.');
      }
      final stockActual = ((snap.data()?['stock'] ?? 0) as num).toInt();
      final delta = tipoAjuste == 'Entrada' ? cantidad : -cantidad;
      final stockNuevo = (stockActual + delta).clamp(0, 1 << 30);

      tx.update(docRef, {
        'stock': stockNuevo,
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

      return ResultadoAjuste(stockActual, stockNuevo);
    });

    // El registro de auditoría se hace fuera de la transacción porque
    // AuditoriaService usa `FieldValue.serverTimestamp()` a través de
    // `.add(...)`, que no se puede mezclar con `tx.set` sobre la misma
    // escritura sin duplicar lógica; una escritura extra aquí es aceptable.
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
              '${motivo.trim().isEmpty ? '' : ' · Motivo: $motivo'}',
        ),
      ],
    );

    return resultado;
  }
}
