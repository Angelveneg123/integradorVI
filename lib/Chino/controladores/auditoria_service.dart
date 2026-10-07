import 'package:cloud_firestore/cloud_firestore.dart';

import '../modelos/evento_auditoria_modelo.dart';

/// Acceso a la colección `auditoria`.
///
/// Cualquier módulo (Ventas, Usuarios, Accesos, Productos, Stock...) puede
/// llamar a [registrarEvento] cuando crea/edita/elimina/ingresa algo. El
/// módulo de Auditoria solo lee esta colección para mostrar la bitácora;
/// por eso es difícil de probar "solo", y la forma real de probarlo es
/// generando eventos desde los otros módulos (o con los datos de prueba
/// de `lib/Chino/controladores/seed_data.dart`).
class AuditoriaService {
  AuditoriaService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection(kColeccionAuditoria);

  /// Stream en tiempo real de todos los eventos, más recientes primero.
  Stream<List<EventoAuditoria>> streamEventos({int limite = 200}) {
    return _coleccion
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((snap) => snap.docs.map(EventoAuditoria.fromDoc).toList());
  }

  /// Lectura puntual de eventos en un rango de fechas (usado por Reportes
  /// para "Auditoría de actividad"), opcionalmente filtrando por módulo.
  Future<List<EventoAuditoria>> obtenerEventos({
    required DateTime desde,
    required DateTime hasta,
    String? modulo,
  }) async {
    Query<Map<String, dynamic>> query = _coleccion
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta));
    if (modulo != null && modulo.trim().isNotEmpty) {
      query = query.where('modulo', isEqualTo: modulo);
    }
    final snap = await query.orderBy('fecha', descending: true).get();
    return snap.docs.map(EventoAuditoria.fromDoc).toList();
  }

  /// Registra un nuevo evento en la bitácora. Cualquier módulo debería
  /// llamar esto justo después de crear/editar/eliminar/ingresar algo.
  ///
  /// [autor] debería venir del usuario autenticado (por ahora, mientras no
  /// haya login conectado, usa un valor fijo o pásalo desde donde sí lo
  /// tengas).
  Future<void> registrarEvento({
    required String titulo,
    required TipoEvento tipo,
    required String descripcion,
    required String autor,
    required String modulo,
    required String idReferencia,
    List<ProductoMovimiento> productos = const [],
    List<CampoInfo> datosAdicionales = const [],
  }) {
    final evento = EventoAuditoria(
      id: '',
      titulo: titulo,
      tipo: tipo,
      descripcion: descripcion,
      autor: autor,
      fecha: DateTime.now(),
      modulo: modulo,
      idReferencia: idReferencia,
      productos: productos,
      datosAdicionales: datosAdicionales,
    );
    return _coleccion.add(evento.toMap());
  }
}
