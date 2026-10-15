import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/evento_auditoria_modelo.dart';
import '../modelos/producto_modelo.dart';
import 'auditoria_service.dart';
import 'permisos_service.dart';

// Resultado del ajuste
class ResultadoAjuste {
  final int stockAnterior;
  final int stockNuevo;
  const ResultadoAjuste(this.stockAnterior, this.stockNuevo);
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

  // Ajustar inventario (entrada o salida)
  Future<ResultadoAjuste> ajustarInventario({
    required Producto producto,
    required String tipoAjuste, // 'Entrada' | 'Salida'
    required int cantidad,
    String motivo = '',
    String autor = 'Usuario del sistema',
  }) async {
    Permisos.instance.exigir(
      Permisos.instance.puedeAjustarStock(producto.sucursal),
      'ajustar el stock de otra sucursal',
    );
    final docRef = _productos.doc(producto.id);

    final resultado = await _db.runTransaction<ResultadoAjuste>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('El producto ${producto.id} ya no existe.');
      }
      final stockActual = existenciaDeDocumento(snap.data() ?? <String, dynamic>{});
      final delta = tipoAjuste == 'Entrada' ? cantidad : -cantidad;
      final stockNuevo = (stockActual + delta).clamp(0, 1 << 30);

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

      return ResultadoAjuste(stockActual, stockNuevo);
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
              '${motivo.trim().isEmpty ? '' : ' · Motivo: $motivo'}',
        ),
      ],
    );

    return resultado;
  }
}
