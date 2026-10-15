import 'package:cloud_firestore/cloud_firestore.dart';

// Colección de usuarios
const String kColeccionUsuarios = 'usuarios';

// Roles
const List<String> kRolesUsuario = ['Administrador', 'Vendedor'];

// Estados (Eliminado = borrado lógico)
const List<String> kEstadosUsuario = ['Activo', 'Inactivo'];
const String kEstadoEliminado = 'Eliminado';

// Modelo de usuario
class Usuario {
  final String id; // uid de Firebase Authentication
  final String codigo;
  final String nombre;
  final String correo;
  final String telefono;
  final String rol;
  final String sucursal;
  final String estado;

  const Usuario({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.rol,
    required this.sucursal,
    this.estado = 'Activo',
  });

  bool get activo => estado == 'Activo';
  bool get esAdministrador => rol == 'Administrador';

  factory Usuario.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Usuario(
      id: doc.id,
      codigo: (data['codigo'] ?? doc.id) as String,
      nombre: (data['nombre'] ?? '') as String,
      correo: (data['correo'] ?? '') as String,
      telefono: (data['telefono'] ?? '') as String,
      rol: (data['rol'] ?? 'Vendedor') as String,
      sucursal: (data['sucursal'] ?? '') as String,
      estado: (data['estado'] ?? 'Activo') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'rol': rol,
        'sucursal': sucursal,
        'estado': estado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      };
}