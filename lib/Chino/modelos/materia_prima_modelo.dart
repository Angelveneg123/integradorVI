import 'package:cloud_firestore/cloud_firestore.dart';

// Colección de materia prima
const String kColeccionMateriaPrima = 'materia_prima';

// Unidades de medida
const List<String> kUnidadesMedida = [
  'Kg',
  'g',
  'lb',
  'oz',
  'lt',
  'ml',
  'Unidad',
  'Docena',
  'Cucharada',
  'Cucharadita',
  'Taza',
];

// Valor de cada unidad en su unidad base (g, ml o unidad)
const Map<String, double> _kFactorUnidad = {
  'kg': 1000,
  'g': 1,
  'lb': 453.59237,
  'oz': 28.349523,
  'lt': 1000,
  'ml': 1,
  'unidad': 1,
  'docena': 12,
  // Medidas de cocina en ml (aprox.)
  'cucharada': 15,
  'cucharadita': 5,
  'taza': 240,
};

// Tipo de medida de cada unidad (solo se convierte dentro del mismo tipo)
const Map<String, String> _kTipoUnidad = {
  'kg': 'peso',
  'g': 'peso',
  'lb': 'peso',
  'oz': 'peso',
  'lt': 'volumen',
  'ml': 'volumen',
  'unidad': 'unidad',
  'docena': 'unidad',
  'cucharada': 'volumen',
  'cucharadita': 'volumen',
  'taza': 'volumen',
};

// Nombre de la unidad como está en kUnidadesMedida (null si no existe)
String? unidadCanonica(String texto) {
  final t = texto.trim().toLowerCase();
  for (final u in kUnidadesMedida) {
    if (u.toLowerCase() == t) return u;
  }
  return null;
}

// Unidades que se pueden usar para un ingrediente guardado en [unidad]
// (ej. lt -> lt, ml)
List<String> unidadesCompatibles(String unidad) {
  final base = unidadCanonica(unidad);
  if (base == null) return [unidad];
  final tipo = _kTipoUnidad[base.toLowerCase()];
  return kUnidadesMedida
      .where((u) => _kTipoUnidad[u.toLowerCase()] == tipo)
      .toList();
}

// Convierte una cantidad entre unidades (null si no son compatibles)
double? convertirUnidad(double valor, String desde, String hacia) {
  final d = unidadCanonica(desde);
  final h = unidadCanonica(hacia);
  if (d == null || h == null) return null;
  if (_kTipoUnidad[d.toLowerCase()] != _kTipoUnidad[h.toLowerCase()]) {
    return null;
  }
  return valor * _kFactorUnidad[d.toLowerCase()]! / _kFactorUnidad[h.toLowerCase()]!;
}

// Cantidad de una receta, ej. "10 ml"
class CantidadReceta {
  final double valor;
  final String unidad;
  const CantidadReceta(this.valor, this.unidad);
}

// Lee un texto como "10 ml" (null si no se entiende)
CantidadReceta? leerCantidadReceta(String texto) {
  final m = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*([A-Za-zÁÉÍÓÚáéíóúñÑ]+)\s*$')
      .firstMatch(texto);
  if (m == null) return null;
  final valor = double.tryParse(m.group(1)!.replaceAll(',', '.'));
  final unidad = unidadCanonica(m.group(2)!);
  if (valor == null || unidad == null) return null;
  return CantidadReceta(valor, unidad);
}

// Evita errores de decimales al sumar y restar cantidades pequeñas
double redondearCantidad(double v) => (v * 1000000).roundToDouble() / 1000000;

// Cantidad para mostrar: 2 decimales, o más si hace falta (ej. 0.9975)
String formatearCantidad(double v) {
  final r2 = (v * 100).roundToDouble() / 100;
  if ((v - r2).abs() < 1e-9) return r2.toStringAsFixed(2);
  var t = v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  return t;
}

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
  // Fecha de registro (si no hay, la última actualización)
  final DateTime? fecha;

  const MateriaPrima({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.unidadMedida,
    required this.sucursal,
    this.estado = 'Activo',
    this.fecha,
  });

  bool get activo => estado == 'Activo';
  bool get agotado => cantidad <= 0;

  // Cantidad con su unidad
  String get cantidadConUnidad =>
      '${formatearCantidad(cantidad)} ${unidadMedida.toLowerCase()}';

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
    final ts = data['creadoEn'] ?? data['actualizadoEn'];
    return MateriaPrima(
      id: doc.id,
      codigo: (data['codigo'] ?? doc.id) as String,
      nombre: (data['nombre'] ?? '') as String,
      cantidad: ((data['cantidad'] ?? 0) as num).toDouble(),
      unidadMedida: (data['unidadMedida'] ?? 'Kg') as String,
      sucursal: (data['sucursal'] ?? '') as String,
      estado: (data['estado'] ?? 'Activo') as String,
      fecha: ts is Timestamp ? ts.toDate() : null,
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
