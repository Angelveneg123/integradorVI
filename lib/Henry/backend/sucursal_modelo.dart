import 'package:cloud_firestore/cloud_firestore.dart';

/// Nombre de la colección de Firestore con las sucursales. Es la fuente de
/// verdad: los demás módulos (Materia Prima, y los que vengan) leen de aquí
/// el listado de sucursales.
const String kColeccionSucursales = 'sucursales';

/// Texto para mostrar una sucursal en pantalla. Antepone la palabra
/// "Sucursal" solo si el nombre no la trae ya (así "Norte" se ve como
/// "Sucursal Norte" y "Sucursal norte" no se duplica).
String etiquetaSucursal(String nombre) {
  final n = nombre.trim();
  if (n.isEmpty) return n;
  if (RegExp(r'^sucursal\b', caseSensitive: false).hasMatch(n)) return n;
  return 'Sucursal $n';
}

/// Formas en que puede venir guardado el nombre de una sucursal en los
/// documentos de `ventas` ("Norte", "Sucursal Norte" o el nombre tal cual).
List<String> variantesNombreSucursal(String nombre) {
  final n = nombre.trim();
  final sinPrefijo =
      n.replaceFirst(RegExp(r'^sucursal\s+', caseSensitive: false), '');
  return <String>{n, sinPrefijo, 'Sucursal $sinPrefijo'}
      .where((e) => e.trim().isNotEmpty)
      .toList();
}

/// Estados posibles de una sucursal.
const List<String> kEstadosSucursal = ['Activo', 'Inactivo'];

/// Ciudades / locaciones disponibles en el formulario (edita la lista para
/// agregar más).
const List<String> kCiudadesSucursal = [
  'Managua',
  'León',
  'Granada',
  'Masaya',
  'Estelí',
  'La Trinidad',
  'Matagalpa',
  'Jinotega',
  'Chinandega',
  'Rivas',
  'Juigalpa',
  'Ocotal',
  'Somoto',
  'Bluefields',
];

/// Modelo de una sucursal (UML "Documento Sucursal" y diseño de las 4
/// pantallas).
///
/// Documento en `sucursales/{id}` (el id del documento es el mismo código,
/// ej. "S001"):
/// ```
/// {
///   "codigo": "S001",
///   "nombre": "Norte",                    // Nombre_Sucursal
///   "encargado": "Pancho Martínez",       // Encargado_Sucursal
///   "ciudad": "La Trinidad",              // Ciudad
///   "direccion": "Donde fue gasolinera...", // Direccion
///   "cantidadPersonal": 9,                // Cantidad_de_personal
///   "estado": "Activo",                   // Estado
///   "actualizadoEn": <Timestamp>
/// }
/// ```
///
/// Los demás módulos guardan la sucursal como el **nombre** (ej. "Norte"),
/// que es lo que ya usan Productos, Stock y Reportes. Por eso, al renombrar
/// una sucursal el servicio actualiza también esos documentos.
class Sucursal {
  final String id;
  final String codigo;
  final String nombre;
  final String encargado;
  final String ciudad;
  final String direccion;
  final int cantidadPersonal;
  final String estado; // 'Activo' o 'Inactivo'

  const Sucursal({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.encargado,
    required this.ciudad,
    required this.direccion,
    required this.cantidadPersonal,
    this.estado = 'Activo',
  });

  bool get activo => estado == 'Activo';

  /// Nombre listo para mostrar (sin duplicar la palabra "Sucursal").
  String get etiqueta => etiquetaSucursal(nombre);

  factory Sucursal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Sucursal(
      id: doc.id,
      codigo: (data['codigo'] ?? doc.id) as String,
      nombre: (data['nombre'] ?? '') as String,
      encargado: (data['encargado'] ?? '') as String,
      ciudad: (data['ciudad'] ?? '') as String,
      direccion: (data['direccion'] ?? '') as String,
      cantidadPersonal: ((data['cantidadPersonal'] ?? 0) as num).toInt(),
      estado: (data['estado'] ?? 'Activo') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'encargado': encargado,
        'ciudad': ciudad,
        'direccion': direccion,
        'cantidadPersonal': cantidadPersonal,
        'estado': estado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      };
}
