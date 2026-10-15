import 'package:cloud_firestore/cloud_firestore.dart';

// Colección de materia prima
const String kColeccionMateriaPrima = 'materia_prima';

// Unidades de medida
const List<String> kUnidadesMedida = ['Kg', 'g', 'lb', 'lt', 'ml', 'Unidad'];

// Sucursales del formulario
const List<String> kSucursalesMateriaPrima = ['Norte', 'Centro'];

// Estados
const List<String> kEstadosMateriaPrima = ['Activo', 'Inactivo'];

// Categorías para los filtros
const List<String> kCategoriasMateriaPrima = ['Harinas', 'Lácteos', 'Líquidos'];


class MateriaPrima {
  final String id; // id del documento en Firestore
  final String codigo; // ej. M001
  final String nombre;
  final double cantidad;
  final String unidadMedida;
  final String sucursal;
  final String estado; // 'Activo' o 'Inactivo'

  const MateriaPrima({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.unidadMedida,
    required this.sucursal,
    this.estado = 'Activo',
  });

  bool get activo => estado == 'Activo';

  // Cantidad con su unidad
  String get cantidadConUnidad =>
      '${cantidad.toStringAsFixed(2)} ${unidadMedida.toLowerCase()}';

  // Categoría según nombre y unidad
  String get categoria {
    final n = nombre.toLowerCase();
    if (n.contains('harina') || n.contains('fécula') || n.contains('fecula')) {
      return 'Harinas';
    }
    if (n.contains('leche') ||
        n.contains('queso') ||
        n.contains('mantequilla') ||
        n.contains('crema') ||
        n.contains('yogur')) {
      return 'Lácteos';
    }
    final u = unidadMedida.toLowerCase();
    if (u == 'lt' || u == 'ml') return 'Líquidos';
    return 'Otros';
  }

// Documento a objeto
  factory MateriaPrima.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MateriaPrima(
      id: doc.id,
      codigo: (data['codigo'] ?? doc.id) as String,
      nombre: (data['nombre'] ?? '') as String,
      cantidad: ((data['cantidad'] ?? 0) as num).toDouble(),
      unidadMedida: (data['unidadMedida'] ?? 'Kg') as String,
      sucursal: (data['sucursal'] ?? '') as String,
      estado: (data['estado'] ?? 'Activo') as String,
    );
  }

// Objeto a mapa
  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'cantidad': cantidad,
        'unidadMedida': unidadMedida,
        'sucursal': sucursal,
        'estado': estado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      };
}
