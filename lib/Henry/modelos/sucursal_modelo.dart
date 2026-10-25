import 'package:cloud_firestore/cloud_firestore.dart';

// Colección de sucursales
const String kColeccionSucursales = 'sucursales';

// Etiqueta de la sucursal
String etiquetaSucursal(String nombre) {
  final n = nombre.trim();
  if (n.isEmpty) return n;
  if (RegExp(r'^sucursal\b', caseSensitive: false).hasMatch(n)) return n;
  return 'Sucursal $n';
}

// Variantes del nombre
List<String> variantesNombreSucursal(String nombre) {
  final n = nombre.trim();
  final sinPrefijo =
      n.replaceFirst(RegExp(r'^sucursal\s+', caseSensitive: false), '');
  return <String>{n, sinPrefijo, 'Sucursal $sinPrefijo'}
      .where((e) => e.trim().isNotEmpty)
      .toList();
}

// Estados
const List<String> kEstadosSucursal = ['Activo', 'Inactivo'];

// Ciudades
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

// Modelo de sucursal
class Sucursal {
  final String id;
  final String codigo;
  final String nombre;
  final String encargado;
  final String ciudad;
  final String direccion;
  final int cantidadPersonal;
  final String estado; // 'Activo' o 'Inactivo'
  // Prefijo de los códigos de esta sucursal (N -> N001). Vacío = se calcula.
  final String prefijo;

  const Sucursal({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.encargado,
    required this.ciudad,
    required this.direccion,
    required this.cantidadPersonal,
    this.estado = 'Activo',
    this.prefijo = '',
  });

  bool get activo => estado == 'Activo';

  // Nombre para mostrar
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
      prefijo: (data['prefijo'] ?? '') as String,
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
        'prefijo': prefijo,
        'actualizadoEn': FieldValue.serverTimestamp(),
      };
}
