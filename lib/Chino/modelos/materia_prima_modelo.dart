import 'package:cloud_firestore/cloud_firestore.dart';

/// Nombre de la colección de Firestore para la materia prima / ingredientes.
const String kColeccionMateriaPrima = 'materia_prima';

/// Unidades de medida disponibles en el formulario (puedes agregar más).
const List<String> kUnidadesMedida = ['Kg', 'g', 'lb', 'lt', 'ml', 'Unidad'];

/// Sucursales disponibles en el formulario. Cuando el módulo de Sucursales
/// esté listo, esta lista se puede reemplazar por una lectura de Firestore.
const List<String> kSucursalesMateriaPrima = ['Norte', 'Centro'];

/// Estados posibles de una materia prima.
const List<String> kEstadosMateriaPrima = ['Activo', 'Inactivo'];

/// Categorías que se usan solo como filtros en el listado (chips).
const List<String> kCategoriasMateriaPrima = ['Harinas', 'Lácteos', 'Líquidos'];

/// Modelo de una materia prima (según el diagrama UML "Documento
/// Materia_Prima" y el diseño de las 4 pantallas).
///
/// Documento en `materia_prima/{id}` (el id del documento es el mismo
/// código, ej. "M001"):
/// ```
/// {
///   "codigo": "M001",
///   "nombre": "Harina de trigo",     // Nombre_Elemento
///   "cantidad": 50.0,                // Cantidad (DOUBLE)
///   "unidadMedida": "Kg",            // Unidad_Medida
///   "sucursal": "Norte",             // Sucursal
///   "estado": "Activo",              // Estado
///   "actualizadoEn": <Timestamp>
/// }
/// ```
class MateriaPrima {
  final String id; // id del documento en Firestore
  final String codigo; // "M001" (el "Id" que se ve en Información de Materia)
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

  /// "50.00 kg" (como se muestra en el listado y en el detalle).
  String get cantidadConUnidad =>
      '${cantidad.toStringAsFixed(2)} ${unidadMedida.toLowerCase()}';

  /// Categoría deducida del nombre/unidad, solo para los chips del listado
  /// (Harinas, Lácteos, Líquidos). No se guarda en Firestore.
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
